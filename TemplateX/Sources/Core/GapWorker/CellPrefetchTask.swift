import Foundation
import CoreGraphics

// MARK: - CellPrefetchTask

/// Cell 预渲染任务
/// 在闲时执行 parse + bind + layout，将结果存入 prefetch cache
/// 对应 Lynx: clay/ui/component/list/base_list_view.h:354 ListPrefetchTask
final class CellPrefetchTask: GapTask {
    
    // MARK: - GapTask 协议
    
    /// 任务 ID（Cell position）
    let taskId: Int
    
    /// 估算执行耗时（纳秒）
    let estimateDuration: Int64
    
    /// 优先级（距离视口越近，值越小，优先级越高）
    let priority: Int
    
    /// 是否强制执行（即使时间预算不足）
    let enableForceRun: Bool
    
    // MARK: - Cell 相关
    
    /// 宿主 ListComponent（弱引用）
    private weak var hostView: AnyObject?
    
    /// 模板 ID
    let templateId: String
    
    /// 模板 JSON
    let templateJson: [String: Any]
    
    /// Cell 数据
    let cellData: [String: Any]
    
    /// 容器尺寸
    let containerSize: CGSize
    
    // MARK: - Init
    
    /// 创建 Cell 预渲染任务
    /// - Parameters:
    ///   - position: Cell 位置（index）
    ///   - templateId: 模板 ID
    ///   - templateJson: 模板 JSON
    ///   - cellData: Cell 数据
    ///   - containerSize: 容器尺寸
    ///   - estimateDuration: 估算耗时（纳秒）
    ///   - priority: 优先级（距离）
    ///   - enableForceRun: 是否强制执行
    ///   - hostView: 宿主视图（弱引用）
    init(
        position: Int,
        templateId: String,
        templateJson: [String: Any],
        cellData: [String: Any],
        containerSize: CGSize,
        estimateDuration: Int64,
        priority: Int,
        enableForceRun: Bool = true,
        hostView: AnyObject? = nil
    ) {
        self.taskId = position
        self.templateId = templateId
        self.templateJson = templateJson
        self.cellData = cellData
        self.containerSize = containerSize
        self.estimateDuration = estimateDuration
        self.priority = priority
        self.enableForceRun = enableForceRun
        self.hostView = hostView
    }
    
    // MARK: - 执行任务
    
    /// 执行预渲染任务
    /// 对应 Lynx: base_list_view.cc:75 ListPrefetchTask::Run()
    func run() {
        // 1. 检查宿主是否还存在
        guard hostView != nil else {
            TXLogger.trace("CellPrefetchTask[\(taskId)]: host released, skip")
            return
        }
        
        // 2. 检查是否已缓存
        let cacheKey = PrefetchCache.cacheKey(templateId: templateId, position: taskId)
        if PrefetchCache.shared.hasCached(cacheKey: cacheKey) {
            TXLogger.trace("CellPrefetchTask[\(taskId)]: already cached, skip")
            return
        }
        
        let startTime = CACurrentMediaTime()
        
        // 3. Parse 模板
        guard let component = TemplateParser.shared.parse(json: templateJson) else {
            TXLogger.warning("CellPrefetchTask[\(taskId)]: parse failed")
            return
        }
        
        // 4. Bind 数据
        DataBindingManager.shared.bind(data: cellData, to: component)
        
        // 5. Layout 计算
        _ = YogaLayoutEngine.shared.calculateLayout(
            for: component,
            containerSize: containerSize
        )
        
        // 6. 标记 prefetch 并缓存
        if let baseComponent = component as? BaseComponent {
            baseComponent.componentFlags.insert(.prefetch)
        }
        
        let item = PrefetchedItem(
            component: component,
            position: taskId,
            templateId: templateId
        )
        PrefetchCache.shared.cache(item, forKey: cacheKey)
        
        let duration = (CACurrentMediaTime() - startTime) * 1000
        TXLogger.trace("CellPrefetchTask[\(taskId)]: completed in \(String(format: "%.2f", duration))ms")
        
        // 7. 更新平均绑定时间
        PerformanceMonitor.shared.updateAverageBindTime(
            templateId: templateId,
            newValue: Int64(duration * 1_000_000)  // 转为纳秒
        )
    }
}

// MARK: - PrefetchedItem

/// 预加载的组件项
struct PrefetchedItem {
    /// 预加载的组件
    let component: Component
    
    /// Cell 位置
    let position: Int
    
    /// 模板 ID
    let templateId: String
    
    /// 创建时间
    let createTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
}

// MARK: - PrefetchCache

/// 预加载缓存
/// 对应 Lynx: list_recycler.h 中的 cached_items_（第二级缓存）
final class PrefetchCache {
    
    static let shared = PrefetchCache()
    
    // MARK: - 配置
    
    /// 每种模板的最大缓存数量
    /// 对应 Lynx: max_limit_
    var maxLimitPerTemplate: Int = 30
    
    // MARK: - 存储
    
    /// 缓存 [cacheKey -> item]
    private var cache: [String: PrefetchedItem] = [:]
    
    /// 按模板分组的 key 列表（用于 LRU 淘汰）
    private var templateKeys: [String: [String]] = [:]
    
    private init() {}
    
    // MARK: - API
    
    /// 生成缓存 key
    static func cacheKey(templateId: String, position: Int) -> String {
        return "\(templateId)_\(position)"
    }
    
    /// 是否已缓存
    func hasCached(cacheKey: String) -> Bool {
        return cache[cacheKey] != nil
    }
    
    /// 获取缓存的组件
    func get(cacheKey: String) -> PrefetchedItem? {
        return cache.removeValue(forKey: cacheKey)
    }
    
    /// 缓存组件
    func cache(_ item: PrefetchedItem, forKey key: String) {
        let templateId = item.templateId
        
        // 检查容量，执行 LRU 淘汰
        var keys = templateKeys[templateId] ?? []
        if keys.count >= maxLimitPerTemplate {
            // 移除最旧的
            if let oldestKey = keys.first {
                cache.removeValue(forKey: oldestKey)
                keys.removeFirst()
            }
        }
        
        // 添加新的
        cache[key] = item
        keys.append(key)
        templateKeys[templateId] = keys
    }
    
    /// 清空指定模板的缓存
    func clear(templateId: String? = nil) {
        if let templateId = templateId {
            if let keys = templateKeys[templateId] {
                for key in keys {
                    cache.removeValue(forKey: key)
                }
                templateKeys.removeValue(forKey: templateId)
            }
        } else {
            cache.removeAll()
            templateKeys.removeAll()
        }
    }
    
    /// 缓存数量
    var count: Int {
        return cache.count
    }
}
