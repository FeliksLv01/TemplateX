import UIKit

// MARK: - 列表预加载管理器

/// 列表预加载管理器
///
/// 借鉴 Lynx 的 ListPreloadCache + GapWorker 设计：
/// - Cell 模板预编译：在列表创建时预先解析 Cell 模板
/// - Cell 高度预计算：批量预计算所有数据项的高度
/// - GapWorker 闲时预加载：在帧空闲时间预创建即将进入屏幕的 Cell
///
/// 使用示例：
/// ```swift
/// let manager = ListPreloadManager(
///     cellTemplate: template,
///     templateId: "product_cell",
///     containerWidth: 375
/// )
///
/// // 预编译模板
/// manager.precompileTemplate()
///
/// // 批量预计算高度
/// manager.precomputeHeights(for: dataSource)
///
/// // 获取缓存的高度
/// let height = manager.cachedHeight(for: index)
/// ```
public final class ListPreloadManager {
    
    // MARK: - 配置
    
    /// 预加载配置
    public struct Config {
        /// 预加载缓冲区数量（上下各预加载多少个 Cell）
        public var preloadBufferCount: Int = 3
        
        /// 是否启用高度缓存
        public var enableHeightCache: Bool = true
        
        /// 是否启用视图预创建
        public var enableViewPreload: Bool = true
        
        /// 最大预创建视图数量
        public var maxPreloadedViews: Int = 5
        
        /// 是否启用 GapWorker 闲时预加载
        public var enableGapWorker: Bool = true
        
        public init() {}
    }
    
    /// 配置
    public var config = Config()
    
    // MARK: - 模板信息
    
    /// Cell 模板 JSON
    public let cellTemplate: JSONWrapper
    
    /// 模板 ID
    public let templateId: String
    
    /// 容器宽度
    public var containerWidth: CGFloat
    
    // MARK: - 缓存
    
    /// 预编译的组件原型（不绑定数据）
    /// 内部可访问，供 RenderPipeline 预处理使用
    internal var componentPrototype: Component?
    
    /// 高度缓存 [index: height]
    /// 内部可访问，供 RenderPipeline 预计算高度使用
    internal var heightCache: [Int: CGFloat] = [:]
    
    /// 预创建的视图缓存 [index: (view, component)]
    private var preloadedViews: [Int: (UIView, Component)] = [:]
    
    /// 上方缓存队列（向上滚动时使用）
    private var upperCache: [(UIView, Component)] = []
    
    /// 下方缓存队列（向下滚动时使用）
    private var lowerCache: [(UIView, Component)] = []
    
    // MARK: - 状态
    
    /// 是否已预编译
    public private(set) var isPrecompiled: Bool = false
    
    /// 当前可见范围
    private var visibleRange: Range<Int>?
    
    /// 上次滚动位置
    private var lastScrollOffset: CGFloat = 0
    
    /// 当前滚动状态
    private var scrollStatus: ScrollStatus = .idle
    
    // MARK: - GapWorker 集成
    
    /// GapWorker 任务组
    private var gapTaskBundle: GapTaskBundle?
    
    /// 预加载位置收集器
    private let prefetchRegistry = PrefetchRegistry()
    
    /// 预加载辅助器
    private var prefetchHelper = LinearLayoutPrefetchHelper()
    
    /// 数据源引用（用于 GapWorker 回调）
    private weak var dataSourceRef: NSArray?
    
    /// 平均 Cell 尺寸（用于计算距离）
    private var averageItemSize: CGFloat = 44
    
    // MARK: - 依赖
    
    private let templateParser = TemplateParser.shared
    private let layoutEngine = YogaLayoutEngine.shared
    private let dataBindingManager = DataBindingManager.shared
    
    /// 后台队列（用于非 GapWorker 场景）
    private let backgroundQueue = DispatchQueue(
        label: "com.templatex.listpreload",
        qos: .userInitiated
    )
    
    // MARK: - Init
    
    public init(
        cellTemplate: JSONWrapper,
        templateId: String,
        containerWidth: CGFloat
    ) {
        self.cellTemplate = cellTemplate
        self.templateId = templateId
        self.containerWidth = containerWidth
        
        // 配置预加载辅助器
        prefetchHelper.prefetchBufferCount = config.preloadBufferCount
    }
    
    deinit {
        // 取消 GapWorker 注册
        unregisterFromGapWorker()
    }
    
    // MARK: - 模板预编译
    
    /// 预编译 Cell 模板
    ///
    /// 在后台线程解析模板，创建组件原型
    /// 后续渲染时通过 clone 复用原型
    public func precompileTemplate(completion: (() -> Void)? = nil) {
        guard !isPrecompiled else {
            completion?()
            return
        }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            let start = CACurrentMediaTime()
            
            // 解析模板创建原型
            if let prototype = self.templateParser.parse(json: self.cellTemplate.rawDictionary) {
                self.componentPrototype = prototype
                self.isPrecompiled = true
                
                let elapsed = (CACurrentMediaTime() - start) * 1000
                TXLogger.trace("[ListPreloadManager] precompileTemplate: \(String(format: "%.2f", elapsed))ms")
            }
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    /// 同步预编译（主线程调用）
    public func precompileTemplateSync() {
        guard !isPrecompiled else { return }
        
        let start = CACurrentMediaTime()
        
        if let prototype = templateParser.parse(json: cellTemplate.rawDictionary) {
            componentPrototype = prototype
            isPrecompiled = true
            
            let elapsed = (CACurrentMediaTime() - start) * 1000
            TXLogger.trace("[ListPreloadManager] precompileTemplateSync: \(String(format: "%.2f", elapsed))ms")
        }
    }
    
    // MARK: - 高度预计算
    
    /// 批量预计算高度
    ///
    /// 在后台线程计算所有数据项的高度，结果缓存到 heightCache
    ///
    /// - Parameters:
    ///   - dataSource: 数据源
    ///   - completion: 完成回调
    public func precomputeHeights(
        for dataSource: [Any],
        completion: (([CGFloat]) -> Void)? = nil
    ) {
        guard config.enableHeightCache else {
            completion?([])
            return
        }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            let start = CACurrentMediaTime()
            var heights: [CGFloat] = []
            
            // 确保已预编译
            if !self.isPrecompiled {
                self.precompileTemplateSync()
            }
            
            guard let prototype = self.componentPrototype else {
                DispatchQueue.main.async {
                    completion?(heights)
                }
                return
            }
            
            // 批量计算高度
            for (index, itemData) in dataSource.enumerated() {
                // 克隆组件
                let component = self.cloneComponentTree(prototype)
                
                // 准备数据上下文
                var context: [String: Any] = [
                    "item": itemData,
                    "index": index
                ]
                if let dictData = itemData as? [String: Any] {
                    context.merge(dictData) { _, new in new }
                }
                
                // 绑定数据
                self.dataBindingManager.bind(data: context, to: component)
                
                // 计算布局
                let containerSize = CGSize(width: self.containerWidth, height: CGFloat.nan)
                let layoutResults = self.layoutEngine.calculateLayout(
                    for: component,
                    containerSize: containerSize
                )
                
                // 获取高度
                let height = layoutResults[component.id]?.frame.height ?? 44
                heights.append(height)
                self.heightCache[index] = height
            }
            
            // 更新平均尺寸
            if !heights.isEmpty {
                self.averageItemSize = heights.reduce(0, +) / CGFloat(heights.count)
            }
            
            let elapsed = (CACurrentMediaTime() - start) * 1000
            TXLogger.trace("[ListPreloadManager] precomputeHeights: count=\(dataSource.count) | \(String(format: "%.2f", elapsed))ms")
            
            DispatchQueue.main.async {
                completion?(heights)
            }
        }
    }
    
    /// 获取缓存的高度
    public func cachedHeight(for index: Int) -> CGFloat? {
        return heightCache[index]
    }
    
    /// 清除高度缓存
    public func clearHeightCache() {
        heightCache.removeAll()
    }
    
    /// 更新单个项的高度缓存
    public func updateHeightCache(for index: Int, data: Any) {
        backgroundQueue.async { [weak self] in
            guard let self = self,
                  let prototype = self.componentPrototype else { return }
            
            let component = self.cloneComponentTree(prototype)
            
            var context: [String: Any] = [
                "item": data,
                "index": index
            ]
            if let dictData = data as? [String: Any] {
                context.merge(dictData) { _, new in new }
            }
            
            self.dataBindingManager.bind(data: context, to: component)
            
            let containerSize = CGSize(width: self.containerWidth, height: CGFloat.nan)
            let layoutResults = self.layoutEngine.calculateLayout(
                for: component,
                containerSize: containerSize
            )
            
            let height = layoutResults[component.id]?.frame.height ?? 44
            
            DispatchQueue.main.async {
                self.heightCache[index] = height
            }
        }
    }
    
    // MARK: - GapWorker 集成
    
    /// 滚动状态
    private enum ScrollStatus {
        case idle
        case dragging
        case fling
        case animating
        
        var needsPrefetch: Bool {
            switch self {
            case .dragging, .fling, .animating:
                return true
            case .idle:
                return false
            }
        }
    }
    
    /// 注册到 GapWorker
    /// 对应 Lynx: base_list_view.cc:719 RegisterPrefetch
    private func registerToGapWorker() {
        guard config.enableGapWorker else { return }
        
        // 创建任务组
        gapTaskBundle = GapTaskBundle(host: self)
        
        // 注册收集器
        TemplateXGapWorker.shared.registerPrefetch(host: self) { [weak self] in
            self?.startPrefetch()
        }
    }
    
    /// 取消注册
    /// 对应 Lynx: base_list_view.cc:728 UnregisterPrefetch
    private func unregisterFromGapWorker() {
        guard config.enableGapWorker else { return }
        
        TemplateXGapWorker.shared.unregisterPrefetch(host: self)
        gapTaskBundle = nil
    }
    
    /// 开始预加载（GapWorker 回调）
    /// 对应 Lynx: base_list_view.cc:735 StartPrefetch
    private func startPrefetch() {
        guard let bundle = gapTaskBundle,
              let visibleRange = visibleRange,
              let dataSource = dataSourceRef as? [Any] else { return }
        
        // 清空旧任务
        bundle.clear()
        
        // 计算滚动方向
        let scrollDirection = lastScrollOffset
        
        // 收集预加载位置
        prefetchHelper.collectPrefetchPositions(
            into: prefetchRegistry,
            visibleRange: visibleRange,
            totalCount: dataSource.count,
            scrollDirection: scrollDirection,
            averageItemSize: averageItemSize
        )
        
        guard !prefetchRegistry.isEmpty else { return }
        
        // 获取平均绑定时间
        let estimateDuration = PerformanceMonitor.shared.getAverageBindTime(templateId: templateId)
        
        // 创建预加载任务
        for info in prefetchRegistry.getSortedPositions() {
            guard info.position < dataSource.count else { continue }
            
            let itemData = dataSource[info.position]
            var context: [String: Any] = ["item": itemData, "index": info.position]
            if let dictData = itemData as? [String: Any] {
                context.merge(dictData) { _, new in new }
            }
            
            let task = CellPrefetchTask(
                position: info.position,
                templateId: templateId,
                templateJson: cellTemplate.rawDictionary,
                cellData: context,
                containerSize: CGSize(width: containerWidth, height: heightCache[info.position] ?? averageItemSize),
                estimateDuration: estimateDuration,
                priority: Int(info.distance),
                enableForceRun: true,
                hostView: self
            )
            
            bundle.addTask(task)
        }
        
        // 排序并提交
        bundle.sort()
        TemplateXGapWorker.shared.submit(taskBundle: bundle, host: self)
    }
    
    /// 更新滚动状态
    /// 对应 Lynx: base_list_view.cc:1272 SetScrollStatus
    private func updateScrollStatus(_ newStatus: ScrollStatus) {
        let oldStatus = scrollStatus
        scrollStatus = newStatus
        
        let needsPrefetch = newStatus.needsPrefetch
        let oldNeedsPrefetch = oldStatus.needsPrefetch
        
        if needsPrefetch && !oldNeedsPrefetch {
            registerToGapWorker()
        } else if !needsPrefetch && oldNeedsPrefetch {
            unregisterFromGapWorker()
        }
    }
    
    // MARK: - 视图预加载（非 GapWorker 模式）
    
    /// 预加载指定范围的视图
    ///
    /// - Parameters:
    ///   - range: 索引范围
    ///   - dataSource: 数据源
    ///   - completion: 完成回调，返回预创建的视图
    public func preloadViews(
        for range: Range<Int>,
        dataSource: [Any],
        completion: @escaping () -> Void
    ) {
        guard config.enableViewPreload else {
            completion()
            return
        }
        
        // 如果启用了 GapWorker，交给 GapWorker 处理
        if config.enableGapWorker {
            // 使用 PrefetchCache 获取已预加载的组件
            for index in range {
                let cacheKey = PrefetchCache.cacheKey(templateId: templateId, position: index)
                if let item = PrefetchCache.shared.get(cacheKey: cacheKey) {
                    // 在主线程创建视图
                    let view = createViewTree(for: item.component)
                    preloadedViews[index] = (view, item.component)
                }
            }
            completion()
            return
        }
        
        // 非 GapWorker 模式：使用后台队列
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            let start = CACurrentMediaTime()
            var preloadCount = 0
            
            // 确保已预编译
            if !self.isPrecompiled {
                self.precompileTemplateSync()
            }
            
            guard let prototype = self.componentPrototype else {
                DispatchQueue.main.async { completion() }
                return
            }
            
            // 预加载指定范围的视图
            for index in range {
                guard index >= 0, index < dataSource.count else { continue }
                guard self.preloadedViews[index] == nil else { continue }
                guard preloadCount < self.config.maxPreloadedViews else { break }
                
                let itemData = dataSource[index]
                
                // 克隆组件
                let component = self.cloneComponentTree(prototype)
                
                // 准备数据上下文
                var context: [String: Any] = [
                    "item": itemData,
                    "index": index
                ]
                if let dictData = itemData as? [String: Any] {
                    context.merge(dictData) { _, new in new }
                }
                
                // 绑定数据
                self.dataBindingManager.bind(data: context, to: component)
                
                // 计算布局
                let height = self.heightCache[index] ?? 44
                let containerSize = CGSize(width: self.containerWidth, height: height)
                let layoutResults = self.layoutEngine.calculateLayout(
                    for: component,
                    containerSize: containerSize
                )
                
                // 应用布局结果
                self.applyLayoutResults(layoutResults, to: component)
                
                // 在主线程创建视图
                DispatchQueue.main.sync {
                    let view = self.createViewTree(for: component)
                    self.preloadedViews[index] = (view, component)
                }
                
                preloadCount += 1
            }
            
            let elapsed = (CACurrentMediaTime() - start) * 1000
            if preloadCount > 0 {
                TXLogger.trace("[ListPreloadManager] preloadViews: count=\(preloadCount) | \(String(format: "%.2f", elapsed))ms")
            }
            
            DispatchQueue.main.async { completion() }
        }
    }
    
    /// 获取预加载的视图
    ///
    /// - Parameter index: 索引
    /// - Returns: 预加载的视图（如果存在）
    public func dequeuePreloadedView(for index: Int) -> (UIView, Component)? {
        // 先检查本地缓存
        if let cached = preloadedViews.removeValue(forKey: index) {
            return cached
        }
        
        // 再检查 PrefetchCache（GapWorker 预加载的）
        if config.enableGapWorker {
            let cacheKey = PrefetchCache.cacheKey(templateId: templateId, position: index)
            if let item = PrefetchCache.shared.get(cacheKey: cacheKey) {
                let view = createViewTree(for: item.component)
                return (view, item.component)
            }
        }
        
        return nil
    }
    
    /// 回收视图到缓存
    public func recycleView(_ view: UIView, component: Component, scrollDirection: ScrollDirection) {
        switch scrollDirection {
        case .up:
            upperCache.append((view, component))
            if upperCache.count > config.maxPreloadedViews {
                upperCache.removeFirst()
            }
        case .down:
            lowerCache.append((view, component))
            if lowerCache.count > config.maxPreloadedViews {
                lowerCache.removeFirst()
            }
        }
    }
    
    /// 滚动方向
    public enum ScrollDirection {
        case up
        case down
    }
    
    // MARK: - 滚动事件处理
    
    /// 处理滚动事件，触发预加载
    ///
    /// - Parameters:
    ///   - scrollView: 滚动视图
    ///   - visibleRange: 当前可见范围
    ///   - dataSource: 数据源
    public func handleScroll(
        scrollView: UIScrollView,
        visibleRange: Range<Int>,
        dataSource: [Any]
    ) {
        let currentOffset = scrollView.contentOffset.y
        let isScrollingDown = currentOffset > lastScrollOffset
        lastScrollOffset = isScrollingDown ? 1 : -1  // 简化为方向标记
        
        self.visibleRange = visibleRange
        self.dataSourceRef = dataSource as NSArray
        
        // 更新滚动状态
        if scrollView.isDragging {
            updateScrollStatus(.dragging)
        } else if scrollView.isDecelerating {
            updateScrollStatus(.fling)
        }
        
        // 如果启用了 GapWorker，预加载由 GapWorker 在 VSYNC 时处理
        // 不需要在这里立即触发
        if config.enableGapWorker {
            return
        }
        
        // 非 GapWorker 模式：计算预加载范围
        let bufferCount = config.preloadBufferCount
        let preloadRange: Range<Int>
        
        if isScrollingDown {
            // 向下滚动，预加载下方
            let start = visibleRange.upperBound
            let end = min(start + bufferCount, dataSource.count)
            preloadRange = start..<end
        } else {
            // 向上滚动，预加载上方
            let end = visibleRange.lowerBound
            let start = max(end - bufferCount, 0)
            preloadRange = start..<end
        }
        
        // 异步预加载
        if !preloadRange.isEmpty {
            preloadViews(for: preloadRange, dataSource: dataSource) {}
        }
    }
    
    /// 滚动结束
    public func handleScrollEnd() {
        updateScrollStatus(.idle)
    }
    
    // MARK: - 清理
    
    /// 清理所有缓存
    public func clear() {
        heightCache.removeAll()
        preloadedViews.removeAll()
        upperCache.removeAll()
        lowerCache.removeAll()
        componentPrototype = nil
        isPrecompiled = false
        
        // 清理 GapWorker 相关
        unregisterFromGapWorker()
        PrefetchCache.shared.clear(templateId: templateId)
    }
    
    // MARK: - 私有方法
    
    /// 克隆组件树
    private func cloneComponentTree(_ component: Component) -> Component {
        let cloned = component.clone()
        
        for child in component.children {
            let clonedChild = cloneComponentTree(child)
            clonedChild.parent = cloned
            cloned.children.append(clonedChild)
        }
        
        return cloned
    }
    
    /// 应用布局结果
    private func applyLayoutResults(_ results: [String: LayoutResult], to component: Component) {
        if let result = results[component.id] {
            component.layoutResult = result
        }
        
        for child in component.children {
            applyLayoutResults(results, to: child)
        }
    }
    
    /// 创建视图树
    private func createViewTree(for component: Component) -> UIView {
        let view = component.createView()
        view.frame = component.layoutResult.frame
        
        for child in component.children {
            let childView = createViewTree(for: child)
            view.addSubview(childView)
        }
        
        component.updateView()
        
        return view
    }
}

// MARK: - ListComponent 扩展

extension ListComponent {
    
    /// 启用预加载优化
    ///
    /// 调用时机：在设置 cellTemplate 和 dataSource 之后
    public func enablePreloading(containerWidth: CGFloat) {
        guard let cellTemplate = cellTemplate else {
            TXLogger.warning("[ListComponent] enablePreloading: no cellTemplate found")
            return
        }
        
        let templateId = cellTemplateId ?? "list_cell_\(id)"
        
        let manager = ListPreloadManager(
            cellTemplate: cellTemplate,
            templateId: templateId,
            containerWidth: containerWidth
        )
        
        self.preloadManager = manager
        
        // 预编译模板
        manager.precompileTemplate { [weak self] in
            guard let self = self else { return }
            
            // 预计算高度
            if !self.dataSource.isEmpty {
                manager.precomputeHeights(for: self.dataSource)
            }
        }
    }
}
