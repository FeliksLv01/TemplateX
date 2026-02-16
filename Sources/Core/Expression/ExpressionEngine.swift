import Foundation
import Antlr4
import os.lock

// MARK: - Expression Result

/// 表达式求值结果
public enum ExpressionResult {
    case success(Any?)
    case failure(ExpressionError)
    
    /// 获取值，失败时返回默认值
    public func value(or defaultValue: Any? = nil) -> Any? {
        switch self {
        case .success(let value): return value
        case .failure: return defaultValue
        }
    }
    
    /// 是否成功
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Expression Error

/// 表达式错误
public enum ExpressionError: Error, CustomStringConvertible {
    case parseError(String, position: Int?)
    case evaluationError(String)
    case invalidExpression
    
    public var description: String {
        switch self {
        case .parseError(let msg, let pos):
            if let p = pos {
                return "Parse error at position \(p): \(msg)"
            }
            return "Parse error: \(msg)"
        case .evaluationError(let msg):
            return "Evaluation error: \(msg)"
        case .invalidExpression:
            return "Invalid expression"
        }
    }
}

// MARK: - Cached Parse Tree

/// 缓存的解析树（包装 ANTLR 解析树上下文）
final class CachedParseTree {
    let tree: TemplateXExprParser.ExpressionContext
    let sourceText: String  // 保存原始表达式字符串，用于从 token 位置提取文本
    let accessTime: Date
    
    init(tree: TemplateXExprParser.ExpressionContext, sourceText: String) {
        self.tree = tree
        self.sourceText = sourceText
        self.accessTime = Date()
    }
}

// MARK: - Expression Engine

/// 表达式引擎 - 带缓存的解析和求值
/// 
/// 功能：
/// - LRU 缓存解析树，避免重复解析
/// - 支持自定义函数注册
/// - 线程安全
/// - 性能统计
public final class ExpressionEngine {
    
    // MARK: - Singleton
    
    /// 共享实例（可选，业务也可创建独立实例）
    public static let shared = ExpressionEngine()
    
    // MARK: - Properties
    
    /// 解析树缓存
    private let parseTreeCache: LRUCache<String, CachedParseTree>
    
    /// 自定义函数注册表
    private var customFunctions: [String: ExpressionFunction] = [:]
    
    /// 高性能自旋锁
    private var functionsLock = os_unfair_lock()
    
    /// 性能统计
    public private(set) var parseCount: Int = 0
    public private(set) var evalCount: Int = 0
    
    // MARK: - Configuration
    
    /// 缓存容量
    public let cacheCapacity: Int
    
    /// 是否启用缓存
    public var cacheEnabled: Bool = true
    
    // MARK: - Initialization
    
    /// 初始化
    /// - Parameter cacheCapacity: 缓存容量，默认 256
    public init(cacheCapacity: Int = 256) {
        self.cacheCapacity = cacheCapacity
        self.parseTreeCache = LRUCache(capacity: cacheCapacity)
    }
    
    // MARK: - Function Registration
    
    /// 注册自定义函数
    public func registerFunction(_ function: ExpressionFunction) {
        os_unfair_lock_lock(&functionsLock)
        defer { os_unfair_lock_unlock(&functionsLock) }
        customFunctions[function.name] = function
    }
    
    /// 注册简单函数
    public func registerFunction(name: String, handler: @escaping ([Any]) -> Any?) {
        registerFunction(SimpleFunction(name: name, handler: handler))
    }
    
    /// 批量注册函数
    public func registerFunctions(_ functions: [ExpressionFunction]) {
        os_unfair_lock_lock(&functionsLock)
        defer { os_unfair_lock_unlock(&functionsLock) }
        for func_ in functions {
            customFunctions[func_.name] = func_
        }
    }
    
    /// 移除函数
    public func unregisterFunction(name: String) {
        os_unfair_lock_lock(&functionsLock)
        defer { os_unfair_lock_unlock(&functionsLock) }
        customFunctions.removeValue(forKey: name)
    }
    
    // MARK: - Parsing
    
    /// 解析表达式（带缓存）
    /// - Parameter expression: 表达式字符串
    /// - Returns: 解析树上下文，失败返回 nil
    @discardableResult
    public func parse(_ expression: String) throws -> TemplateXExprParser.ExpressionContext {
        parseCount += 1
        
        // 尝试从缓存获取
        if cacheEnabled, let cached = parseTreeCache.get(expression) {
            return cached.tree
        }
        
        // 解析
        let tree = try parseInternal(expression)
        
        // 存入缓存
        if cacheEnabled {
            parseTreeCache.set(expression, CachedParseTree(tree: tree, sourceText: expression))
        }
        
        return tree
    }
    
    /// 内部解析实现
    private func parseInternal(_ expression: String) throws -> TemplateXExprParser.ExpressionContext {
        // 创建输入流
        let input = ANTLRInputStream(expression)
        
        // 词法分析
        let lexer = TemplateXExprLexer(input)
        // 强制复制 token 文本，避免 inputStream 释放后 getText() 返回 nil
        lexer.setTokenFactory(CommonTokenFactory(true))
        lexer.removeErrorListeners()
        let errorListener = ExpressionErrorListener()
        lexer.addErrorListener(errorListener)
        
        // Token 流
        let tokens = CommonTokenStream(lexer)
        
        // 语法分析
        let parser = try TemplateXExprParser(tokens)
        parser.removeErrorListeners()
        parser.addErrorListener(errorListener)
        
        // 解析
        let tree = try parser.expression()
        
        // 检查错误
        if let error = errorListener.errors.first {
            throw ExpressionError.parseError(error.message, position: error.position)
        }
        
        return tree
    }
    
    // MARK: - Evaluation
    
    /// 求值表达式
    /// - Parameters:
    ///   - expression: 表达式字符串
    ///   - context: 数据上下文
    /// - Returns: 求值结果
    public func evaluate(_ expression: String, context: [String: Any]) -> ExpressionResult {
        evalCount += 1
        
        do {
            let tree = try parse(expression)
            return evaluateTree(tree, context: context)
        } catch let error as ExpressionError {
            return .failure(error)
        } catch {
            return .failure(.parseError(error.localizedDescription, position: nil))
        }
    }
    
    /// 求值解析树
    /// - Parameters:
    ///   - tree: 解析树
    ///   - context: 数据上下文
    /// - Returns: 求值结果
    public func evaluateTree(_ tree: TemplateXExprParser.ExpressionContext, context: [String: Any]) -> ExpressionResult {
        os_unfair_lock_lock(&functionsLock)
        let functions = customFunctions
        os_unfair_lock_unlock(&functionsLock)
        
        let evaluator = ExpressionEvaluator(context: context, functions: functions)
        let result = evaluator.visit(tree)
        
        return .success(result)
    }
    
    /// 快速求值（便捷方法）
    /// - Parameters:
    ///   - expression: 表达式字符串
    ///   - context: 数据上下文
    ///   - defaultValue: 失败时的默认值
    /// - Returns: 求值结果
    @inline(__always)
    public func eval(_ expression: String, context: [String: Any], default defaultValue: Any? = nil) -> Any? {
        return evaluate(expression, context: context).value(or: defaultValue)
    }
    
    // MARK: - Binding Expression Support
    
    /// 检查字符串是否包含绑定表达式 ${...}
    public func containsBinding(_ text: String) -> Bool {
        return text.contains("${") && text.contains("}")
    }
    
    /// 解析绑定表达式
    /// 支持格式：
    /// - "${expression}" - 纯表达式
    /// - "prefix ${expr1} middle ${expr2} suffix" - 混合字符串
    public func resolveBinding(_ text: String, context: [String: Any]) -> Any? {
        guard containsBinding(text) else {
            return text
        }
        
        // 纯表达式: ${...}
        if text.hasPrefix("${") && text.hasSuffix("}") && text.filter({ $0 == "$" }).count == 1 {
            let expr = String(text.dropFirst(2).dropLast())
            return eval(expr, context: context)
        }
        
        // 混合字符串: 逐个替换 ${...}
        var result = text
        let pattern = #"\$\{([^}]+)\}"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        // 从后向前替换，避免位置错乱
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let exprRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            
            let expr = String(result[exprRange])
            let value = eval(expr, context: context)
            let replacement = stringValue(value)
            
            result.replaceSubrange(range, with: replacement)
        }
        
        return result
    }
    
    /// 批量解析绑定
    public func resolveBindings(_ dict: [String: Any], context: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in dict {
            if let strValue = value as? String {
                result[key] = resolveBinding(strValue, context: context)
            } else if let dictValue = value as? [String: Any] {
                result[key] = resolveBindings(dictValue, context: context)
            } else if let arrayValue = value as? [Any] {
                result[key] = resolveBindingsInArray(arrayValue, context: context)
            } else {
                result[key] = value
            }
        }
        
        return result
    }
    
    private func resolveBindingsInArray(_ array: [Any], context: [String: Any]) -> [Any] {
        return array.map { element in
            if let strValue = element as? String {
                return resolveBinding(strValue, context: context) ?? strValue
            } else if let dictValue = element as? [String: Any] {
                return resolveBindings(dictValue, context: context)
            } else if let arrayValue = element as? [Any] {
                return resolveBindingsInArray(arrayValue, context: context)
            }
            return element
        }
    }
    
    // MARK: - Cache Management
    
    /// 清空缓存
    public func clearCache() {
        parseTreeCache.clear()
    }
    
    /// 缓存命中率
    public var cacheHitRate: Double {
        return parseTreeCache.hitRate
    }
    
    /// 缓存数量
    public var cacheCount: Int {
        return parseTreeCache.count
    }
    
    // MARK: - Statistics
    
    /// 重置统计
    public func resetStatistics() {
        parseCount = 0
        evalCount = 0
        parseTreeCache.clear()
    }
    
    /// 统计信息
    public var statistics: [String: Any] {
        return [
            "parseCount": parseCount,
            "evalCount": evalCount,
            "cacheCount": cacheCount,
            "cacheHitRate": cacheHitRate,
            "cacheCapacity": cacheCapacity
        ]
    }
    
    // MARK: - Helper
    
    private func stringValue(_ value: Any?) -> String {
        guard let v = value else { return "" }
        
        switch v {
        case let str as String: return str
        case let num as Double:
            return num.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(num)) : String(num)
        case let num as Int: return String(num)
        case let bool as Bool: return bool ? "true" : "false"
        default: return String(describing: v)
        }
    }
}

// MARK: - Error Listener

/// ANTLR 错误监听器
final class ExpressionErrorListener: BaseErrorListener {
    
    struct ParseError {
        let message: String
        let position: Int
    }
    
    var errors: [ParseError] = []
    
    override func syntaxError<T>(
        _ recognizer: Recognizer<T>,
        _ offendingSymbol: AnyObject?,
        _ line: Int,
        _ charPositionInLine: Int,
        _ msg: String,
        _ e: AnyObject?
    ) {
        errors.append(ParseError(message: msg, position: charPositionInLine))
    }
}
