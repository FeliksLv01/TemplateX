import Foundation

// MARK: - XML → JSON 编译器

/// XML → JSON 编译器 - 将 XML 模板编译为运行态 JSON
public final class XMLToJSONCompiler {
    
    // MARK: - 配置
    
    /// 编译选项
    public struct Options {
        /// 是否压缩输出
        public var minify: Bool = false
        
        /// 是否保留调试信息
        public var debug: Bool = false
        
        /// 是否预编译表达式
        public var precompileExpressions: Bool = true
        
        /// 是否压缩枚举值
        public var compressEnums: Bool = true
        
        /// 是否内联样式
        public var inlineStyles: Bool = true
        
        public init() {}
    }
    
    /// 编译器选项
    public var options: Options
    
    // MARK: - 状态
    
    /// 模板元信息
    private var metaInfo: TemplateMetaInfo?
    
    /// 表达式池（用于去重）
    private var expressionPool: [[String: Any]] = []
    private var expressionMap: [String: Int] = [:]
    
    /// 字符串池（用于去重）
    private var stringPool: [String] = []
    private var stringMap: [String: Int] = [:]
    
    /// 编译错误
    private var errors: [CompileError] = []
    private var warnings: [CompileWarning] = []
    
    // MARK: - Init
    
    public init(options: Options = Options()) {
        self.options = options
    }
    
    // MARK: - 编译入口
    
    /// 编译 XML 字符串
    public func compile(_ xmlString: String) throws -> [String: Any] {
        let parser = TemplateXMLParser()
        let rootNode = try parser.parse(xmlString)
        return try compile(rootNode)
    }
    
    /// 编译 XML 文件
    public func compile(fileURL: URL) throws -> [String: Any] {
        let parser = TemplateXMLParser()
        let rootNode = try parser.parse(fileURL: fileURL)
        return try compile(rootNode)
    }
    
    /// 编译 XMLNode 树
    public func compile(_ root: XMLNode) throws -> [String: Any] {
        // 重置状态
        resetState()
        
        // 解析模板元信息
        if root.name == "Template" {
            metaInfo = parseTemplateMetaInfo(root)
            
            // 编译根节点的第一个子节点作为实际视图
            guard let viewRoot = root.children.first else {
                throw CompileError.emptyTemplate
            }
            
            return buildTemplateJSON(viewRoot: viewRoot)
        } else {
            // 直接作为视图节点编译
            return buildTemplateJSON(viewRoot: root)
        }
    }
    
    /// 编译为 JSON 字符串
    public func compileToString(_ xmlString: String) throws -> String {
        let json = try compile(xmlString)
        return try jsonToString(json)
    }
    
    /// 编译并写入文件
    public func compile(_ xmlString: String, outputURL: URL) throws {
        let json = try compile(xmlString)
        let jsonString = try jsonToString(json)
        try jsonString.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Private - 构建 JSON
    
    private func buildTemplateJSON(viewRoot: XMLNode) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // 模板信息
        if let meta = metaInfo {
            result["name"] = meta.name
            result["version"] = meta.version
            if let desc = meta.description {
                result["description"] = desc
            }
        }
        
        // 编译视图树
        result["root"] = compileNode(viewRoot)
        
        // 表达式池（如果启用预编译）
        if options.precompileExpressions && !expressionPool.isEmpty {
            result["expressions"] = [
                "precompiled": true,
                "pool": expressionPool
            ]
        }
        
        // 调试信息
        if options.debug {
            result["_debug"] = [
                "errors": errors.map { $0.errorDescription ?? String(describing: $0) },
                "warnings": warnings.map { $0.description },
                "compiler": "TemplateX XMLCompiler v1.0"
            ]
        }
        
        return result
    }
    
    /// 编译单个节点
    private func compileNode(_ node: XMLNode) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // 组件类型
        let componentType = AttributeMapper.componentType(for: node.name)
        result["type"] = componentType
        
        // 节点 ID
        if let id = node.attribute("id") {
            result["id"] = id
        }
        
        // 编译属性
        let (props, bindings, events) = compileAttributes(node, componentType: componentType)
        
        if !props.isEmpty {
            result["props"] = props
        }
        
        if !bindings.isEmpty {
            result["bindings"] = bindings
        }
        
        if !events.isEmpty {
            result["events"] = events
        }
        
        // 编译子节点
        if !node.children.isEmpty {
            result["children"] = compileChildren(node.children)
        }
        
        // 文本内容
        if let text = node.textContent, !text.isEmpty {
            // 检查是否包含表达式
            if ExpressionExtractor.containsExpression(text) {
                if var existingBindings = result["bindings"] as? [String: Any] {
                    existingBindings["text"] = compileBinding(text)
                    result["bindings"] = existingBindings
                } else {
                    result["bindings"] = ["text": compileBinding(text)]
                }
            } else {
                if var existingProps = result["props"] as? [String: Any] {
                    existingProps["text"] = text
                    result["props"] = existingProps
                } else {
                    result["props"] = ["text": text]
                }
            }
        }
        
        return result
    }
    
    /// 编译子节点列表
    private func compileChildren(_ children: [XMLNode]) -> [[String: Any]] {
        // 直接编译所有子节点（已移除 If/ForEach/x-if 指令支持）
        return children.map { compileNode($0) }
    }
    
    // MARK: - 属性编译
    
    /// 编译属性
    private func compileAttributes(_ node: XMLNode, componentType: String) -> (
        props: [String: Any],
        bindings: [String: Any],
        events: [String: Any]
    ) {
        var props: [String: Any] = [:]
        var bindings: [String: Any] = [:]
        var events: [String: Any] = [:]
        
        for (key, value) in node.attributes {
            // 跳过 id（已单独处理）
            if key == "id" { continue }
            
            let category = AttributeMapper.attributeCategory(for: key)
            
            switch category {
            case .layout:
                compileLayoutAttribute(key: key, value: value, into: &props, bindings: &bindings)
                
            case .style:
                compileStyleAttribute(key: key, value: value, into: &props, bindings: &bindings)
                
            case .text:
                compileTextAttribute(key: key, value: value, into: &props, bindings: &bindings)
                
            case .image:
                compileImageAttribute(key: key, value: value, into: &props, bindings: &bindings)
                
            case .event:
                compileEventAttribute(key: key, value: value, into: &events)
                
            case .directive:
                // x- 指令已废弃，跳过
                break
                
            case .identity:
                // 已处理
                break
                
            case .custom:
                // 自定义属性，保持原样
                if ExpressionExtractor.containsExpression(value) {
                    bindings[key] = compileBinding(value)
                } else {
                    props[key] = value
                }
            }
        }
        
        return (props, bindings, events)
    }
    
    /// 编译布局属性
    private func compileLayoutAttribute(
        key: String,
        value: String,
        into props: inout [String: Any],
        bindings: inout [String: Any]
    ) {
        let mappedKey = AttributeMapper.layoutAttributeMap[key] ?? key
        
        // 检查是否是表达式
        if ExpressionExtractor.containsExpression(value) {
            bindings[mappedKey] = compileBinding(value)
            return
        }
        
        // 处理枚举值
        if ["orientation", "flexDirection", "justifyContent", "alignItems", 
            "alignContent", "alignSelf", "flexWrap", "position"].contains(mappedKey) {
            if options.compressEnums {
                props[mappedKey] = AttributeMapper.mapEnumValue(attribute: mappedKey, value: value)
            } else {
                props[mappedKey] = value
            }
            return
        }
        
        // 处理尺寸值
        if ["width", "height", "minWidth", "minHeight", "maxWidth", "maxHeight",
            "top", "bottom", "left", "right", "start", "end"].contains(mappedKey) {
            props[mappedKey] = UnitParser.parseDimension(value)
            return
        }
        
        // 处理边距
        if ["margin", "padding"].contains(mappedKey) {
            props[mappedKey] = UnitParser.parseEdgeInsets(value)
            return
        }
        
        // 单边边距
        if mappedKey.hasPrefix("margin") || mappedKey.hasPrefix("padding") {
            props[mappedKey] = UnitParser.parseNumericValue(value)
            return
        }
        
        // 其他布局属性
        if let doubleValue = Double(value) {
            props[mappedKey] = doubleValue
        } else {
            props[mappedKey] = value
        }
    }
    
    /// 编译样式属性
    private func compileStyleAttribute(
        key: String,
        value: String,
        into props: inout [String: Any],
        bindings: inout [String: Any]
    ) {
        let mappedKey = AttributeMapper.styleAttributeMap[key] ?? key
        
        // 检查是否是表达式
        if ExpressionExtractor.containsExpression(value) {
            bindings[mappedKey] = compileBinding(value)
            return
        }
        
        // 颜色属性
        if ["backgroundColor", "borderColor", "shadowColor"].contains(mappedKey) {
            props[mappedKey] = UnitParser.parseColor(value)
            return
        }
        
        // 数值属性
        if ["borderWidth", "borderRadius", "shadowRadius", "shadowOpacity", 
            "opacity", "elevation"].contains(mappedKey) {
            props[mappedKey] = UnitParser.parseNumericValue(value)
            return
        }
        
        // 布尔属性
        if ["clipToBounds", "hidden", "visible"].contains(mappedKey) {
            props[mappedKey] = (value.lowercased() == "true" || value == "1")
            return
        }
        
        props[mappedKey] = value
    }
    
    /// 编译文本属性
    private func compileTextAttribute(
        key: String,
        value: String,
        into props: inout [String: Any],
        bindings: inout [String: Any]
    ) {
        let mappedKey = AttributeMapper.textAttributeMap[key] ?? key
        
        // 检查是否是表达式
        if ExpressionExtractor.containsExpression(value) {
            bindings[mappedKey] = compileBinding(value)
            return
        }
        
        // 字体大小
        if mappedKey == "fontSize" {
            props[mappedKey] = UnitParser.parseFontSize(value)
            return
        }
        
        // 字重
        if mappedKey == "fontWeight" {
            if options.compressEnums {
                props[mappedKey] = AttributeMapper.mapEnumValue(attribute: "fontWeight", value: value)
            } else {
                props[mappedKey] = value
            }
            return
        }
        
        // 文本对齐
        if mappedKey == "textAlign" {
            if options.compressEnums {
                props[mappedKey] = AttributeMapper.mapEnumValue(attribute: "textAlign", value: value)
            } else {
                props[mappedKey] = value
            }
            return
        }
        
        // 省略模式
        if mappedKey == "ellipsize" {
            if options.compressEnums {
                props[mappedKey] = AttributeMapper.mapEnumValue(attribute: "ellipsize", value: value)
            } else {
                props[mappedKey] = value
            }
            return
        }
        
        // 最大行数
        if mappedKey == "maxLines" {
            props[mappedKey] = Int(value) ?? 0
            return
        }
        
        // 颜色
        if mappedKey == "textColor" {
            props[mappedKey] = UnitParser.parseColor(value)
            return
        }
        
        // 行高、字间距
        if ["lineHeight", "letterSpacing"].contains(mappedKey) {
            props[mappedKey] = UnitParser.parseNumericValue(value)
            return
        }
        
        props[mappedKey] = value
    }
    
    /// 编译图片属性
    private func compileImageAttribute(
        key: String,
        value: String,
        into props: inout [String: Any],
        bindings: inout [String: Any]
    ) {
        let mappedKey = AttributeMapper.imageAttributeMap[key] ?? key
        
        // 检查是否是表达式
        if ExpressionExtractor.containsExpression(value) {
            bindings[mappedKey] = compileBinding(value)
            return
        }
        
        // 缩放模式
        if mappedKey == "scaleType" {
            if options.compressEnums {
                props[mappedKey] = AttributeMapper.mapEnumValue(attribute: "scaleType", value: value)
            } else {
                props[mappedKey] = value
            }
            return
        }
        
        // 颜色
        if mappedKey == "tintColor" {
            props[mappedKey] = UnitParser.parseColor(value)
            return
        }
        
        props[mappedKey] = value
    }
    
    /// 编译事件属性
    private func compileEventAttribute(
        key: String,
        value: String,
        into events: inout [String: Any]
    ) {
        // 移除 on 前缀，转为事件类型
        var eventType = key
        if key.hasPrefix("on") {
            eventType = String(key.dropFirst(2))
            eventType = eventType.prefix(1).lowercased() + eventType.dropFirst()
        }
        
        // 检查修饰符
        let parts = eventType.split(separator: ".")
        eventType = String(parts[0])
        let modifiers = parts.dropFirst().map { String($0) }
        
        // 映射事件类型
        if let mappedType = AttributeMapper.eventAttributeMap[key] {
            eventType = mappedType
        }
        
        // 解析事件表达式
        let eventResult = ExpressionExtractor.parseEventExpression(value)
        var eventConfig = eventResult.toJSON()
        
        if !modifiers.isEmpty {
            eventConfig["modifiers"] = modifiers
        }
        
        events[eventType] = eventConfig
    }
    

    // MARK: - 表达式编译
    
    /// 编译绑定表达式
    private func compileBinding(_ value: String) -> [String: Any] {
        if ExpressionExtractor.isPureExpression(value) {
            let expr = ExpressionExtractor.extractPureExpression(value)!
            return addToExpressionPool(expr)
        } else {
            // 混合字符串
            return ExpressionExtractor.compileMixedString(value) ?? ["value": value]
        }
    }
    
    /// 添加到表达式池
    private func addToExpressionPool(_ expression: String) -> [String: Any] {
        if options.precompileExpressions {
            // 检查是否已存在
            if let index = expressionMap[expression] {
                return ["ref": index]
            }
            
            // 添加到池中
            let index = expressionPool.count
            let entry: [String: Any] = [
                "id": index,
                "expr": expression
            ]
            expressionPool.append(entry)
            expressionMap[expression] = index
            
            return ["ref": index]
        } else {
            return ["expr": expression]
        }
    }
    

    // MARK: - Helpers
    
    /// 重置状态
    private func resetState() {
        metaInfo = nil
        expressionPool.removeAll()
        expressionMap.removeAll()
        stringPool.removeAll()
        stringMap.removeAll()
        errors.removeAll()
        warnings.removeAll()
    }
    
    /// 解析模板元信息
    private func parseTemplateMetaInfo(_ node: XMLNode) -> TemplateMetaInfo {
        return TemplateMetaInfo(
            name: node.attribute("name") ?? "unnamed",
            version: node.attribute("version") ?? "1.0",
            description: node.attribute("description")
        )
    }
    
    /// JSON 转字符串
    private func jsonToString(_ json: [String: Any]) throws -> String {
        let options: JSONSerialization.WritingOptions = self.options.minify 
            ? [] 
            : [.prettyPrinted, .sortedKeys]
        
        let data = try JSONSerialization.data(withJSONObject: json, options: options)
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw CompileError.jsonEncodingFailed
        }
        
        return string
    }
}

// MARK: - 错误类型

/// 编译错误
public enum CompileError: Error, LocalizedError {
    case emptyTemplate
    case invalidXML(String)
    case unknownElement(String)
    case missingRequiredAttribute(element: String, attribute: String)
    case invalidAttributeValue(element: String, attribute: String, value: String)
    case jsonEncodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .emptyTemplate:
            return "Template is empty"
        case .invalidXML(let message):
            return "Invalid XML: \(message)"
        case .unknownElement(let name):
            return "Unknown element: \(name)"
        case .missingRequiredAttribute(let element, let attribute):
            return "Missing required attribute '\(attribute)' in element '\(element)'"
        case .invalidAttributeValue(let element, let attribute, let value):
            return "Invalid value '\(value)' for attribute '\(attribute)' in element '\(element)'"
        case .jsonEncodingFailed:
            return "Failed to encode JSON"
        }
    }
}

/// 编译警告
public struct CompileWarning {
    public let message: String
    public let location: SourceLocation?
    
    public var description: String {
        if let loc = location {
            return "[\(loc.description)] \(message)"
        }
        return message
    }
}
