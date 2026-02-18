import UIKit

// MARK: - 渲染管道

/// 渲染管道
/// 
/// 借鉴 Lynx 的架构设计：
/// - 后台线程执行 parse + bind + layout
/// - UI 操作入队批处理
/// - SyncFlush 机制避免白屏
/// 
/// 使用示例：
/// ```swift
/// let pipeline = RenderPipeline()
/// 
/// // 1. 启动渲染（后台执行 parse/bind/layout）
/// pipeline.start(json: template, data: data, containerSize: size)
/// 
/// // 2. 在 layoutSubviews 时同步刷新
/// pipeline.syncFlush()
/// 
/// // 3. 获取渲染结果
/// if let view = pipeline.renderedView {
///     addSubview(view)
/// }
/// ```
final class RenderPipeline {
    
    // MARK: - 配置
    
    /// 管道配置
    public struct Config {
        /// SyncFlush 超时时间（毫秒）
        public var syncFlushTimeoutMs: Int = 100
        
        /// 是否启用视图复用
        public var enableViewReuse: Bool = true
        
        /// 是否启用性能监控
        public var enablePerformanceMonitor: Bool = false
        
        public init() {}
    }
    
    /// 配置
    public var config = Config() {
        didSet {
            operationQueue.timeoutMs = config.syncFlushTimeoutMs
        }
    }
    
    // MARK: - 状态
    
    /// 管道状态
    public enum State {
        case idle           // 空闲
        case preparing      // 后台准备中
        case ready          // 准备完成，等待 flush
        case flushing       // 正在执行 UI 操作
        case completed      // 渲染完成
        case error(Error)   // 错误
    }
    
    /// 当前状态
    public private(set) var state: State = .idle
    
    /// 渲染结果
    public private(set) var renderedView: UIView?
    
    /// 渲染的组件树
    public private(set) var rootComponent: Component?
    
    /// 布局结果
    public private(set) var layoutResults: [String: LayoutResult]?
    
    // MARK: - 内部组件
    
    /// UI 操作队列
    private let operationQueue = UIOperationQueue()
    
    /// 渲染引擎依赖
    private let templateParser = TemplateParser.shared
    private let dataBindingManager = DataBindingManager.shared
    private let layoutEngine = YogaLayoutEngine.shared
    private let viewRecyclePool = ViewRecyclePool.shared
    
    /// 后台队列
    private let backgroundQueue: DispatchQueue
    
    /// 实例 ID
    public let instanceId: String
    
    /// 取消标记
    private var isCancelled = false
    private let cancelLock = NSLock()
    
    // MARK: - 统计
    
    /// 各阶段耗时（毫秒）
    public struct Timing {
        public var parseMs: Double = 0
        public var bindMs: Double = 0
        public var layoutMs: Double = 0
        public var waitMs: Double = 0
        public var flushMs: Double = 0
        public var totalMs: Double = 0
        
        public var description: String {
            return "parse=\(String(format: "%.2f", parseMs))ms | bind=\(String(format: "%.2f", bindMs))ms | layout=\(String(format: "%.2f", layoutMs))ms | wait=\(String(format: "%.2f", waitMs))ms | flush=\(String(format: "%.2f", flushMs))ms | total=\(String(format: "%.2f", totalMs))ms"
        }
    }
    
    /// 上次渲染耗时
    public private(set) var lastTiming = Timing()
    
    // MARK: - 回调
    
    /// 渲染完成回调
    public var onComplete: ((UIView) -> Void)?
    
    /// 错误回调
    public var onError: ((Error) -> Void)?
    
    // MARK: - Init
    
    public init(instanceId: String = UUID().uuidString) {
        self.instanceId = instanceId
        self.backgroundQueue = DispatchQueue(
            label: "com.templatex.pipeline.\(instanceId)",
            qos: .userInitiated
        )
        operationQueue.timeoutMs = config.syncFlushTimeoutMs
    }
    
    // MARK: - 启动渲染
    
    /// 启动渲染管道
    /// 
    /// 在后台线程执行：
    /// 1. 解析模板
    /// 2. 绑定数据
    /// 3. 计算布局
    /// 4. 生成 UI 操作入队
    /// 
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    public func start(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) {
        // 重置状态
        reset()
        
        state = .preparing
        operationQueue.markPreparing()
        
        let totalStart = CACurrentMediaTime()
        
        // 后台执行
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 1. 解析模板
            let parseStart = CACurrentMediaTime()
            guard let component = self.templateParser.parse(json: json) else {
                self.handleError(RenderPipelineError.parseFailed)
                return
            }
            self.lastTiming.parseMs = (CACurrentMediaTime() - parseStart) * 1000
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 2. 绑定数据
            let bindStart = CACurrentMediaTime()
            if let data = data {
                self.dataBindingManager.bind(data: data, to: component)
            }
            self.lastTiming.bindMs = (CACurrentMediaTime() - bindStart) * 1000
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 3. 计算布局
            let layoutStart = CACurrentMediaTime()
            let layoutResults = self.layoutEngine.calculateLayout(
                for: component,
                containerSize: containerSize
            )
            self.lastTiming.layoutMs = (CACurrentMediaTime() - layoutStart) * 1000
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 4. 应用布局结果
            self.applyLayoutResults(layoutResults, to: component)
            
            // 保存结果
            self.rootComponent = component
            self.layoutResults = layoutResults
            
            // 5. 预处理 ListComponent（预编译 Cell 模板、预计算高度）
            self.preloadListComponents(component, containerSize: containerSize)
            
            // 6. 生成 UI 操作入队
            self.generateUIOperations(for: component, isRoot: true)
            
            // 记录总后台时间
            let backendTime = (CACurrentMediaTime() - totalStart) * 1000
            
            // 标记准备完成
            self.operationQueue.markReady()
            self.state = .ready
            
            TXLogger.trace("RenderPipeline[\(self.instanceId)]: backend completed in \(String(format: "%.2f", backendTime))ms | \(self.lastTiming.description)")
        }
    }
    
    /// 使用缓存的组件原型启动渲染（Cell 场景优化）
    /// 
    /// - Parameters:
    ///   - prototype: 组件原型（通过 clone 复用）
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    public func startWithPrototype(
        prototype: Component,
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) {
        // 重置状态
        reset()
        
        state = .preparing
        operationQueue.markPreparing()
        
        let totalStart = CACurrentMediaTime()
        
        // 后台执行
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 1. 克隆组件树
            let parseStart = CACurrentMediaTime()
            let component = self.cloneComponentTree(prototype)
            self.lastTiming.parseMs = (CACurrentMediaTime() - parseStart) * 1000
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 2. 绑定数据
            let bindStart = CACurrentMediaTime()
            if let data = data {
                self.dataBindingManager.bind(data: data, to: component)
            }
            self.lastTiming.bindMs = (CACurrentMediaTime() - bindStart) * 1000
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 3. 计算布局
            let layoutStart = CACurrentMediaTime()
            let layoutResults = self.layoutEngine.calculateLayout(
                for: component,
                containerSize: containerSize
            )
            self.lastTiming.layoutMs = (CACurrentMediaTime() - layoutStart) * 1000
            
            // 检查取消
            if self.checkCancelled() { return }
            
            // 4. 应用布局结果
            self.applyLayoutResults(layoutResults, to: component)
            
            // 保存结果
            self.rootComponent = component
            self.layoutResults = layoutResults
            
            // 5. 生成 UI 操作入队
            self.generateUIOperations(for: component, isRoot: true)
            
            // 标记准备完成
            self.operationQueue.markReady()
            self.state = .ready
        }
    }
    
    // MARK: - SyncFlush
    
    /// 同步刷新（主线程调用）
    /// 
    /// 等待后台准备完成，然后批量执行所有 UI 操作
    /// 
    /// - Returns: 渲染的视图（如果成功）
    @discardableResult
    public func syncFlush() -> UIView? {
        guard Thread.isMainThread else {
            TXLogger.error("syncFlush must be called on main thread")
            return nil
        }
        
        let totalStart = CACurrentMediaTime()
        let waitStart = CACurrentMediaTime()
        
        // 等待后台完成并执行 UI 操作
        state = .flushing
        let success = operationQueue.syncFlush()
        
        lastTiming.waitMs = operationQueue.lastWaitTimeMs
        lastTiming.flushMs = operationQueue.lastExecuteTimeMs
        lastTiming.totalMs = (CACurrentMediaTime() - totalStart) * 1000 + lastTiming.parseMs + lastTiming.bindMs + lastTiming.layoutMs
        
        if success {
            state = .completed
            
            if config.enablePerformanceMonitor {
                TXLogger.info("RenderPipeline[\(instanceId)]: \(lastTiming.description)")
            }
            
            // 触发回调
            if let view = renderedView {
                onComplete?(view)
            }
            
            return renderedView
        } else {
            return nil
        }
    }
    
    /// 强制刷新（不等待，直接执行当前队列中的操作）
    @discardableResult
    public func forceFlush() -> UIView? {
        guard Thread.isMainThread else {
            TXLogger.error("forceFlush must be called on main thread")
            return nil
        }
        
        state = .flushing
        operationQueue.forceFlush()
        state = .completed
        
        return renderedView
    }
    
    // MARK: - 取消
    
    /// 取消渲染
    public func cancel() {
        cancelLock.lock()
        isCancelled = true
        cancelLock.unlock()
        
        operationQueue.reset()
        state = .idle
    }
    
    private func checkCancelled() -> Bool {
        cancelLock.lock()
        let cancelled = isCancelled
        cancelLock.unlock()
        
        if cancelled {
            state = .idle
        }
        return cancelled
    }
    
    // MARK: - 重置
    
    /// 重置管道状态
    public func reset() {
        cancelLock.lock()
        isCancelled = false
        cancelLock.unlock()
        
        operationQueue.reset()
        renderedView = nil
        rootComponent = nil
        layoutResults = nil
        state = .idle
        lastTiming = Timing()
    }
    
    // MARK: - 生成 UI 操作
    
    /// 生成 UI 操作并入队
    private func generateUIOperations(for component: Component, isRoot: Bool) {
        // 创建视图操作
        operationQueue.enqueue { [weak self] in
            guard let self = self else { return }
            
            // 创建或复用视图
            let view: UIView
            if let existingView = component.view {
                view = existingView
            } else if self.config.enableViewReuse,
                      let recycledView = self.viewRecyclePool.dequeueView(forType: component.type) {
                view = recycledView
                component.view = view
                // 复用视图时强制应用样式
                if let baseComponent = component as? BaseComponent {
                    baseComponent.forceApplyStyle = true
                }
            } else {
                view = component.createView()
            }
            
            // 设置属性
            view.componentType = component.type
            view.accessibilityIdentifier = component.id
            
            // 设置 frame
            view.frame = component.layoutResult.frame
            
            // 如果是根组件，保存引用
            if isRoot {
                self.renderedView = view
            }
        }
        
        // 递归处理子组件（先创建子视图）
        for child in component.children {
            generateUIOperations(for: child, isRoot: false)
        }
        
        // 添加子视图操作（在子视图创建后）
        for child in component.children {
            operationQueue.enqueue {
                guard let parentView = component.view, let childView = child.view else { return }
                if childView.superview !== parentView {
                    parentView.addSubview(childView)
                }
            }
        }
        
        // 更新视图属性操作
        operationQueue.enqueue {
            component.updateView()
        }
    }
    
    // MARK: - 布局应用
    
    /// 应用布局结果
    private func applyLayoutResults(
        _ results: [String: LayoutResult],
        to component: Component
    ) {
        if let result = results[component.id] {
            component.layoutResult = result
        }
        
        // 递归处理子组件
        for child in component.children {
            applyLayoutResults(results, to: child)
        }
    }
    
    // MARK: - 组件克隆
    
    private func cloneComponentTree(_ component: Component) -> Component {
        let cloned = component.clone()
        
        for child in component.children {
            let clonedChild = cloneComponentTree(child)
            clonedChild.parent = cloned
            cloned.children.append(clonedChild)
        }
        
        return cloned
    }
    
    // MARK: - ListComponent 预处理
    
    /// 预处理 ListComponent
    ///
    /// 在后台阶段预先处理 ListComponent：
    /// 1. 预编译 Cell 模板
    /// 2. 预计算所有数据项的高度
    /// 3. 预加载首屏可见的 Cell
    ///
    /// - Parameters:
    ///   - component: 组件树根节点
    ///   - containerSize: 容器尺寸
    private func preloadListComponents(_ component: Component, containerSize: CGSize) {
        // 如果是 ListComponent，启用预加载
        if let listComponent = component as? ListComponent,
           let cellTemplate = listComponent.cellTemplate {
            
            let start = CACurrentMediaTime()
            
            // 获取容器宽度
            let containerWidth = listComponent.layoutResult.frame.width > 0
                ? listComponent.layoutResult.frame.width
                : containerSize.width
            
            // 创建预加载管理器
            let templateId = listComponent.cellTemplateId ?? "list_cell_\(listComponent.id)"
            let manager = ListPreloadManager(
                cellTemplate: cellTemplate,
                templateId: templateId,
                containerWidth: containerWidth
            )
            
            // 同步预编译模板（在后台线程，所以不会阻塞主线程）
            manager.precompileTemplateSync()
            
            // 如果有数据源，预计算高度
            if !listComponent.dataSource.isEmpty {
                // 同步计算高度（后台线程）
                for (index, itemData) in listComponent.dataSource.enumerated() {
                    guard let prototype = manager.componentPrototype else { break }
                    
                    let clonedComponent = cloneComponentTree(prototype)
                    
                    var context: [String: Any] = [
                        "item": itemData,
                        "index": index
                    ]
                    if let dictData = itemData as? [String: Any] {
                        context.merge(dictData) { _, new in new }
                    }
                    
                    dataBindingManager.bind(data: context, to: clonedComponent)
                    
                    let cellSize = CGSize(width: containerWidth, height: CGFloat.nan)
                    let cellLayoutResults = layoutEngine.calculateLayout(
                        for: clonedComponent,
                        containerSize: cellSize
                    )
                    
                    if let height = cellLayoutResults[clonedComponent.id]?.frame.height, height > 0 {
                        manager.heightCache[index] = height
                    }
                }
            }
            
            // 保存到组件
            listComponent.preloadManager = manager
            
            let elapsed = (CACurrentMediaTime() - start) * 1000
            TXLogger.trace("RenderPipeline: preloadListComponent \(listComponent.id) completed in \(String(format: "%.2f", elapsed))ms | heights=\(manager.heightCache.count)")
        }
        
        // 递归处理子组件
        for child in component.children {
            preloadListComponents(child, containerSize: containerSize)
        }
    }
    
    // MARK: - 错误处理
    
    private func handleError(_ error: Error) {
        state = .error(error)
        operationQueue.markError(error)
        
        DispatchQueue.main.async { [weak self] in
            self?.onError?(error)
        }
    }
}

// MARK: - 错误类型

/// 渲染管道错误
public enum RenderPipelineError: Error, LocalizedError {
    case parseFailed
    case layoutFailed
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .parseFailed:
            return "Failed to parse template"
        case .layoutFailed:
            return "Failed to calculate layout"
        case .cancelled:
            return "Pipeline was cancelled"
        }
    }
}

// MARK: - 管道池

/// 渲染管道池
/// 
/// 复用 RenderPipeline 实例，减少内存分配
public final class RenderPipelinePool {
    
    public static let shared = RenderPipelinePool()
    
    /// 池中的管道
    private var pool: [RenderPipeline] = []
    
    /// 最大池大小
    public var maxPoolSize: Int = 8
    
    /// 默认配置（新创建或复用的管道会应用此配置）
    var defaultConfig = RenderPipeline.Config()
    
    /// 锁
    private var lock = os_unfair_lock()
    
    private init() {}
    
    /// 获取管道
    func acquire() -> RenderPipeline {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if let pipeline = pool.popLast() {
            pipeline.reset()
            pipeline.config = defaultConfig
            return pipeline
        }
        
        let pipeline = RenderPipeline()
        pipeline.config = defaultConfig
        return pipeline
    }
    
    /// 归还管道
    func release(_ pipeline: RenderPipeline) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if pool.count < maxPoolSize {
            pipeline.reset()
            pool.append(pipeline)
        }
    }
    
    /// 清空池
    public func clear() {
        os_unfair_lock_lock(&lock)
        pool.removeAll()
        os_unfair_lock_unlock(&lock)
    }
    
    /// 当前池大小
    public var count: Int {
        os_unfair_lock_lock(&lock)
        let c = pool.count
        os_unfair_lock_unlock(&lock)
        return c
    }
}
