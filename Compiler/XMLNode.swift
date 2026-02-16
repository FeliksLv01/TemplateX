import Foundation

// MARK: - XML 节点中间表示

/// XML 节点 - 解析后的中间表示
public final class XMLNode {
    
    /// 节点名称（标签名）
    public let name: String
    
    /// 属性字典
    public var attributes: [String: String]
    
    /// 子节点
    public var children: [XMLNode]
    
    /// 文本内容（如果有）
    public var textContent: String?
    
    /// 父节点
    public weak var parent: XMLNode?
    
    /// 源码位置（用于错误提示）
    public var sourceLocation: SourceLocation?
    
    public init(
        name: String,
        attributes: [String: String] = [:],
        children: [XMLNode] = [],
        textContent: String? = nil
    ) {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.textContent = textContent
    }
    
    // MARK: - 便捷访问
    
    /// 获取属性值
    public func attribute(_ key: String) -> String? {
        attributes[key]
    }
    
    /// 获取属性值（带默认值）
    public func attribute(_ key: String, default: String) -> String {
        attributes[key] ?? `default`
    }
    
    /// 获取指定名称的子节点
    public func child(named name: String) -> XMLNode? {
        children.first { $0.name == name }
    }
    
    /// 获取所有指定名称的子节点
    public func children(named name: String) -> [XMLNode] {
        children.filter { $0.name == name }
    }
    
    /// 是否有子节点
    public var hasChildren: Bool {
        !children.isEmpty
    }
    
    /// 是否是叶子节点
    public var isLeaf: Bool {
        children.isEmpty
    }
}

// MARK: - 源码位置

/// 源码位置信息
public struct SourceLocation {
    public let line: Int
    public let column: Int
    public let filePath: String?
    
    public init(line: Int, column: Int, filePath: String? = nil) {
        self.line = line
        self.column = column
        self.filePath = filePath
    }
    
    public var description: String {
        if let path = filePath {
            return "\(path):\(line):\(column)"
        }
        return "line \(line), column \(column)"
    }
}

// MARK: - 调试输出

extension XMLNode: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var result = "<\(name)"
        
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            result += " \(key)=\"\(value)\""
        }
        
        if children.isEmpty && textContent == nil {
            result += "/>"
        } else {
            result += ">"
            
            if let text = textContent {
                result += text
            }
            
            for child in children {
                result += "\n  " + child.debugDescription.replacingOccurrences(of: "\n", with: "\n  ")
            }
            
            if !children.isEmpty {
                result += "\n"
            }
            
            result += "</\(name)>"
        }
        
        return result
    }
}

// MARK: - 模板元信息

/// 模板元信息（从 <Template> 标签解析）
public struct TemplateMetaInfo {
    public let name: String
    public let version: String
    public let description: String?
    
    public init(name: String, version: String = "1.0", description: String? = nil) {
        self.name = name
        self.version = version
        self.description = description
    }
}
