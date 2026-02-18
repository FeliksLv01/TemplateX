import Foundation
import os.lock

// MARK: - 模板解析器

/// 模板解析器 - 将 JSON 转换为组件树
public final class TemplateParser {
    
    public static let shared = TemplateParser()
    
    private init() {}
    
    // MARK: - 解析入口
    
    /// 从 JSON 数据解析模板
    public func parse(data: Data) -> Component? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            TXLogger.error("Failed to parse JSON data")
            return nil
        }
        return parse(json: json)
    }
    
    /// 从 JSON 字典解析模板
    public func parse(json: [String: Any]) -> Component? {
        let start = CACurrentMediaTime()
        
        // 细分：创建 JSONWrapper
        let wrapper = JSONWrapper(json)
        
        // 细分：解析节点树
        let result = parse(wrapper: wrapper)
        
        return result
    }
    
    /// 从 JSONWrapper 解析模板
    public func parse(wrapper: JSONWrapper) -> Component? {
        // 检查是否有 root 节点
        if let root = wrapper.child("root") {
            return parseNode(root)
        }
        
        // 直接作为根节点
        return parseNode(wrapper)
    }
    
    // MARK: - 节点解析
    
    /// 递归解析节点
    private func parseNode(_ json: JSONWrapper) -> Component? {
        // 获取组件类型
        guard let type = json.type else {
            TXLogger.warning("Node missing 'type' field")
            return nil
        }
        
        // 创建组件
        guard let component = ComponentRegistry.shared.createComponent(type: type, from: json) else {
            TXLogger.error("Failed to create component of type: \(type)")
            return nil
        }
        
        // 递归解析子节点
        for childJson in json.children {
            if let child = parseNode(childJson) {
                component.children.append(child)
                child.parent = component
            }
        }
        
        return component
    }
}

// MARK: - 模板加载器

/// 模板加载器 - 从文件/网络加载模板
public final class TemplateLoader {
    
    public static let shared = TemplateLoader()
    
    private init() {}
    
    // MARK: - 加载方法
    
    /// 从 Bundle 加载模板
    public func loadFromBundle(name: String, bundle: Bundle = .main) -> Component? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            TXLogger.error("Template not found in bundle: \(name)")
            return nil
        }
        return loadFromFile(url: url)
    }
    
    /// 从 Bundle 加载模板 JSON 字典
    public func loadJSONFromBundle(name: String, bundle: Bundle = .main) -> [String: Any]? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            TXLogger.error("Template not found in bundle: \(name)")
            return nil
        }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            TXLogger.error("Failed to parse JSON: \(name)")
            return nil
        }
        return json
    }
    
    /// 从文件路径加载模板
    public func loadFromFile(path: String) -> Component? {
        let url = URL(fileURLWithPath: path)
        return loadFromFile(url: url)
    }
    
    /// 从文件 URL 加载模板
    public func loadFromFile(url: URL) -> Component? {
        guard let data = try? Data(contentsOf: url) else {
            TXLogger.error("Failed to read file: \(url)")
            return nil
        }
        return TemplateParser.shared.parse(data: data)
    }
    
    /// 从 JSON 字符串加载模板
    public func loadFromString(_ jsonString: String) -> Component? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return TemplateParser.shared.parse(data: data)
    }
    
    /// 从字典加载模板
    public func loadFromDictionary(_ json: [String: Any]) -> Component? {
        return TemplateParser.shared.parse(json: json)
    }
}

// MARK: - 模板缓存

/// 模板缓存 - LRU 策略
public final class TemplateCache {
    
    public static let shared = TemplateCache()
    
    /// LRU 缓存
    private var cache: [String: CacheEntry] = [:]
    private var accessOrder: [String] = []
    private let capacity: Int
    private var unfairLock = os_unfair_lock()
    
    private struct CacheEntry {
        let component: Component
        let timestamp: Date
    }
    
    public init(capacity: Int = 50) {
        self.capacity = capacity
    }
    
    // MARK: - 缓存操作
    
    /// 获取缓存的模板
    public func get(_ key: String) -> Component? {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        guard let entry = cache[key] else { return nil }
        
        // 更新访问顺序
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }
        
        return entry.component
    }
    
    /// 存入缓存
    public func set(_ key: String, component: Component) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        // 如果已存在，更新
        if cache[key] != nil {
            cache[key] = CacheEntry(component: component, timestamp: Date())
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
                accessOrder.append(key)
            }
            return
        }
        
        // 容量检查
        while cache.count >= capacity && !accessOrder.isEmpty {
            let oldest = accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        
        // 插入新条目
        cache[key] = CacheEntry(component: component, timestamp: Date())
        accessOrder.append(key)
    }
    
    /// 移除缓存
    public func remove(_ key: String) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        cache.removeValue(forKey: key)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }
    
    /// 清空缓存
    public func clear() {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    /// 当前缓存数量
    public var count: Int {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return cache.count
    }
    
    /// 裁剪缓存到指定数量
    ///
    /// 按 LRU 顺序移除最旧的条目，直到缓存数量 <= count
    /// - Parameter count: 目标缓存数量
    public func trimToCount(_ count: Int) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        while cache.count > count && !accessOrder.isEmpty {
            let oldest = accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }
}
