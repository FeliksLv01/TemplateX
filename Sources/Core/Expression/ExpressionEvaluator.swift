import Foundation
import Antlr4

// MARK: - TerminalNode Safe Extension

/// TerminalNode 的安全扩展
/// ANTLR4 的 TerminalNodeImpl.getText() 内部会强制解包 symbol，
/// 即使使用可选链也会在 symbol 为 nil 时崩溃。
/// 此扩展通过直接访问 symbol 属性来安全获取文本。
extension TerminalNode {
    /// 安全获取节点文本，避免 symbol 为 nil 时崩溃
    func safeGetText() -> String? {
        // TerminalNode 协议要求有 getSymbol() 方法
        guard let symbol = getSymbol() else { return nil }
        return symbol.getText()
    }
}

/// 表达式求值器 - 基于 ANTLR4 Visitor 模式
/// 
/// 遍历 AST 并计算表达式值，支持：
/// - 算术运算: +, -, *, /, %
/// - 比较运算: ==, !=, <, >, <=, >=
/// - 逻辑运算: &&, ||, !
/// - 三元表达式: condition ? trueValue : falseValue
/// - 成员访问: obj.member
/// - 索引访问: arr[index]
/// - 函数调用: func(args...)
public final class ExpressionEvaluator: TemplateXExprBaseVisitor<Any> {
    
    // MARK: - Properties
    
    /// 数据上下文
    private let context: [String: Any]
    
    /// 内置函数注册表
    private let functions: [String: ExpressionFunction]
    
    // MARK: - Initialization
    
    public init(context: [String: Any], functions: [String: ExpressionFunction] = [:]) {
        self.context = context
        // 合并内置函数和自定义函数
        self.functions = BuiltinFunctions.all.merging(functions) { _, custom in custom }
    }
    
    // MARK: - Entry Point
    
    public override func visitExpression(_ ctx: TemplateXExprParser.ExpressionContext) -> Any? {
        guard let ternary = ctx.ternary() else { return nil }
        return visit(ternary)
    }
    
    // MARK: - Ternary Expression
    
    public override func visitTernary(_ ctx: TemplateXExprParser.TernaryContext) -> Any? {
        // 如果有 ? :，则是三元表达式
        let ternaryChildren = ctx.ternary()
        if ternaryChildren.count == 2 {
            guard let logicalOr = ctx.logicalOr() else { return nil }
            let condition = toBool(visit(logicalOr))
            return condition ? visit(ternaryChildren[0]) : visit(ternaryChildren[1])
        }
        
        // 否则直接返回 logicalOr 的结果
        guard let logicalOr = ctx.logicalOr() else { return nil }
        return visit(logicalOr)
    }
    
    // MARK: - Logical Operations
    
    public override func visitLogicalOr(_ ctx: TemplateXExprParser.LogicalOrContext) -> Any? {
        let children = ctx.logicalAnd()
        guard !children.isEmpty else { return nil }
        
        // 如果只有一个子节点，直接返回其值（不转换为 Bool）
        if children.count == 1 {
            return visit(children[0])
        }
        
        // 有多个子节点时才进行逻辑或运算
        var result = toBool(visit(children[0]))
        
        // 短路求值
        for i in 1..<children.count {
            if result { return true }
            result = result || toBool(visit(children[i]))
        }
        
        return result
    }
    
    public override func visitLogicalAnd(_ ctx: TemplateXExprParser.LogicalAndContext) -> Any? {
        let children = ctx.equality()
        guard !children.isEmpty else { return nil }
        
        // 如果只有一个子节点，直接返回其值（不转换为 Bool）
        if children.count == 1 {
            return visit(children[0])
        }
        
        // 有多个子节点时才进行逻辑与运算
        var result = toBool(visit(children[0]))
        
        // 短路求值
        for i in 1..<children.count {
            if !result { return false }
            result = result && toBool(visit(children[i]))
        }
        
        return result
    }
    
    // MARK: - Comparison Operations
    
    public override func visitEquality(_ ctx: TemplateXExprParser.EqualityContext) -> Any? {
        let children = ctx.comparison()
        guard !children.isEmpty else { return nil }
        
        var result = visit(children[0])
        
        // 获取运算符 (在 comparison 节点之间)
        let childCount = ctx.getChildCount()
        var opIndex = 1
        
        for i in 1..<children.count {
            guard opIndex < childCount else { break }
            let opText = (ctx.getChild(opIndex) as? TerminalNode)?.safeGetText() ?? ""
            let right = visit(children[i])
            result = compareEqual(result, right, op: opText)
            opIndex += 2  // 跳过下一个 comparison 到下一个运算符
        }
        
        return result
    }
    
    public override func visitComparison(_ ctx: TemplateXExprParser.ComparisonContext) -> Any? {
        let children = ctx.additive()
        guard !children.isEmpty else { return nil }
        
        var result = visit(children[0])
        
        let childCount = ctx.getChildCount()
        var opIndex = 1
        
        for i in 1..<children.count {
            guard opIndex < childCount else { break }
            let opText = (ctx.getChild(opIndex) as? TerminalNode)?.safeGetText() ?? ""
            let right = visit(children[i])
            result = compareOrder(result, right, op: opText)
            opIndex += 2
        }
        
        return result
    }
    
    // MARK: - Arithmetic Operations
    
    public override func visitAdditive(_ ctx: TemplateXExprParser.AdditiveContext) -> Any? {
        let children = ctx.multiplicative()
        guard !children.isEmpty else { return nil }
        
        var result = visit(children[0])
        
        let childCount = ctx.getChildCount()
        var opIndex = 1
        
        for i in 1..<children.count {
            guard opIndex < childCount else { break }
            let opText = (ctx.getChild(opIndex) as? TerminalNode)?.safeGetText() ?? ""
            let right = visit(children[i])
            
            // 字符串拼接
            if opText == "+", let leftStr = result as? String {
                result = leftStr + toString(right)
            } else if opText == "+", let rightStr = right as? String {
                result = toString(result) + rightStr
            } else {
                // 数值运算
                let leftNum = toDouble(result)
                let rightNum = toDouble(right)
                result = opText == "+" ? leftNum + rightNum : leftNum - rightNum
            }
            
            opIndex += 2
        }
        
        return result
    }
    
    public override func visitMultiplicative(_ ctx: TemplateXExprParser.MultiplicativeContext) -> Any? {
        let children = ctx.unary()
        guard !children.isEmpty else {
            return nil
        }
        
        let firstResult = visit(children[0])
        
        // 如果只有一个子节点（没有乘除运算），直接返回原始值，不转换为 Double
        if children.count == 1 {
            return firstResult
        }
        
        // 有乘除运算时才转换为数字
        var result = toDouble(firstResult)
        
        let childCount = ctx.getChildCount()
        var opIndex = 1
        
        for i in 1..<children.count {
            guard opIndex < childCount else { break }
            let opText = (ctx.getChild(opIndex) as? TerminalNode)?.safeGetText() ?? ""
            let right = toDouble(visit(children[i]))
            
            switch opText {
            case "*": result = result * right
            case "/": result = right != 0 ? result / right : 0
            case "%": result = right != 0 ? result.truncatingRemainder(dividingBy: right) : 0
            default: break
            }
            
            opIndex += 2
        }
        
        return result
    }
    
    // MARK: - Unary Operations
    
    public override func visitUnary(_ ctx: TemplateXExprParser.UnaryContext) -> Any? {
        
        // 检查是否有一元运算符
        if let unary = ctx.unary() {
            let value = visit(unary)
            // 检查是 ! 还是 -
            if ctx.NOT() != nil {
                return !toBool(value)
            } else if ctx.MINUS() != nil {
                return -toDouble(value)
            }
        }
        
        // 否则访问 postfix
        guard let postfix = ctx.postfix() else {
            return nil
        }
        return visit(postfix)
    }
    
    // MARK: - Postfix Operations
    
    public override func visitPostfix(_ ctx: TemplateXExprParser.PostfixContext) -> Any? {
        guard let primary = ctx.primary() else {
            return nil
        }
        
        // 手动分发到具体的 visitor 方法
        // 原因：ANTLR 生成的 accept() 方法使用 `visitor as? TemplateXExprBaseVisitor` 做类型检查，
        // 但 Swift 泛型不支持将 `TemplateXExprBaseVisitor<Any>` 转换为未指定参数的 `TemplateXExprBaseVisitor`，
        // 导致分发失败，visitIdentifier/visitStringLiteral 等方法不会被调用。
        var result: Any?
        switch primary {
        case let ctx as TemplateXExprParser.IdentifierContext:
            result = visitIdentifier(ctx)
        case let ctx as TemplateXExprParser.StringLiteralContext:
            result = visitStringLiteral(ctx)
        case let ctx as TemplateXExprParser.NumberLiteralContext:
            result = visitNumberLiteral(ctx)
        case let ctx as TemplateXExprParser.TrueLiteralContext:
            result = visitTrueLiteral(ctx)
        case let ctx as TemplateXExprParser.FalseLiteralContext:
            result = visitFalseLiteral(ctx)
        case let ctx as TemplateXExprParser.NullLiteralContext:
            result = visitNullLiteral(ctx)
        case let ctx as TemplateXExprParser.ParenthesizedContext:
            result = visitParenthesized(ctx)
        case let ctx as TemplateXExprParser.ArrayExprContext:
            result = visitArrayExpr(ctx)
        case let ctx as TemplateXExprParser.ObjectExprContext:
            result = visitObjectExpr(ctx)
        default:
            // fallback 到默认的 visit（虽然可能不会工作，但保留以防万一）
            result = visit(primary)
        }
        
        // 处理后缀操作 (成员访问、函数调用、索引访问)
        for op in ctx.postfixOp() {
            if let memberAccess = op as? TemplateXExprParser.MemberAccessContext {
                result = visitMemberAccessOp(result, memberAccess)
            } else if let funcCall = op as? TemplateXExprParser.FunctionCallContext {
                result = visitFunctionCallOp(result, funcCall)
            } else if let indexAccess = op as? TemplateXExprParser.IndexAccessContext {
                result = visitIndexAccessOp(result, indexAccess)
            }
        }
        
        return result
    }
    
    private func visitMemberAccessOp(_ target: Any?, _ ctx: TemplateXExprParser.MemberAccessContext) -> Any? {
        guard let member = ctx.IDENTIFIER()?.safeGetText() else { return nil }
        return getMember(target, member)
    }
    
    private func visitFunctionCallOp(_ target: Any?, _ ctx: TemplateXExprParser.FunctionCallContext) -> Any? {
        // 收集参数
        var args: [Any] = []
        if let argList = ctx.argumentList() {
            for ternary in argList.ternary() {
                if let value = visit(ternary) {
                    args.append(value)
                }
            }
        }
        
        // 如果 target 是函数名（字符串），调用注册的函数
        if let funcName = target as? String, let function = functions[funcName] {
            return function.execute(args)
        }
        
        return nil
    }
    
    private func visitIndexAccessOp(_ target: Any?, _ ctx: TemplateXExprParser.IndexAccessContext) -> Any? {
        guard let expr = ctx.expression() else { return nil }
        let index = visit(expr)
        return getIndex(target, index)
    }
    
    // MARK: - Primary Expressions
    
    public override func visitNumberLiteral(_ ctx: TemplateXExprParser.NumberLiteralContext) -> Any? {
        guard let text = ctx.NUMBER()?.safeGetText() else { return 0.0 }
        return Double(text) ?? 0.0
    }
    
    public override func visitStringLiteral(_ ctx: TemplateXExprParser.StringLiteralContext) -> Any? {
        
        let stringNode = ctx.STRING()
        
        guard let terminalNode = stringNode else {
            return ""
        }
        
        let symbol = terminalNode.getSymbol()
        
        guard let token = symbol else {
            return ""
        }
        
        // 尝试获取文本 - 检查 token 的更多属性
        
        // 尝试从 inputStream 获取文本
        if let inputStream = token.getInputStream() {
            let start = token.getStartIndex()
            let stop = token.getStopIndex()
            if start >= 0 && stop >= start {
                do {
                    let text = try inputStream.getText(Interval.of(start, stop))
                    // 去掉首尾引号并处理转义
                    let result = unescapeString(String(text.dropFirst().dropLast()))
                    return result
                } catch {
                }
            }
        }
        
        guard let text = token.getText() else {
            return ""
        }
        
        // 去掉首尾引号并处理转义
        let result = unescapeString(String(text.dropFirst().dropLast()))
        return result
    }
    
    public override func visitTrueLiteral(_ ctx: TemplateXExprParser.TrueLiteralContext) -> Any? {
        return true
    }
    
    public override func visitFalseLiteral(_ ctx: TemplateXExprParser.FalseLiteralContext) -> Any? {
        return false
    }
    
    public override func visitNullLiteral(_ ctx: TemplateXExprParser.NullLiteralContext) -> Any? {
        return nil
    }
    
    public override func visitIdentifier(_ ctx: TemplateXExprParser.IdentifierContext) -> Any? {
        
        // 检查 IDENTIFIER token - 不使用 String(describing:) 避免触发 description 崩溃
        let identifierNode = ctx.IDENTIFIER()
        
        guard let terminalNode = identifierNode else {
            return nil
        }
        
        // 检查 symbol
        let symbol = terminalNode.getSymbol()
        
        guard let token = symbol else {
            return nil
        }
        
        // 打印 token 详情
        
        // 尝试从 inputStream 获取文本（因为 getText() 返回 nil）
        var name: String?
        if let inputStream = token.getInputStream() {
            let start = token.getStartIndex()
            let stop = token.getStopIndex()
            if start >= 0 && stop >= start {
                do {
                    name = try inputStream.getText(Interval.of(start, stop))
                } catch {
                }
            }
        }
        
        // fallback 到 getText()
        if name == nil {
            name = token.getText()
        }
        
        guard let identifierName = name else {
            return nil
        }
        
        
        // 先从上下文查找
        if let value = context[identifierName] {
            return value
        }
        
        // 如果是函数名，返回函数名字符串（用于后续的函数调用）
        if functions[identifierName] != nil {
            return identifierName
        }
        
        return nil
    }
    
    public override func visitParenthesized(_ ctx: TemplateXExprParser.ParenthesizedContext) -> Any? {
        guard let ternary = ctx.ternary() else { return nil }
        return visit(ternary)
    }
    
    public override func visitArrayExpr(_ ctx: TemplateXExprParser.ArrayExprContext) -> Any? {
        guard let arrayLiteral = ctx.arrayLiteral() else { return [] }
        return visit(arrayLiteral)
    }
    
    public override func visitArrayLiteral(_ ctx: TemplateXExprParser.ArrayLiteralContext) -> Any? {
        var elements: [Any] = []
        for ternary in ctx.ternary() {
            if let value = visit(ternary) {
                elements.append(value)
            }
        }
        return elements
    }
    
    public override func visitObjectExpr(_ ctx: TemplateXExprParser.ObjectExprContext) -> Any? {
        guard let objectLiteral = ctx.objectLiteral() else { return [:] as [String: Any] }
        return visit(objectLiteral)
    }
    
    public override func visitObjectLiteral(_ ctx: TemplateXExprParser.ObjectLiteralContext) -> Any? {
        var dict: [String: Any] = [:]
        for entry in ctx.objectEntry() {
            var keyString: String?
            
            // 优先使用 IDENTIFIER
            if let identifierText = entry.IDENTIFIER()?.safeGetText() {
                keyString = identifierText
            } else if let stringText = entry.STRING()?.safeGetText() {
                // 去掉首尾引号
                keyString = String(stringText.dropFirst().dropLast())
            }
            
            if let key = keyString,
               let ternary = entry.ternary(),
               let value = visit(ternary) {
                dict[key] = value
            }
        }
        return dict
    }
    
    // MARK: - Helper Methods
    
    private func toBool(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool: return bool
        case let num as Double: return num != 0
        case let num as Int: return num != 0
        case let str as String: return !str.isEmpty
        case let arr as [Any]: return !arr.isEmpty
        case let dict as [String: Any]: return !dict.isEmpty
        case .none: return false
        case .some: return true
        }
    }
    
    private func toDouble(_ value: Any?) -> Double {
        switch value {
        case let num as Double: return num
        case let num as Int: return Double(num)
        case let str as String: return Double(str) ?? 0
        case let bool as Bool: return bool ? 1 : 0
        default: return 0
        }
    }
    
    private func toString(_ value: Any?) -> String {
        switch value {
        case let str as String: return str
        case let num as Double: 
            return num.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(num)) : String(num)
        case let num as Int: return String(num)
        case let bool as Bool: return bool ? "true" : "false"
        case .none: return ""
        default: return String(describing: value!)
        }
    }
    
    private func isEqual(_ left: Any?, _ right: Any?) -> Bool {
        switch (left, right) {
        case (.none, .none): return true
        case (.none, _), (_, .none): return false
        case (let l as Bool, let r as Bool): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Int): return l == Double(r)
        case (let l as Int, let r as Double): return Double(l) == r
        case (let l as String, let r as String): return l == r
        default: return false
        }
    }
    
    private func compareEqual(_ left: Any?, _ right: Any?, op: String) -> Bool {
        switch op {
        case "==": return isEqual(left, right)
        case "!=": return !isEqual(left, right)
        default: return false
        }
    }
    
    private func compareOrder(_ left: Any?, _ right: Any?, op: String) -> Bool {
        let leftNum = toDouble(left)
        let rightNum = toDouble(right)
        
        switch op {
        case "<": return leftNum < rightNum
        case ">": return leftNum > rightNum
        case "<=": return leftNum <= rightNum
        case ">=": return leftNum >= rightNum
        default: return false
        }
    }
    
    private func getMember(_ obj: Any?, _ member: String) -> Any? {
        guard let dict = obj as? [String: Any] else { return nil }
        return dict[member]
    }
    
    private func getIndex(_ obj: Any?, _ index: Any?) -> Any? {
        if let arr = obj as? [Any], let idx = index as? Int {
            return idx >= 0 && idx < arr.count ? arr[idx] : nil
        }
        if let arr = obj as? [Any], let idx = index as? Double {
            let intIdx = Int(idx)
            return intIdx >= 0 && intIdx < arr.count ? arr[intIdx] : nil
        }
        if let dict = obj as? [String: Any], let key = index as? String {
            return dict[key]
        }
        return nil
    }
    
    private func unescapeString(_ str: String) -> String {
        var result = ""
        var iterator = str.makeIterator()
        
        while let char = iterator.next() {
            if char == "\\" {
                if let escaped = iterator.next() {
                    switch escaped {
                    case "n": result.append("\n")
                    case "t": result.append("\t")
                    case "r": result.append("\r")
                    case "\\": result.append("\\")
                    case "\"": result.append("\"")
                    case "'": result.append("'")
                    default: result.append(escaped)
                    }
                }
            } else {
                result.append(char)
            }
        }
        
        return result
    }
}
