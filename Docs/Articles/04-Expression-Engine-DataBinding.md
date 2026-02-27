# TemplateX：表达式引擎与数据绑定

> 本文是 TemplateX 系列文章的第 4 篇，深入解析表达式引擎的设计与实现，以及数据绑定机制。

## 先看效果

在 TemplateX 中，你可以这样使用表达式：

```json
{
  "type": "text",
  "props": {
    "text": "${user.name + ' - VIP ' + user.level}"
  }
}
```

```json
{
  "type": "container",
  "bindings": {
    "display": "${user.isVip && user.level > 3}"
  }
}
```

```json
{
  "type": "text",
  "props": {
    "text": "${formatNumber(price, 2) + ' 元'}"
  }
}
```

**支持的表达式特性：**

| 类别 | 示例 | 说明 |
|------|------|------|
| 属性访问 | `user.name` | 点语法访问 |
| 索引访问 | `items[0]` | 数组/字典索引 |
| 算术运算 | `price * 0.8` | +, -, *, /, % |
| 比较运算 | `count > 10` | ==, !=, <, >, <=, >= |
| 逻辑运算 | `a && b` | &&, \|\|, ! |
| 三元表达式 | `isVip ? 'VIP' : '普通'` | 条件判断 |
| 函数调用 | `formatDate(ts, 'yyyy-MM-dd')` | 30+ 内置函数 |
| 字符串拼接 | `'Hello ' + name` | 自动类型转换 |

**Question**: 如何设计一个高性能的表达式引擎，支持这些复杂的语法？

---

## 整体设计

### 表达式引擎架构

```
┌─────────────────────────────────────────────────────────────┐
│                    ExpressionEngine                          │
│                     (表达式引擎)                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐     ┌──────────────┐    ┌──────────────┐ │
│  │   Lexer      │────▶│    Parser    │───▶│   AST        │ │
│  │  (词法分析)   │     │   (语法分析)  │    │  (解析树)     │ │
│  └──────────────┘     └──────────────┘    └──────┬───────┘ │
│         ↑                                         │         │
│         │                                         ▼         │
│  ┌──────────────┐                        ┌──────────────┐  │
│  │ ANTLR4       │                        │  Evaluator   │  │
│  │ (.g4 语法)   │                        │   (求值器)    │  │
│  └──────────────┘                        └──────┬───────┘  │
│                                                  │          │
│  ┌──────────────────────────────────────────────┴───────┐  │
│  │                    LRU Cache                          │  │
│  │               (解析树缓存 256 条)                      │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 三层架构

| 层级 | 模块 | 职责 |
|------|------|------|
| **语法层** | ANTLR4 Grammar | 定义表达式语法规则 |
| **解析层** | ExpressionEngine | 词法分析 + 语法分析 + 缓存 |
| **求值层** | ExpressionEvaluator | 遍历 AST 计算结果 |
| **绑定层** | DataBindingManager | 递归绑定组件树 |

---

## Step 1: ANTLR4 语法定义

### 为什么选择 ANTLR4？

| 方案 | 优点 | 缺点 |
|------|------|------|
| 手写解析器 | 灵活、无依赖 | 工作量大、易出错 |
| 正则表达式 | 简单 | 不支持嵌套、难维护 |
| **ANTLR4** | 自动生成、支持复杂语法 | 需要依赖库 |
| JavaScriptCore | 完整 JS 支持 | 重、性能差 |

**选择 ANTLR4 的理由：**
1. 语法描述清晰（`.g4` 文件）
2. 自动生成 Lexer + Parser
3. Visitor 模式遍历 AST
4. Swift 支持良好

### 语法文件：TemplateXExpr.g4

```antlr
/**
 * TemplateX 表达式语法
 */
grammar TemplateXExpr;

// ==================== Parser Rules ====================

/** 入口规则 */
expression
    : ternary EOF
    ;

/** 三元表达式: condition ? trueExpr : falseExpr */
ternary
    : logicalOr (QUESTION ternary COLON ternary)?
    ;

/** 逻辑或: a || b */
logicalOr
    : logicalAnd (OR logicalAnd)*
    ;

/** 逻辑与: a && b */
logicalAnd
    : equality (AND equality)*
    ;

/** 相等比较: a == b, a != b */
equality
    : comparison ((EQ | NE) comparison)*
    ;

/** 大小比较: a < b, a > b, a <= b, a >= b */
comparison
    : additive ((LT | GT | LE | GE) additive)*
    ;

/** 加减运算: a + b, a - b */
additive
    : multiplicative ((PLUS | MINUS) multiplicative)*
    ;

/** 乘除运算: a * b, a / b, a % b */
multiplicative
    : unary ((MUL | DIV | MOD) unary)*
    ;

/** 一元运算: !a, -a */
unary
    : NOT unary
    | MINUS unary
    | postfix
    ;

/** 后缀运算: 成员访问、函数调用、数组索引 */
postfix
    : primary postfixOp*
    ;

postfixOp
    : DOT IDENTIFIER                  # MemberAccess
    | LPAREN argumentList? RPAREN     # FunctionCall
    | LBRACK expression RBRACK        # IndexAccess
    ;

/** 基础表达式 */
primary
    : NUMBER                          # NumberLiteral
    | STRING                          # StringLiteral
    | TRUE                            # TrueLiteral
    | FALSE                           # FalseLiteral
    | NULL                            # NullLiteral
    | IDENTIFIER                      # Identifier
    | LPAREN ternary RPAREN           # Parenthesized
    | arrayLiteral                    # ArrayExpr
    | objectLiteral                   # ObjectExpr
    ;
```

### 运算符优先级

语法规则的顺序定义了优先级（从低到高）：

```
┌────────────────────────────────────────────────────┐
│                  运算符优先级                        │
├────────────────────────────────────────────────────┤
│                                                     │
│  低   ternary        ?:       三元表达式            │
│   ↓   logicalOr      ||       逻辑或                │
│   ↓   logicalAnd     &&       逻辑与                │
│   ↓   equality       == !=    相等比较              │
│   ↓   comparison     < > <= >=  大小比较            │
│   ↓   additive       + -      加减                  │
│   ↓   multiplicative * / %    乘除模                │
│   ↓   unary          ! -      一元运算              │
│  高   postfix        . [] ()  成员/索引/调用         │
│                                                     │
└────────────────────────────────────────────────────┘
```

---

## Step 2: ExpressionEngine 实现

### 核心类设计

```swift
/// 表达式引擎 - 带缓存的解析和求值
public final class ExpressionEngine {
    
    // MARK: - Singleton
    public static let shared = ExpressionEngine()
    
    // MARK: - Properties
    
    /// 解析树缓存（LRU，容量 256）
    private let parseTreeCache: LRUCache<String, CachedParseTree>
    
    /// 自定义函数注册表
    private var customFunctions: [String: ExpressionFunction] = [:]
    
    /// 高性能自旋锁（函数注册表访问）
    private var functionsLock = os_unfair_lock()
    
    // MARK: - Configuration
    
    /// 是否启用缓存（默认 true）
    public var cacheEnabled: Bool = true
}
```

### 解析流程（带缓存）

```swift
/// 解析表达式（带缓存）
@discardableResult
public func parse(_ expression: String) throws -> TemplateXExprParser.ExpressionContext {
    parseCount += 1
    
    // 1. 尝试从缓存获取
    if cacheEnabled, let cached = parseTreeCache.get(expression) {
        return cached.tree  // 缓存命中，直接返回
    }
    
    // 2. 缓存未命中，执行解析
    let tree = try parseInternal(expression)
    
    // 3. 存入缓存
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
    lexer.setTokenFactory(CommonTokenFactory(true))  // 强制复制 token 文本
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
```

**Tips**: `CommonTokenFactory(true)` 强制复制 token 文本到内存，避免 inputStream 释放后 `getText()` 返回 nil 的问题。

### 求值 API

```swift
/// 求值表达式
public func evaluate(_ expression: String, context: [String: Any]) -> ExpressionResult {
    evalCount += 1
    
    do {
        // 1. 解析（命中缓存则 O(1)）
        let tree = try parse(expression)
        
        // 2. 求值
        return evaluateTree(tree, context: context)
    } catch let error as ExpressionError {
        return .failure(error)
    } catch {
        return .failure(.parseError(error.localizedDescription, position: nil))
    }
}

/// 快速求值（便捷方法）
@inline(__always)
public func eval(_ expression: String, context: [String: Any], default defaultValue: Any? = nil) -> Any? {
    return evaluate(expression, context: context).value(or: defaultValue)
}
```

### 绑定表达式解析

TemplateX 使用 `${...}` 语法标记绑定表达式：

```swift
/// 检查是否包含绑定表达式
public func containsBinding(_ text: String) -> Bool {
    return text.contains("${") && text.contains("}")
}

/// 解析绑定表达式
/// 支持格式：
/// - "${expression}" - 纯表达式
/// - "prefix ${expr1} middle ${expr2} suffix" - 混合字符串
public func resolveBinding(_ text: String, context: [String: Any]) -> Any? {
    guard containsBinding(text) else {
        return text  // 无表达式，直接返回
    }
    
    // 纯表达式: ${...}
    if text.hasPrefix("${") && text.hasSuffix("}") 
       && text.filter({ $0 == "$" }).count == 1 {
        let expr = String(text.dropFirst(2).dropLast())
        return eval(expr, context: context)  // 返回原始类型
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
        let replacement = stringValue(value)  // 转为字符串
        
        result.replaceSubrange(range, with: replacement)
    }
    
    return result
}
```

**关键点**：
- 纯表达式 `${...}` 保留原始类型（Bool、Number、Array 等）
- 混合字符串强制转为 String 拼接

---

## Step 3: ExpressionEvaluator 求值器

### Visitor 模式遍历 AST

ANTLR4 生成的 Visitor 基类：

```swift
public class TemplateXExprBaseVisitor<T>: AbstractParseTreeVisitor<T> {
    open func visitExpression(_ ctx: TemplateXExprParser.ExpressionContext) -> T? { ... }
    open func visitTernary(_ ctx: TemplateXExprParser.TernaryContext) -> T? { ... }
    open func visitLogicalOr(_ ctx: TemplateXExprParser.LogicalOrContext) -> T? { ... }
    // ... 每个语法规则对应一个 visit 方法
}
```

TemplateX 的求值器继承并实现：

```swift
/// 表达式求值器 - 基于 ANTLR4 Visitor 模式
public final class ExpressionEvaluator: TemplateXExprBaseVisitor<Any> {
    
    /// 数据上下文
    private let context: [String: Any]
    
    /// 函数注册表（内置 + 自定义）
    private let functions: [String: ExpressionFunction]
    
    public init(context: [String: Any], functions: [String: ExpressionFunction] = [:]) {
        self.context = context
        // 合并内置函数和自定义函数（自定义优先）
        self.functions = BuiltinFunctions.all.merging(functions) { _, custom in custom }
    }
}
```

### 三元表达式求值

```swift
public override func visitTernary(_ ctx: TemplateXExprParser.TernaryContext) -> Any? {
    let ternaryChildren = ctx.ternary()
    
    // 如果有 ? :，则是三元表达式
    if ternaryChildren.count == 2 {
        guard let logicalOr = ctx.logicalOr() else { return nil }
        let condition = toBool(visit(logicalOr))
        
        // 短路求值：只计算需要的分支
        return condition ? visit(ternaryChildren[0]) : visit(ternaryChildren[1])
    }
    
    // 否则直接返回 logicalOr 的结果
    guard let logicalOr = ctx.logicalOr() else { return nil }
    return visit(logicalOr)
}
```

### 逻辑运算（短路求值）

```swift
public override func visitLogicalOr(_ ctx: TemplateXExprParser.LogicalOrContext) -> Any? {
    let children = ctx.logicalAnd()
    guard !children.isEmpty else { return nil }
    
    // 单个子节点：保留原始类型
    if children.count == 1 {
        return visit(children[0])
    }
    
    // 多个子节点：短路求值
    var result = toBool(visit(children[0]))
    
    for i in 1..<children.count {
        if result { return true }  // 短路：true || x = true
        result = result || toBool(visit(children[i]))
    }
    
    return result
}

public override func visitLogicalAnd(_ ctx: TemplateXExprParser.LogicalAndContext) -> Any? {
    let children = ctx.equality()
    guard !children.isEmpty else { return nil }
    
    if children.count == 1 {
        return visit(children[0])
    }
    
    var result = toBool(visit(children[0]))
    
    for i in 1..<children.count {
        if !result { return false }  // 短路：false && x = false
        result = result && toBool(visit(children[i]))
    }
    
    return result
}
```

**Tips**: 短路求值不仅是语义正确，还能提升性能（避免不必要的计算）。

### 算术运算 + 字符串拼接

```swift
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
        
        // 字符串拼接：任一侧为 String 时，+ 变为字符串拼接
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
```

### 成员访问与索引访问

```swift
public override func visitPostfix(_ ctx: TemplateXExprParser.PostfixContext) -> Any? {
    guard let primary = ctx.primary() else { return nil }
    
    // 先计算 primary 的值
    var result: Any? = visitPrimary(primary)
    
    // 处理后缀操作 (链式调用)
    for op in ctx.postfixOp() {
        if let memberAccess = op as? TemplateXExprParser.MemberAccessContext {
            // user.name → getMember(user, "name")
            result = visitMemberAccessOp(result, memberAccess)
            
        } else if let funcCall = op as? TemplateXExprParser.FunctionCallContext {
            // formatDate(...) → 调用函数
            result = visitFunctionCallOp(result, funcCall)
            
        } else if let indexAccess = op as? TemplateXExprParser.IndexAccessContext {
            // items[0] → getIndex(items, 0)
            result = visitIndexAccessOp(result, indexAccess)
        }
    }
    
    return result
}

private func getMember(_ obj: Any?, _ member: String) -> Any? {
    guard let dict = obj as? [String: Any] else { return nil }
    return dict[member]
}

private func getIndex(_ obj: Any?, _ index: Any?) -> Any? {
    // 数组索引
    if let arr = obj as? [Any], let idx = index as? Int {
        return idx >= 0 && idx < arr.count ? arr[idx] : nil
    }
    if let arr = obj as? [Any], let idx = index as? Double {
        let intIdx = Int(idx)
        return intIdx >= 0 && intIdx < arr.count ? arr[intIdx] : nil
    }
    // 字典索引
    if let dict = obj as? [String: Any], let key = index as? String {
        return dict[key]
    }
    return nil
}
```

### 标识符查找

```swift
public override func visitIdentifier(_ ctx: TemplateXExprParser.IdentifierContext) -> Any? {
    guard let name = ctx.IDENTIFIER()?.safeGetText() else { return nil }
    
    // 1. 从数据上下文查找
    if let value = context[name] {
        return value
    }
    
    // 2. 如果是函数名，返回函数名字符串
    //    （后续 FunctionCall 会用这个名字调用函数）
    if functions[name] != nil {
        return name
    }
    
    return nil
}
```

---

## Step 4: 内置函数库

### 函数协议

```swift
/// 表达式函数协议
public protocol ExpressionFunction {
    /// 函数名
    var name: String { get }
    
    /// 执行函数
    func execute(_ args: [Any]) -> Any?
}

/// 简单函数包装器
public struct SimpleFunction: ExpressionFunction {
    public let name: String
    private let handler: ([Any]) -> Any?
    
    public init(name: String, handler: @escaping ([Any]) -> Any?) {
        self.name = name
        self.handler = handler
    }
    
    public func execute(_ args: [Any]) -> Any? {
        handler(args)
    }
}
```

### 内置函数列表

| 类别 | 函数 | 示例 |
|------|------|------|
| **数学** | `abs`, `max`, `min`, `round`, `floor`, `ceil`, `sqrt`, `pow` | `max(a, b)` |
| **字符串** | `length`, `uppercase`, `lowercase`, `trim`, `substring`, `contains`, `startsWith`, `endsWith`, `replace`, `split`, `join` | `substring(str, 0, 5)` |
| **格式化** | `formatNumber`, `formatDate` | `formatNumber(price, 2)` |
| **条件** | `ifEmpty`, `ifNull` | `ifEmpty(name, '匿名')` |
| **类型转换** | `toString`, `toNumber`, `toBoolean` | `toString(count)` |
| **数组** | `first`, `last`, `indexOf`, `reverse` | `first(items)` |

### 实现示例

```swift
public enum BuiltinFunctions {
    
    public static let all: [String: ExpressionFunction] = [
        
        // 数学函数
        "abs": SimpleFunction(name: "abs") { args in
            guard let num = args.first else { return 0.0 }
            return abs(toDouble(num))
        },
        
        "max": SimpleFunction(name: "max") { args in
            let nums = args.map { toDouble($0) }
            return nums.max() ?? 0.0
        },
        
        // 字符串函数
        "substring": SimpleFunction(name: "substring") { args in
            guard let str = args.first as? String, args.count >= 2 else { return "" }
            
            let start = Int(toDouble(args[1]))
            let length = args.count > 2 ? Int(toDouble(args[2])) : str.count - start
            
            guard start >= 0 && start < str.count else { return "" }
            
            let startIndex = str.index(str.startIndex, offsetBy: start)
            let endIndex = str.index(startIndex, offsetBy: min(length, str.count - start))
            return String(str[startIndex..<endIndex])
        },
        
        // 格式化函数
        "formatNumber": SimpleFunction(name: "formatNumber") { args in
            guard let num = args.first else { return "" }
            let value = toDouble(num)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if args.count > 1, let decimals = args[1] as? Double {
                formatter.minimumFractionDigits = Int(decimals)
                formatter.maximumFractionDigits = Int(decimals)
            }
            return formatter.string(from: NSNumber(value: value)) ?? ""
        },
        
        "formatDate": SimpleFunction(name: "formatDate") { args in
            guard args.count >= 2,
                  let format = args[1] as? String else { return "" }
            
            let timestamp: TimeInterval
            if let ts = args[0] as? Double {
                timestamp = ts
            } else if let ts = args[0] as? Int {
                timestamp = Double(ts)
            } else {
                return ""
            }
            
            // 智能判断秒/毫秒
            let date: Date
            if timestamp > 1_000_000_000_000 {
                date = Date(timeIntervalSince1970: timestamp / 1000)  // 毫秒
            } else {
                date = Date(timeIntervalSince1970: timestamp)  // 秒
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter.string(from: date)
        },
        
        // 条件函数
        "ifEmpty": SimpleFunction(name: "ifEmpty") { args in
            guard args.count >= 2 else { return nil }
            let value = args[0]
            let fallback = args[1]
            
            if let str = value as? String, str.isEmpty {
                return fallback
            }
            if value is NSNull {
                return fallback
            }
            return value
        },
        
        // ... 更多函数
    ]
}
```

### 注册自定义函数

```swift
// 方式 1: 简单闭包
ExpressionEngine.shared.registerFunction(name: "formatPrice") { args in
    guard let price = args.first as? Double else { return "¥0.00" }
    return String(format: "¥%.2f", price)
}

// 方式 2: 协议实现
struct PluralizeFunction: ExpressionFunction {
    let name = "pluralize"
    
    func execute(_ args: [Any]) -> Any? {
        guard args.count >= 2,
              let count = args[0] as? Double,
              let singular = args[1] as? String else { return "" }
        
        let plural = args.count > 2 ? (args[2] as? String ?? singular + "s") : singular + "s"
        return count == 1 ? singular : plural
    }
}

ExpressionEngine.shared.registerFunction(PluralizeFunction())

// 使用
// ${pluralize(count, 'item', 'items')}
```

---

## Step 5: DataBindingManager 数据绑定

### 绑定流程

```
┌─────────────────────────────────────────────────────────────┐
│                     DataBindingManager                       │
└─────────────────────────────────────────────────────────────┘

  Component Tree          Data Context
       │                       │
       ▼                       ▼
  ┌─────────┐           ┌──────────┐
  │  Root   │◀──────────│   data   │
  │Component│           │   $data  │
  └────┬────┘           │  $index  │
       │                │ $parent  │
  ┌────┴────┐           └──────────┘
  │         │
  ▼         ▼
┌─────┐  ┌─────┐
│Child│  │Child│   ← 每个子组件构建独立上下文
└─────┘  └─────┘     $index, $parent 自动注入
```

### 递归绑定实现

```swift
public final class DataBindingManager {
    
    /// 表达式引擎
    private let expressionEngine: ExpressionEngine
    
    /// 绑定数据到组件树
    public func bind(
        data: [String: Any],
        to component: Component,
        templateData: [String: Any]? = nil
    ) {
        // 构建完整的数据上下文
        var context = data
        
        // 添加模板级数据
        if let templateData = templateData {
            context["templateData"] = templateData
        }
        
        // 添加内置变量
        context["$data"] = data  // 原始数据引用
        
        // 递归绑定
        bindRecursive(data: context, to: component)
    }
    
    /// 递归绑定
    private func bindRecursive(data: [String: Any], to component: Component) {
        // 1. 保存绑定数据
        if let baseComponent = component as? BaseComponent {
            baseComponent.bindings = data
            
            // 2. 解析 props 和 bindings 中的表达式
            if let json = baseComponent.jsonWrapper {
                resolveExpressions(json: json, data: data, component: baseComponent)
            }
            
            // 3. 特殊处理 ListComponent
            if let listComponent = baseComponent as? ListComponent {
                bindListComponent(listComponent, data: data)
            }
        }
        
        // 4. 递归处理子组件
        for (index, child) in component.children.enumerated() {
            var childContext = data
            childContext["$index"] = index    // 注入索引
            childContext["$parent"] = data    // 注入父上下文
            
            bindRecursive(data: childContext, to: child)
        }
    }
}
```

### 表达式解析与应用

```swift
private func resolveExpressions(
    json: JSONWrapper,
    data: [String: Any],
    component: BaseComponent
) {
    // 处理 props 中的表达式
    if let props = json.props {
        for (key, value) in props.rawDictionary {
            if let strValue = value as? String, 
               expressionEngine.containsBinding(strValue) {
                let resolvedValue = expressionEngine.resolveBinding(strValue, context: data)
                applyResolvedValue(key: key, value: resolvedValue, to: component)
            }
        }
    }
    
    // 处理 bindings 中的表达式
    if let bindings = json.bindings {
        for (key, value) in bindings.rawDictionary {
            if let strValue = value as? String,
               expressionEngine.containsBinding(strValue) {
                let resolvedValue = expressionEngine.resolveBinding(strValue, context: data)
                applyResolvedValue(key: key, value: resolvedValue, to: component)
            }
        }
    }
}

private func applyResolvedValue(key: String, value: Any?, to component: BaseComponent) {
    guard let value = value else { return }
    
    switch key {
    case "text":
        if let textComponent = component as? TextComponent {
            textComponent.text = stringValue(value)
        }
        
    case "src", "source", "imageUrl", "url":
        if let imageComponent = component as? ImageComponent {
            imageComponent.src = stringValue(value)
        }
        
    case "visible", "visibility":
        let isVisible = boolValue(value)
        component.style.visibility = isVisible ? .visible : .hidden
        
    case "display":
        // 支持布尔值或字符串
        let newDisplay: Display
        if let boolVal = value as? Bool {
            newDisplay = boolVal ? .flex : .none
        } else {
            let displayValue = stringValue(value).lowercased()
            newDisplay = displayValue == "none" ? .none : .flex
        }
        component.style.display = newDisplay
        
    case "opacity", "alpha":
        component.style.opacity = cgFloatValue(value)
        
    case "backgroundColor", "bgColor":
        if let colorValue = colorValue(value) {
            component.style.backgroundColor = colorValue
        }
        
    case "width":
        component.style.width = dimensionValue(value)
        
    case "height":
        component.style.height = dimensionValue(value)
        
    // ... 更多属性
    
    default:
        // 存储到 bindings 供组件自行处理
        component.bindings[key] = value
    }
}
```

### 列表绑定

```swift
private func bindListComponent(_ listComponent: ListComponent, data: [String: Any]) {
    // 方式 1：通过 props.items 表达式绑定
    if let itemsExpr = listComponent.props.items,
       expressionEngine.containsBinding(itemsExpr) {
        if let items = expressionEngine.resolveBinding(itemsExpr, context: data) as? [Any] {
            listComponent.dataSource = items
        }
    }
    // 方式 2：回退到 data["items"] 直接绑定
    else if let items = data["items"] as? [Any] {
        listComponent.dataSource = items
    }
    
    // 解析 estimatedItemHeight 表达式
    if let heightExpr = listComponent.props.estimatedItemHeightExpr,
       expressionEngine.containsBinding(heightExpr) {
        if let height = expressionEngine.resolveBinding(heightExpr, context: data) as? CGFloat {
            listComponent.resolvedEstimatedItemHeight = height
        }
    }
}

/// 绑定列表数据（for-each 循环）
public func bindList<T>(
    items: [T],
    itemKey: String = "item",
    to component: Component,
    templateFactory: (T, Int) -> Component
) -> [Component] {
    return items.enumerated().map { index, item in
        let childComponent = templateFactory(item, index)
        
        // 构建 item 上下文
        var itemContext: [String: Any] = [
            itemKey: item,
            "$index": index,
            "$first": index == 0,
            "$last": index == items.count - 1,
            "$odd": index % 2 == 1,
            "$even": index % 2 == 0
        ]
        
        // 如果 item 是字典，展开到上下文
        if let dict = item as? [String: Any] {
            for (key, value) in dict {
                itemContext[key] = value
            }
        }
        
        if let baseComponent = childComponent as? BaseComponent {
            baseComponent.bindings = itemContext
        }
        
        return childComponent
    }
}
```

---

## 性能优化

### 1. 解析树缓存

```swift
// 解析树缓存（LRU，容量 256）
private let parseTreeCache: LRUCache<String, CachedParseTree>

/// 缓存的解析树
final class CachedParseTree {
    let tree: TemplateXExprParser.ExpressionContext
    let sourceText: String  // 保存原始表达式
    let accessTime: Date
}
```

**缓存效果**：
- 首次解析：~0.5ms（ANTLR 词法 + 语法分析）
- 缓存命中：~0.01ms（直接返回解析树）

### 2. 函数注册表加锁

```swift
private var functionsLock = os_unfair_lock()

public func registerFunction(_ function: ExpressionFunction) {
    os_unfair_lock_lock(&functionsLock)
    defer { os_unfair_lock_unlock(&functionsLock) }
    customFunctions[function.name] = function
}
```

**为什么用 `os_unfair_lock`**：
- 比 `NSLock` 快 10 倍
- 比 `DispatchQueue` 快 5 倍
- 适合短临界区

### 3. 短路求值

```swift
// && 短路：第一个 false 立即返回
if !result { return false }

// || 短路：第一个 true 立即返回
if result { return true }
```

### 4. 类型保留

```swift
// 纯表达式保留原始类型
"${user.isVip}"  // → Bool(true)
"${items.count}" // → Double(10)

// 混合字符串转为 String
"VIP: ${user.isVip}" // → String("VIP: true")
```

### 性能数据

| 操作 | 首次 | 缓存命中 |
|------|------|---------|
| 简单表达式 `user.name` | 0.3ms | 0.02ms |
| 算术表达式 `price * 0.8` | 0.4ms | 0.03ms |
| 复杂表达式（10 个运算符） | 0.8ms | 0.08ms |
| 函数调用 `formatDate(...)` | 0.5ms | 0.05ms |

---

## 错误处理

### 错误类型

```swift
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
```

### 错误监听器

```swift
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
```

### 安全的默认值

```swift
// 使用 default 参数
let name = engine.eval("user.name", context: data, default: "匿名")

// 使用 ExpressionResult
let result = engine.evaluate("user.age", context: data)
switch result {
case .success(let value):
    print("Age: \(value ?? "unknown")")
case .failure(let error):
    print("Error: \(error)")
}
```

---

## 使用示例

### 模板中使用表达式

```json
{
  "type": "container",
  "style": {
    "flexDirection": "column",
    "padding": 16
  },
  "children": [
    {
      "type": "text",
      "props": {
        "text": "${user.name}"
      },
      "style": {
        "fontSize": 20,
        "fontWeight": "bold"
      }
    },
    {
      "type": "text",
      "props": {
        "text": "${'年龄: ' + user.age + ' 岁'}"
      },
      "style": {
        "fontSize": 14,
        "textColor": "#666666"
      }
    },
    {
      "type": "container",
      "bindings": {
        "display": "${user.isVip}"
      },
      "children": [
        {
          "type": "text",
          "props": {
            "text": "VIP 会员"
          },
          "style": {
            "fontSize": 12,
            "textColor": "#FF6B6B"
          }
        }
      ]
    },
    {
      "type": "text",
      "props": {
        "text": "${formatDate(user.createTime, 'yyyy-MM-dd HH:mm')}"
      },
      "style": {
        "fontSize": 12,
        "textColor": "#999999"
      }
    }
  ]
}
```

### 代码中使用

```swift
// 渲染
let data: [String: Any] = [
    "user": [
        "name": "张三",
        "age": 28,
        "isVip": true,
        "createTime": 1703030400000
    ]
]

let view = TemplateX.render(json: template, data: data)

// 更新数据
TemplateX.update(view: view, data: [
    "user": [
        "name": "张三",
        "age": 29,  // 年龄变化
        "isVip": true,
        "createTime": 1703030400000
    ]
])
```

---

## 小结

本文介绍了 TemplateX 表达式引擎的完整设计与实现：

| 模块 | 技术要点 |
|------|---------|
| **语法定义** | ANTLR4 语法文件，自动生成 Lexer/Parser |
| **解析缓存** | LRU 缓存解析树，避免重复解析 |
| **Visitor 求值** | 遍历 AST，短路求值，类型自动转换 |
| **内置函数** | 30+ 函数，支持自定义扩展 |
| **数据绑定** | 递归绑定组件树，注入上下文变量 |

**核心优化**：
- 解析树缓存（首次 0.5ms → 命中 0.01ms）
- 短路求值（避免不必要计算）
- `os_unfair_lock`（高性能锁）
- 类型保留（纯表达式保留原始类型）

---

## 下一篇预告

下一篇我们将深入 **Diff + Patch 增量更新**，包括：

- 为什么需要增量更新
- ViewDiffer 的 Diff 算法
- DiffPatcher 的 Patch 应用
- 组件树克隆与 ID 匹配
- 性能对比（全量 vs 增量）

---

## 系列文章

1. TemplateX 概述与架构设计
2. 模板解析与组件系统
3. Flexbox 布局引擎
4. **表达式引擎与数据绑定**（本文）
5. Diff + Patch 增量更新
6. GapWorker 列表优化
7. 性能优化实战

---

## 参考资料

- [ANTLR4 Documentation](https://www.antlr.org/) - ANTLR 官方文档
- [ANTLR4 Swift Target](https://github.com/antlr/antlr4/tree/master/runtime/Swift) - ANTLR4 Swift 运行时
- [Expression Language Design](https://docs.spring.io/spring-framework/docs/current/reference/html/core.html#expressions) - Spring EL 设计参考
