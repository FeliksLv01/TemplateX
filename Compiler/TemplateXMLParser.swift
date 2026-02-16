import Foundation

// MARK: - XML 解析器

/// XML 解析器 - 将 XML 字符串解析为 XMLNode 树
public final class TemplateXMLParser: NSObject {
    
    // MARK: - 解析状态
    
    private var rootNode: XMLNode?
    private var nodeStack: [XMLNode] = []
    private var currentTextContent: String = ""
    private var parseError: Error?
    
    // MARK: - Public API
    
    /// 解析 XML 字符串
    public func parse(_ xmlString: String) throws -> XMLNode {
        guard let data = xmlString.data(using: .utf8) else {
            throw XMLParseError.invalidEncoding
        }
        return try parse(data: data)
    }
    
    /// 解析 XML 数据
    public func parse(data: Data) throws -> XMLNode {
        // 重置状态
        rootNode = nil
        nodeStack.removeAll()
        currentTextContent = ""
        parseError = nil
        
        // 创建解析器
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        
        // 执行解析
        let success = parser.parse()
        
        // 检查错误
        if let error = parseError {
            throw error
        }
        
        if !success {
            throw parser.parserError ?? XMLParseError.unknownError
        }
        
        guard let root = rootNode else {
            throw XMLParseError.emptyDocument
        }
        
        return root
    }
    
    /// 从文件解析
    public func parse(fileURL: URL) throws -> XMLNode {
        let data = try Data(contentsOf: fileURL)
        return try parse(data: data)
    }
}

// MARK: - XMLParserDelegate

extension TemplateXMLParser: XMLParserDelegate {
    
    public func parserDidStartDocument(_ parser: XMLParser) {
        // 开始解析
    }
    
    public func parserDidEndDocument(_ parser: XMLParser) {
        // 解析完成
    }
    
    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        // 处理之前的文本内容
        flushTextContent()
        
        // 创建新节点
        let node = XMLNode(name: elementName, attributes: attributeDict)
        node.sourceLocation = SourceLocation(
            line: parser.lineNumber,
            column: parser.columnNumber
        )
        
        // 如果有父节点，添加为子节点
        if let parent = nodeStack.last {
            parent.children.append(node)
            node.parent = parent
        }
        
        // 入栈
        nodeStack.append(node)
        
        // 第一个元素作为根节点
        if rootNode == nil {
            rootNode = node
        }
    }
    
    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // 处理文本内容
        flushTextContent()
        
        // 出栈
        _ = nodeStack.popLast()
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentTextContent += string
    }
    
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            currentTextContent += string
        }
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = XMLParseError.parsingFailed(parseError.localizedDescription)
    }
    
    public func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        self.parseError = XMLParseError.validationFailed(validationError.localizedDescription)
    }
    
    // MARK: - Private
    
    private func flushTextContent() {
        let trimmed = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmed.isEmpty, let current = nodeStack.last {
            current.textContent = trimmed
        }
        
        currentTextContent = ""
    }
}

// MARK: - 解析错误

/// XML 解析错误
public enum XMLParseError: Error, LocalizedError {
    case invalidEncoding
    case emptyDocument
    case parsingFailed(String)
    case validationFailed(String)
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Invalid XML encoding"
        case .emptyDocument:
            return "Empty XML document"
        case .parsingFailed(let message):
            return "XML parsing failed: \(message)"
        case .validationFailed(let message):
            return "XML validation failed: \(message)"
        case .unknownError:
            return "Unknown XML parsing error"
        }
    }
}
