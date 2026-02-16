import Foundation
import os.lock

// MARK: - 预渲染优化器

/// 预渲染优化器 - 提前计算布局和构建组件树
/// 注意：主线程渲染优先，此模块用于提前准备数据，最终渲染仍在主线程
public final class PreRenderOptimizer {
    
    public static let shared = PreRenderOptimizer()
    
    // MARK: - 配置
    
    /// 是否启用预渲染
    public var isEnabled: Bool = true
    
    /// 预渲染队列
    private let preRenderQueue = DispatchQueue(
        label: "com.templatex.prerender",
        qos: .userInitiated
    )
    
    /// 预渲染缓存
    private var preRenderCache: [String: PreRenderResult] = [:]
    private var cacheLock = os_unfair_lock()
    
    /// 缓存最大数量
    public var maxCacheSize: Int = 50
    
    private init() {}
    
    // MARK: - 预渲染 API
    
    /// 预渲染模板（异步）
    /// - Parameters:
    ///   - templateId: 模板 ID
    ///   - json: 模板 JSON
    ///   - data: 绑定数据
    ///   - size: 容器尺寸
    ///   - completion: 完成回调（主线程）
    public func preRender(
        templateId: String,
        json: JSONWrapper,
        data: [String: Any],
        size: CGSize,
        completion: ((PreRenderResult) -> Void)? = nil
    ) {
        guard isEnabled else {
            completion?(PreRenderResult(templateId: templateId, status: .disabled))
            return
        }
        
        let cacheKey = generateCacheKey(templateId: templateId, data: data, size: size)
        
        // 检查缓存
        os_unfair_lock_lock(&cacheLock)
        if let cached = preRenderCache[cacheKey], !cached.isExpired {
            os_unfair_lock_unlock(&cacheLock)
            DispatchQueue.main.async {
                completion?(cached)
            }
            return
        }
        os_unfair_lock_unlock(&cacheLock)
        
        // 异步预渲染
        preRenderQueue.async { [weak self] in
            guard let self = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 1. 构建组件树（不创建 UIView）
            let componentTree = self.buildComponentTree(from: json, data: data)
            
            // 2. 预计算布局（使用 Yoga）
            let layoutInfo = self.preCalculateLayout(componentTree: componentTree, size: size)
            
            // 3. 预处理表达式（缓存求值结果）
            let expressionCache = self.preEvaluateExpressions(json: json, data: data)
            
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            
            let result = PreRenderResult(
                templateId: templateId,
                status: .success,
                componentTree: componentTree,
                layoutInfo: layoutInfo,
                expressionCache: expressionCache,
                preRenderDuration: duration
            )
            
            // 缓存结果
            os_unfair_lock_lock(&self.cacheLock)
            self.preRenderCache[cacheKey] = result
            self.trimCacheIfNeeded()
            os_unfair_lock_unlock(&self.cacheLock)
            
            // 主线程回调
            DispatchQueue.main.async {
                completion?(result)
            }
        }
    }
    
    /// 获取预渲染结果（同步）
    public func getCachedResult(
        templateId: String,
        data: [String: Any],
        size: CGSize
    ) -> PreRenderResult? {
        let cacheKey = generateCacheKey(templateId: templateId, data: data, size: size)
        
        os_unfair_lock_lock(&cacheLock)
        defer { os_unfair_lock_unlock(&cacheLock) }
        
        if let cached = preRenderCache[cacheKey], !cached.isExpired {
            return cached
        }
        return nil
    }
    
    /// 清除缓存
    public func clearCache() {
        os_unfair_lock_lock(&cacheLock)
        preRenderCache.removeAll()
        os_unfair_lock_unlock(&cacheLock)
    }
    
    /// 移除指定模板的缓存
    public func invalidateCache(for templateId: String) {
        os_unfair_lock_lock(&cacheLock)
        preRenderCache = preRenderCache.filter { !$0.key.hasPrefix(templateId) }
        os_unfair_lock_unlock(&cacheLock)
    }
    
    // MARK: - Private
    
    private func generateCacheKey(templateId: String, data: [String: Any], size: CGSize) -> String {
        // 简单的缓存键生成，实际可以用 hash
        let dataHash = data.description.hashValue
        return "\(templateId)_\(Int(size.width))x\(Int(size.height))_\(dataHash)"
    }
    
    private func buildComponentTree(from json: JSONWrapper, data: [String: Any]) -> Component? {
        guard let type = json.type else { return nil }
        
        // 使用组件池获取组件
        guard let component = ComponentPool.shared.obtainComponent(type: type, from: json) else {
            return nil
        }
        
        // 递归构建子组件
        for childJson in json.children {
            if let childComponent = buildComponentTree(from: childJson, data: data) {
                component.addChild(childComponent)
            }
        }
        
        return component
    }
    
    private func preCalculateLayout(componentTree: Component?, size: CGSize) -> LayoutInfo {
        guard let root = componentTree else {
            return LayoutInfo(frames: [:])
        }
        
        var frames: [String: CGRect] = [:]
        
        // TODO: 集成 Yoga 布局计算
        // 这里简化处理，实际需要调用 YogaLayoutEngine
        calculateFrames(component: root, in: CGRect(origin: .zero, size: size), frames: &frames)
        
        return LayoutInfo(frames: frames)
    }
    
    private func calculateFrames(component: Component, in bounds: CGRect, frames: inout [String: CGRect]) {
        // 简化的布局计算（实际应使用 Yoga）
        frames[component.id] = bounds
        
        // 子组件布局（简化为垂直排列）
        var yOffset: CGFloat = 0
        for child in component.children {
            let childHeight: CGFloat = 44  // 默认高度
            let childFrame = CGRect(x: 0, y: yOffset, width: bounds.width, height: childHeight)
            calculateFrames(component: child, in: childFrame, frames: &frames)
            yOffset += childHeight
        }
    }
    
    private func preEvaluateExpressions(json: JSONWrapper, data: [String: Any]) -> [String: Any] {
        var cache: [String: Any] = [:]
        
        // 遍历 bindings，预计算表达式
        if let bindings = json.bindings?.rawDictionary {
            for (key, value) in bindings {
                if let expression = value as? String, expression.hasPrefix("${") {
                    // 提取表达式并求值
                    let expr = String(expression.dropFirst(2).dropLast())
                    let result = ExpressionEngine.shared.evaluate(expr, context: data)
                    if let value = result.value() {
                        cache[key] = value
                    }
                }
            }
        }
        
        return cache
    }
    
    private func trimCacheIfNeeded() {
        // 已持有锁
        while preRenderCache.count > maxCacheSize {
            // 移除最旧的（简化处理，实际可以用 LRU）
            if let oldestKey = preRenderCache.keys.first {
                preRenderCache.removeValue(forKey: oldestKey)
            }
        }
    }
}

// MARK: - PreRenderResult

/// 预渲染结果
public struct PreRenderResult {
    
    public enum Status {
        case success
        case disabled
        case failed(Error)
    }
    
    public let templateId: String
    public let status: Status
    
    /// 预构建的组件树
    public let componentTree: Component?
    
    /// 预计算的布局信息
    public let layoutInfo: LayoutInfo?
    
    /// 预求值的表达式缓存
    public let expressionCache: [String: Any]
    
    /// 预渲染耗时（毫秒）
    public let preRenderDuration: Double
    
    /// 创建时间
    public let createdAt: Date
    
    /// 过期时间（秒）
    public var expirationInterval: TimeInterval = 60
    
    /// 是否过期
    public var isExpired: Bool {
        return Date().timeIntervalSince(createdAt) > expirationInterval
    }
    
    init(
        templateId: String,
        status: Status,
        componentTree: Component? = nil,
        layoutInfo: LayoutInfo? = nil,
        expressionCache: [String: Any] = [:],
        preRenderDuration: Double = 0
    ) {
        self.templateId = templateId
        self.status = status
        self.componentTree = componentTree
        self.layoutInfo = layoutInfo
        self.expressionCache = expressionCache
        self.preRenderDuration = preRenderDuration
        self.createdAt = Date()
    }
}

// MARK: - LayoutInfo

/// 布局信息
public struct LayoutInfo {
    /// 组件 ID -> Frame 映射
    public let frames: [String: CGRect]
    
    /// 获取组件的 frame
    public func frame(for componentId: String) -> CGRect? {
        return frames[componentId]
    }
}

// MARK: - 批量预渲染

extension PreRenderOptimizer {
    
    /// 批量预渲染多个模板
    public func preRenderBatch(
        templates: [(id: String, json: JSONWrapper, data: [String: Any], size: CGSize)],
        completion: (([PreRenderResult]) -> Void)? = nil
    ) {
        guard isEnabled else {
            let results = templates.map { PreRenderResult(templateId: $0.id, status: .disabled) }
            completion?(results)
            return
        }
        
        let group = DispatchGroup()
        var results: [PreRenderResult] = []
        var resultsLock = os_unfair_lock()
        
        for template in templates {
            group.enter()
            preRender(
                templateId: template.id,
                json: template.json,
                data: template.data,
                size: template.size
            ) { result in
                os_unfair_lock_lock(&resultsLock)
                results.append(result)
                os_unfair_lock_unlock(&resultsLock)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion?(results)
        }
    }
}
