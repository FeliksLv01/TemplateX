import Foundation

// MARK: - 表达式提取器

/// 表达式提取器 - 提取和预处理 ${} 语法
public struct ExpressionExtractor {
    
    // MARK: - 正则表达式
    
    /// 匹配 ${...} 表达式的正则
    private static let expressionPattern = #"\$\{([^}]+)\}"#
    private static let expressionRegex = try! NSRegularExpression(
        pattern: expressionPattern,
        options: []
    )
    
    // MARK: - 提取表达式
    
    /// 检查字符串是否包含表达式
    public static func containsExpression(_ value: String) -> Bool {
        return value.contains("${")
    }
    
    /// 检查是否是纯表达式（整个字符串就是一个表达式）
    public static func isPureExpression(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // 检查是否以 ${ 开头，以 } 结尾
        if trimmed.hasPrefix("${") && trimmed.hasSuffix("}") {
            // 确保中间没有其他内容
            let inner = String(trimmed.dropFirst(2).dropLast())
            // 简单检查：确保只有一个表达式
            if !inner.contains("${") {
                return true
            }
        }
        
        return false
    }
    
    /// 提取纯表达式的内容
    public static func extractPureExpression(_ value: String) -> String? {
        guard isPureExpression(value) else { return nil }
        
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return String(trimmed.dropFirst(2).dropLast())
    }
    
    /// 提取所有表达式
    public static func extractExpressions(_ value: String) -> [ExpressionMatch] {
        let nsString = value as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        let matches = expressionRegex.matches(in: value, options: [], range: range)
        
        return matches.map { match in
            let fullRange = match.range
            let exprRange = match.range(at: 1)
            
            let fullMatch = nsString.substring(with: fullRange)
            let expression = nsString.substring(with: exprRange)
            
            return ExpressionMatch(
                fullMatch: fullMatch,
                expression: expression,
                range: fullRange
            )
        }
    }
    
    // MARK: - 表达式编译
    
    /// 编译单个表达式属性
    /// - Returns: 绑定配置字典
    public static func compileExpression(_ value: String) -> [String: Any]? {
        guard let expr = extractPureExpression(value) else {
            return nil
        }
        
        return [
            "expr": expr,
            "type": "expression"
        ]
    }
    
    /// 编译混合字符串（包含文本和表达式）
    /// - Returns: 绑定配置字典
    public static func compileMixedString(_ value: String) -> [String: Any]? {
        let expressions = extractExpressions(value)
        
        guard !expressions.isEmpty else {
            return nil
        }
        
        // 如果是纯表达式，直接返回
        if isPureExpression(value) {
            return [
                "expr": expressions[0].expression,
                "type": "expression"
            ]
        }
        
        // 混合字符串，编译为模板
        var segments: [[String: Any]] = []
        var currentIndex = 0
        let nsString = value as NSString
        
        for match in expressions {
            // 添加表达式之前的文本
            if match.range.location > currentIndex {
                let textRange = NSRange(
                    location: currentIndex,
                    length: match.range.location - currentIndex
                )
                let text = nsString.substring(with: textRange)
                if !text.isEmpty {
                    segments.append([
                        "type": "text",
                        "value": text
                    ])
                }
            }
            
            // 添加表达式
            segments.append([
                "type": "expr",
                "value": match.expression
            ])
            
            currentIndex = match.range.location + match.range.length
        }
        
        // 添加最后的文本
        if currentIndex < nsString.length {
            let text = nsString.substring(from: currentIndex)
            if !text.isEmpty {
                segments.append([
                    "type": "text",
                    "value": text
                ])
            }
        }
        
        return [
            "type": "template",
            "segments": segments
        ]
    }
    
    // MARK: - 条件表达式解析
    
    /// 解析条件表达式（用于 display 绑定等场景）
    public static func parseCondition(_ value: String) -> String {
        // 如果是 ${} 包裹的，提取内容
        if let expr = extractPureExpression(value) {
            return expr
        }
        // 否则直接返回（可能是简单的变量名）
        return value
    }
    
    // MARK: - For 循环解析（已废弃，保留用于兼容）
    
    /// 解析 for 循环表达式（已废弃，请使用 ListComponent）
    /// 支持格式：
    /// - "item in items"
    /// - "(item, index) in items"
    /// - "item in items :key item.id"
    public static func parseForExpression(_ value: String) -> ForExpressionResult? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // 提取 key 部分
        var mainPart = trimmed
        var keyExpression: String? = nil
        
        if let keyRange = trimmed.range(of: ":key ") {
            mainPart = String(trimmed[..<keyRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            keyExpression = String(trimmed[keyRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        
        // 解析主表达式
        guard let inRange = mainPart.range(of: " in ") else {
            return nil
        }
        
        let leftPart = String(mainPart[..<inRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        var itemsExpression = String(mainPart[inRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        
        // 如果 items 是表达式，提取
        if let expr = extractPureExpression(itemsExpression) {
            itemsExpression = expr
        }
        
        // 解析变量部分
        var itemName: String
        var indexName: String? = nil
        
        if leftPart.hasPrefix("(") && leftPart.hasSuffix(")") {
            // (item, index) 格式
            let inner = String(leftPart.dropFirst().dropLast())
            let parts = inner.split(separator: ",").map { 
                $0.trimmingCharacters(in: .whitespaces) 
            }
            itemName = parts[0]
            if parts.count > 1 {
                indexName = parts[1]
            }
        } else {
            // item 格式
            itemName = leftPart
        }
        
        return ForExpressionResult(
            itemName: itemName,
            indexName: indexName,
            itemsExpression: itemsExpression,
            keyExpression: keyExpression
        )
    }
    
    // MARK: - 事件表达式解析
    
    /// 解析事件表达式
    /// 支持格式：
    /// - "handleClick"
    /// - "handleClick()"
    /// - "handleClick(item.id)"
    /// - "navigateTo('detail', {id: item.id})"
    public static func parseEventExpression(_ value: String) -> EventExpressionResult {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // 检查是否是函数调用
        if let parenIndex = trimmed.firstIndex(of: "(") {
            let methodName = String(trimmed[..<parenIndex])
            let argsStart = trimmed.index(after: parenIndex)
            let argsEnd = trimmed.lastIndex(of: ")") ?? trimmed.endIndex
            let argsString = String(trimmed[argsStart..<argsEnd])
            
            return EventExpressionResult(
                type: .method,
                methodName: methodName,
                arguments: argsString.isEmpty ? nil : argsString,
                rawExpression: trimmed
            )
        } else {
            // 简单的方法名
            return EventExpressionResult(
                type: .method,
                methodName: trimmed,
                arguments: nil,
                rawExpression: trimmed
            )
        }
    }
}

// MARK: - 数据结构

/// 表达式匹配结果
public struct ExpressionMatch {
    /// 完整匹配（包含 ${}）
    public let fullMatch: String
    /// 表达式内容
    public let expression: String
    /// 匹配范围
    public let range: NSRange
}

/// For 表达式解析结果
public struct ForExpressionResult {
    /// 循环项变量名
    public let itemName: String
    /// 索引变量名（可选）
    public let indexName: String?
    /// 集合表达式
    public let itemsExpression: String
    /// Key 表达式（可选）
    public let keyExpression: String?
    
    /// 转换为 JSON
    public func toJSON() -> [String: Any] {
        var result: [String: Any] = [
            "item": itemName,
            "items": itemsExpression
        ]
        
        if let index = indexName {
            result["index"] = index
        }
        
        if let key = keyExpression {
            result["key"] = key
        }
        
        return result
    }
}

/// 事件表达式解析结果
public struct EventExpressionResult {
    /// 事件类型
    public let type: EventType
    /// 方法名
    public let methodName: String?
    /// 参数
    public let arguments: String?
    /// 原始表达式
    public let rawExpression: String
    
    public enum EventType {
        case method
        case expression
        case route
    }
    
    /// 转换为 JSON
    public func toJSON() -> [String: Any] {
        var result: [String: Any] = [
            "type": typeString
        ]
        
        if let method = methodName {
            result["method"] = method
        }
        
        if let args = arguments {
            result["args"] = args
        }
        
        return result
    }
    
    private var typeString: String {
        switch type {
        case .method:
            return "method"
        case .expression:
            return "expression"
        case .route:
            return "route"
        }
    }
}
