#!/usr/bin/env swift

import Foundation

// MARK: - 完整编译器测试
// 将所有编译器文件合并后测试 XML → JSON 编译

print("=" .repeated(60))
print("TemplateX Compiler Full Test")
print("=" .repeated(60))

// MARK: - SourceLocation
struct SourceLocation {
    let line: Int
    let column: Int
    let filePath: String?
    
    init(line: Int, column: Int, filePath: String? = nil) {
        self.line = line
        self.column = column
        self.filePath = filePath
    }
    
    var description: String {
        if let path = filePath {
            return "\(path):\(line):\(column)"
        }
        return "line \(line), column \(column)"
    }
}

// MARK: - XMLNode
final class XMLNode {
    let name: String
    var attributes: [String: String]
    var children: [XMLNode]
    var textContent: String?
    weak var parent: XMLNode?
    var sourceLocation: SourceLocation?
    
    init(name: String, attributes: [String: String] = [:], children: [XMLNode] = [], textContent: String? = nil) {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.textContent = textContent
    }
    
    func attribute(_ key: String) -> String? { attributes[key] }
}

// MARK: - TemplateMetaInfo
struct TemplateMetaInfo {
    let name: String
    let version: String
    let description: String?
}

// MARK: - XMLParseError
enum XMLParseError: Error {
    case invalidEncoding
    case emptyDocument
    case parsingFailed(String)
    case validationFailed(String)
    case unknownError
}

// MARK: - TemplateXMLParser
final class TemplateXMLParser: NSObject, XMLParserDelegate {
    private var rootNode: XMLNode?
    private var nodeStack: [XMLNode] = []
    private var currentTextContent: String = ""
    private var parseError: Error?
    
    func parse(_ xmlString: String) throws -> XMLNode {
        guard let data = xmlString.data(using: .utf8) else {
            throw XMLParseError.invalidEncoding
        }
        return try parse(data: data)
    }
    
    func parse(data: Data) throws -> XMLNode {
        rootNode = nil
        nodeStack.removeAll()
        currentTextContent = ""
        parseError = nil
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        let success = parser.parse()
        
        if let error = parseError { throw error }
        if !success { throw parser.parserError ?? XMLParseError.unknownError }
        guard let root = rootNode else { throw XMLParseError.emptyDocument }
        
        return root
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        flushTextContent()
        let node = XMLNode(name: elementName, attributes: attributes)
        node.sourceLocation = SourceLocation(line: parser.lineNumber, column: parser.columnNumber)
        if let parent = nodeStack.last {
            parent.children.append(node)
            node.parent = parent
        }
        nodeStack.append(node)
        if rootNode == nil { rootNode = node }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        flushTextContent()
        _ = nodeStack.popLast()
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentTextContent += string
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        self.parseError = XMLParseError.parsingFailed(error.localizedDescription)
    }
    
    private func flushTextContent() {
        let trimmed = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let current = nodeStack.last {
            current.textContent = trimmed
        }
        currentTextContent = ""
    }
}

// MARK: - ExpressionExtractor
struct ExpressionExtractor {
    static func containsExpression(_ value: String) -> Bool {
        return value.contains("${")
    }
    
    static func isPureExpression(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("${") && trimmed.hasSuffix("}") {
            let inner = String(trimmed.dropFirst(2).dropLast())
            return !inner.contains("${")
        }
        return false
    }
    
    static func extractPureExpression(_ value: String) -> String? {
        guard isPureExpression(value) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return String(trimmed.dropFirst(2).dropLast())
    }
}

// MARK: - AttributeCategory
enum AttributeCategory { case layout, style, text, image, event, directive, identity, custom }

// MARK: - AttributeMapper (简化版)
struct AttributeMapper {
    static let componentTypeMap: [String: String] = [
        "Flex": "flex", "Row": "flex", "Column": "flex",
        "View": "view", "Text": "text", "Image": "image",
        "ScrollView": "scroll", "ListView": "list", "Template": "template"
    ]
    
    static func componentType(for tagName: String) -> String {
        return componentTypeMap[tagName] ?? tagName.lowercased()
    }
    
    static let layoutKeys = Set(["width", "height", "margin", "padding", "flex", "flexDirection",
                                  "justifyContent", "alignItems", "marginTop", "marginBottom",
                                  "marginLeft", "marginRight", "paddingHorizontal", "paddingVertical"])
    static let styleKeys = Set(["backgroundColor", "borderRadius", "opacity", "hidden", "overflow"])
    static let textKeys = Set(["text", "fontSize", "fontWeight", "textColor", "maxLines", "ellipsize", "textDecoration"])
    static let imageKeys = Set(["src", "scaleType", "aspectRatio"])
    static let eventKeys = Set(["onClick", "onTap"])
    
    static func attributeCategory(for name: String) -> AttributeCategory {
        if layoutKeys.contains(name) { return .layout }
        if styleKeys.contains(name) { return .style }
        if textKeys.contains(name) { return .text }
        if imageKeys.contains(name) { return .image }
        if eventKeys.contains(name) { return .event }
        if name.hasPrefix("x-") { return .directive }
        if name == "id" { return .identity }
        return .custom
    }
}

// MARK: - XMLToJSONCompiler (简化版)
final class XMLToJSONCompiler {
    private var metaInfo: TemplateMetaInfo?
    
    func compile(_ xmlString: String) throws -> [String: Any] {
        let parser = TemplateXMLParser()
        let rootNode = try parser.parse(xmlString)
        return try compile(rootNode)
    }
    
    func compile(_ root: XMLNode) throws -> [String: Any] {
        metaInfo = nil
        
        if root.name == "Template" {
            metaInfo = TemplateMetaInfo(
                name: root.attribute("name") ?? "unnamed",
                version: root.attribute("version") ?? "1.0",
                description: root.attribute("description")
            )
            guard let viewRoot = root.children.first else {
                return ["error": "Empty template"]
            }
            return buildTemplateJSON(viewRoot: viewRoot)
        } else {
            return buildTemplateJSON(viewRoot: root)
        }
    }
    
    private func buildTemplateJSON(viewRoot: XMLNode) -> [String: Any] {
        var result: [String: Any] = [:]
        if let meta = metaInfo {
            result["name"] = meta.name
            result["version"] = meta.version
            if let desc = meta.description {
                result["description"] = desc
            }
        }
        result["root"] = compileNode(viewRoot)
        return result
    }
    
    private func compileNode(_ node: XMLNode) -> [String: Any] {
        var result: [String: Any] = [:]
        
        let componentType = AttributeMapper.componentType(for: node.name)
        result["type"] = componentType
        
        if let id = node.attribute("id") {
            result["id"] = id
        }
        
        var props: [String: Any] = [:]
        var bindings: [String: Any] = [:]
        var events: [String: Any] = [:]
        
        // 处理 Row/Column 的 flexDirection
        if node.name == "Row" {
            props["flexDirection"] = "row"
        } else if node.name == "Column" {
            props["flexDirection"] = "column"
        }
        
        for (key, value) in node.attributes {
            if key == "id" { continue }
            
            if ExpressionExtractor.containsExpression(value) {
                if let expr = ExpressionExtractor.extractPureExpression(value) {
                    bindings[key] = ["expr": expr]
                } else {
                    bindings[key] = ["expr": value]
                }
            } else if AttributeMapper.attributeCategory(for: key) == .event {
                events[key.replacingOccurrences(of: "on", with: "").lowercased()] = ["method": value]
            } else {
                // 尝试解析数值
                if let num = Double(value) {
                    props[key] = num
                } else {
                    props[key] = value
                }
            }
        }
        
        if !props.isEmpty { result["props"] = props }
        if !bindings.isEmpty { result["bindings"] = bindings }
        if !events.isEmpty { result["events"] = events }
        
        if !node.children.isEmpty {
            result["children"] = node.children.map { compileNode($0) }
        }
        
        if let text = node.textContent, !text.isEmpty {
            if ExpressionExtractor.containsExpression(text) {
                if var b = result["bindings"] as? [String: Any] {
                    b["text"] = ["expr": text]
                    result["bindings"] = b
                } else {
                    result["bindings"] = ["text": ["expr": text]]
                }
            } else {
                if var p = result["props"] as? [String: Any] {
                    p["text"] = text
                    result["props"] = p
                } else {
                    result["props"] = ["text": text]
                }
            }
        }
        
        return result
    }
}

// MARK: - String Extension
extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// MARK: - Test Runner

let testsPath = "/Users/lvyou4/Desktop/DSL/TemplateX/Compiler/Tests"
let testFiles = ["simple_card.xml", "product_card.xml", "user_profile.xml"]
let compiler = XMLToJSONCompiler()

for file in testFiles {
    let filePath = testsPath + "/" + file
    print("\n📄 Compiling: \(file)")
    print("-" .repeated(50))
    
    do {
        let xml = try String(contentsOfFile: filePath, encoding: .utf8)
        let json = try compiler.compile(xml)
        
        // 输出 JSON
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // 统计信息
        let nodeCount = countNodes(json)
        let bindingCount = countBindings(json)
        
        print("✅ Compilation successful!")
        print("   - Template: \(json["name"] ?? "N/A")")
        print("   - Version: \(json["version"] ?? "N/A")")
        print("   - Nodes: \(nodeCount)")
        print("   - Bindings: \(bindingCount)")
        print("   - JSON size: \(jsonData.count) bytes")
        
        // 保存 JSON
        let outputPath = filePath.replacingOccurrences(of: ".xml", with: ".json")
        try jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("   - Output: \(outputPath.split(separator: "/").last!)")
        
    } catch {
        print("❌ Error: \(error)")
    }
}

print("\n" + "=" .repeated(60))
print("All tests completed!")
print("=" .repeated(60))

// MARK: - Helpers

func countNodes(_ json: [String: Any]) -> Int {
    var count = 0
    if let root = json["root"] as? [String: Any] {
        count = countNodesRecursive(root)
    }
    return count
}

func countNodesRecursive(_ node: [String: Any]) -> Int {
    var count = 1
    if let children = node["children"] as? [[String: Any]] {
        for child in children {
            count += countNodesRecursive(child)
        }
    }
    return count
}

func countBindings(_ json: [String: Any]) -> Int {
    var count = 0
    if let root = json["root"] as? [String: Any] {
        count = countBindingsRecursive(root)
    }
    return count
}

func countBindingsRecursive(_ node: [String: Any]) -> Int {
    var count = 0
    if let bindings = node["bindings"] as? [String: Any] {
        count += bindings.count
    }
    if let children = node["children"] as? [[String: Any]] {
        for child in children {
            count += countBindingsRecursive(child)
        }
    }
    return count
}
