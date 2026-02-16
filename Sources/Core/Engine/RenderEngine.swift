import UIKit
import os.lock

// MARK: - 渲染引擎

/// 模板渲染引擎
/// 核心职责：
/// 1. 解析模板 -> 组件树
/// 2. 计算布局
/// 3. 创建/更新视图
/// 4. 支持增量更新（Diff）
public final class RenderEngine {
    
    // MARK: - 单例
    
    public static let shared = RenderEngine()
    
    // MARK: - 配置
    
    /// 渲染配置
    public struct Config {
        /// 是否启用视图复用
        public var enableViewReuse: Bool = true
        
        /// 是否启用布局缓存
        public var enableLayoutCache: Bool = true
        
        /// 是否启用性能监控
        public var enablePerformanceMonitor: Bool = false
        
        /// 是否启用增量更新（Diff）
        public var enableIncrementalUpdate: Bool = true
        
        /// 是否启用更新动画
        public var enableUpdateAnimation: Bool = false
        
        /// 更新动画时长
        public var updateAnimationDuration: TimeInterval = 0.25
        
        /// 是否优先使用并发渲染
        /// 
        /// 当设置为 true 时：
        /// - 单个渲染：parse + layout 在子线程执行
        /// - 批量渲染：多个模板并发处理
        /// 
        /// 注意：createView 始终在主线程执行（UIKit 要求）
        public var preferConcurrentRender: Bool = false
        
        public init() {}
    }
    
    public var config = Config()
    
    // MARK: - 依赖
    
    private let layoutEngine = YogaLayoutEngine.shared
    private let templateParser = TemplateParser.shared
    private let templateCache = TemplateCache.shared
    private let dataBindingManager = DataBindingManager.shared
    private let expressionEngine = ExpressionEngine.shared
    private let viewDiffer = ViewDiffer.shared
    private let diffPatcher = DiffPatcher.shared
    private let viewRecyclePool = ViewRecyclePool.shared
    
    // MARK: - 渲染状态缓存
    
    /// 已渲染的组件树缓存 (viewIdentifier -> Component)
    private var renderedComponents: [String: Component] = [:]
    
    /// 已渲染的数据缓存 (viewIdentifier -> data)
    private var renderedData: [String: [String: Any]] = [:]
    
    // MARK: - 模板原型缓存（Cell 场景优化）
    
    /// 组件模板原型缓存 (templateId → Component 原型)
    /// 用于 Cell 场景，避免重复 parse，通过 clone + bind 复用
    private var componentTemplateCache: [String: Component] = [:]
    
    /// 高度缓存 (cacheKey → height)
    /// cacheKey = "\(templateId)_\(containerWidth)_\(dataId)"
    /// 使用 LRU 策略，默认容量 500
    private var heightCache: [String: CGFloat] = [:]
    private var heightCacheOrder: [String] = []
    private let heightCacheCapacity: Int = 500
    
    // MARK: - Init
    
    private init() {
        // 预热布局引擎
        layoutEngine.warmUp(nodeCount: 64)
        
        // 注册内存警告
        viewRecyclePool.registerMemoryWarningHandler()
    }
    
    // MARK: - 渲染 API
    
    /// 从模板名称渲染视图
    /// - Parameters:
    ///   - templateName: 模板名称（Bundle 中的 JSON 文件名）
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    /// - Returns: 渲染后的视图
    public func render(
        templateName: String,
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) -> UIView? {
        // 1. 尝试从缓存获取组件树
        var component: Component?
        if config.enableViewReuse {
            component = templateCache.get(templateName)
        }
        
        // 2. 缓存未命中，加载模板
        if component == nil {
            component = TemplateLoader.shared.loadFromBundle(name: templateName)
            if let c = component, config.enableViewReuse {
                templateCache.set(templateName, component: c)
            }
        }
        
        guard let rootComponent = component else {
            TXLogger.error("Failed to load template: \(templateName)")
            return nil
        }
        
        // 3. 绑定数据（如果有）
        if let data = data {
            bindData(data, to: rootComponent)
        }
        
        // 4. 渲染
        return render(component: rootComponent, containerSize: containerSize)
    }
    
    /// 从 JSON 渲染视图
    public func render(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) -> UIView? {
        let totalStart = CACurrentMediaTime()
        
        // 1. 解析模板
        let parseStart = CACurrentMediaTime()
        guard let component = templateParser.parse(json: json) else {
            return nil
        }
        let parseTime = (CACurrentMediaTime() - parseStart) * 1000
        
        // 2. 绑定数据
        let bindStart = CACurrentMediaTime()
        if let data = data {
            bindData(data, to: component)
        }
        let bindTime = (CACurrentMediaTime() - bindStart) * 1000
        
        // 3. 渲染组件
        let renderStart = CACurrentMediaTime()
        let view = render(component: component, containerSize: containerSize)
        let renderTime = (CACurrentMediaTime() - renderStart) * 1000
        
        let totalTime = (CACurrentMediaTime() - totalStart) * 1000
        TXLogger.trace("render(json): total=\(String(format: "%.2f", totalTime))ms | parse=\(String(format: "%.2f", parseTime))ms | bind=\(String(format: "%.2f", bindTime))ms | render=\(String(format: "%.2f", renderTime))ms")
        
        return view
    }
    
    /// 从组件树渲染视图
    public func render(
        component: Component,
        containerSize: CGSize
    ) -> UIView {
        // 重置统计
        viewCreationStats.reset()
        
        // 使用新的性能监控系统
        let session = config.enablePerformanceMonitor 
            ? PerformanceMonitor.shared.beginTrace("render", templateId: component.id)
            : nil
        defer { session?.end() }
        
        // 1. 计算布局
        let layoutStart = CACurrentMediaTime()
        let layoutResults: [String: LayoutResult]
        if let session = session {
            layoutResults = session.measure("layout") {
                layoutEngine.calculateLayout(for: component, containerSize: containerSize)
            }
        } else {
            layoutResults = layoutEngine.calculateLayout(for: component, containerSize: containerSize)
        }
        let layoutTime = (CACurrentMediaTime() - layoutStart) * 1000
        
        // 2. 应用布局结果
        let applyLayoutStart = CACurrentMediaTime()
        applyLayoutResults(layoutResults, to: component)
        let applyLayoutTime = (CACurrentMediaTime() - applyLayoutStart) * 1000
        
        // 3. 创建视图树
        let createViewStart = CACurrentMediaTime()
        let rootView: UIView
        if let session = session {
            rootView = session.measure("createView") {
                createViewTree(component, isRoot: true)
            }
        } else {
            rootView = createViewTree(component, isRoot: true)
        }
        let createViewTime = (CACurrentMediaTime() - createViewStart) * 1000
        
        // 4. 更新视图
        let updateViewStart = CACurrentMediaTime()
        if let session = session {
            session.measure("updateView") {
                updateViewTree(component)
            }
        } else {
            updateViewTree(component)
        }
        let updateViewTime = (CACurrentMediaTime() - updateViewStart) * 1000
        
        // 5. 缓存渲染状态
        let viewId = generateViewIdentifier(rootView)
        renderedComponents[viewId] = component
        
        return rootView
    }
    
    // MARK: - 增量更新 API
    
    /// 增量更新：只更新变化的部分
    /// - Parameters:
    ///   - view: 已渲染的视图
    ///   - data: 新数据
    ///   - containerSize: 容器尺寸
    /// - Returns: 更新操作数量（0 表示无变化）
    @discardableResult
    public func update(
        view: UIView,
        data: [String: Any],
        containerSize: CGSize
    ) -> Int {
        let viewId = generateViewIdentifier(view)
        
        guard let oldComponent = renderedComponents[viewId] else {
            TXLogger.info("No cached component for view, performing full render")
            return -1
        }
        
        // 检查是否启用增量更新
        guard config.enableIncrementalUpdate else {
            // 回退到全量更新
            fullUpdate(component: oldComponent, data: data, containerSize: containerSize)
            return -1
        }
        
        let session = config.enablePerformanceMonitor 
            ? PerformanceMonitor.shared.beginTrace("update", templateId: oldComponent.id)
            : nil
        defer { session?.end() }
        
        // 1. 克隆组件树并绑定新数据
        session?.mark("clone_start")
        let newComponent = cloneComponentTree(oldComponent)
        bindData(data, to: newComponent)
        session?.mark("clone_end")
        
        // 2. 计算 Diff
        session?.mark("diff_start")
        let diffResult = viewDiffer.diff(oldTree: oldComponent, newTree: newComponent)
        session?.mark("diff_end")
        
        // 3. 判断是否有变化
        guard diffResult.hasDiff else {
            return 0
        }
        
        // 4. 配置 Patcher
        diffPatcher.config.enableViewRecycle = config.enableViewReuse
        diffPatcher.config.enableAnimation = config.enableUpdateAnimation
        diffPatcher.config.animationDuration = config.updateAnimationDuration
        
        // 5. 应用 Diff
        session?.mark("patch_start")
        diffPatcher.apply(diffResult, to: oldComponent, rootView: view, containerSize: containerSize)
        session?.mark("patch_end")
        
        // 6. 更新缓存
        renderedData[viewId] = data
        
        // 7. 输出日志
        if config.enablePerformanceMonitor {
            let stats = diffResult.statistics
            TXLogger.debug("Diff stats: \(stats.description)")
        }
        
        return diffResult.operationCount
    }
    
    /// 快速更新：只更新数据绑定，不改变结构
    /// 适用于确定结构不变的场景
    public func quickUpdate(
        view: UIView,
        data: [String: Any],
        containerSize: CGSize
    ) {
        let viewId = generateViewIdentifier(view)
        
        guard let component = renderedComponents[viewId] else {
            TXLogger.info("No cached component for view")
            return
        }
        
        diffPatcher.quickUpdate(data: data, to: component, containerSize: containerSize)
        renderedData[viewId] = data
    }
    
    /// 全量更新：重新绑定数据并更新所有视图
    public func fullUpdate(
        component: Component,
        data: [String: Any],
        containerSize: CGSize
    ) {
        // 绑定新数据
        bindData(data, to: component)
        
        // 重新计算布局
        let layoutResults = layoutEngine.calculateLayout(for: component, containerSize: containerSize)
        applyLayoutResults(layoutResults, to: component)
        
        // 更新视图
        updateViewTree(component)
    }
    
    // MARK: - 组件管理
    
    /// 获取视图关联的组件
    public func getComponent(for view: UIView) -> Component? {
        let viewId = generateViewIdentifier(view)
        return renderedComponents[viewId]
    }
    
    /// 获取视图最后渲染的数据
    public func getData(for view: UIView) -> [String: Any]? {
        let viewId = generateViewIdentifier(view)
        return renderedData[viewId]
    }
    
    /// 清理视图关联的缓存
    public func cleanup(view: UIView) {
        let viewId = generateViewIdentifier(view)
        
        // 回收组件树
        if let component = renderedComponents.removeValue(forKey: viewId) {
            viewRecyclePool.recycleComponentTree(component)
        }
        
        renderedData.removeValue(forKey: viewId)
    }
    
    /// 清理所有缓存
    public func clearAllCache() {
        renderedComponents.removeAll()
        renderedData.removeAll()
        templateCache.clear()
        viewRecyclePool.clear()
    }
    
    // MARK: - 数据绑定
    
    /// 绑定数据到组件树
    private func bindData(_ data: [String: Any], to component: Component) {
        dataBindingManager.bind(data: data, to: component)
    }
    
    // MARK: - 布局
    
    /// 应用布局结果到组件树（支持扁平化偏移累加）
    ///
    /// Yoga 返回的是相对于父节点的坐标。对于扁平化的父组件（没有创建 UIView），
    /// 其子组件的 view 实际上被添加到了更上层的祖先视图中，所以需要累加扁平化父组件的偏移。
    ///
    /// 注意：此方法在 createViewTree() 之前调用，所以需要使用 canFlatten 来判断
    /// 是否需要扁平化，并同时设置 isFlattened 标记。
    ///
    /// - Parameters:
    ///   - results: Yoga 计算的布局结果（相对坐标）
    ///   - component: 目标组件
    ///   - parentOffset: 扁平化父组件的累计偏移
    private func applyLayoutResults(
        _ results: [String: LayoutResult],
        to component: Component,
        parentOffset: CGPoint = .zero
    ) {
        // 获取 Yoga 计算的相对坐标
        guard let result = results[component.id] else {
            // 如果没有布局结果，继续处理子组件
            for child in component.children {
                applyLayoutResults(results, to: child, parentOffset: parentOffset)
            }
            return
        }
        
        // 计算当前组件应该累加到子组件的偏移
        var offsetForChildren: CGPoint = .zero
        
        // 应用布局结果
        var adjustedResult = result
        
        // 使用 canFlatten 判断（因为此方法在 createViewTree 之前调用，isFlattened 可能还未设置）
        // 同时设置 isFlattened 标记，供后续 createViewTree 使用
        let shouldFlatten = component.canFlatten
        if shouldFlatten {
            component.isFlattened = true
            // 扁平化组件：不设置自己的 frame（因为没有 view）
            // 但需要把自己的位置偏移传递给子组件
            offsetForChildren = CGPoint(
                x: parentOffset.x + result.frame.origin.x,
                y: parentOffset.y + result.frame.origin.y
            )
            component.layoutResult = result  // 保留原始结果用于其他用途
        } else {
            component.isFlattened = false
            // 非扁平化组件：累加父偏移到自己的 frame
            if parentOffset != .zero {
                adjustedResult.frame.origin.x += parentOffset.x
                adjustedResult.frame.origin.y += parentOffset.y
            }
            component.layoutResult = adjustedResult
            // 非扁平化组件的子组件不需要额外偏移
            offsetForChildren = .zero
        }
        
        // 递归处理子组件
        for child in component.children {
            applyLayoutResults(results, to: child, parentOffset: offsetForChildren)
        }
    }
    
    // MARK: - 视图创建统计（调试用）
    
    private class ViewCreationStats {
        var viewCount = 0
        var createViewTime: Double = 0
        var addSubviewTime: Double = 0
        var viewTypeStats: [String: (count: Int, time: Double)] = [:]
        
        func reset() {
            viewCount = 0
            createViewTime = 0
            addSubviewTime = 0
            viewTypeStats.removeAll()
        }
        
        func recordCreate(type: String, time: Double) {
            viewCount += 1
            createViewTime += time
            var stat = viewTypeStats[type] ?? (0, 0)
            stat.count += 1
            stat.time += time
            viewTypeStats[type] = stat
        }
        
        func recordAddSubview(time: Double) {
            addSubviewTime += time
        }
    }
    
    private let viewCreationStats = ViewCreationStats()
    
    // MARK: - 视图创建
    
    /// 创建视图树（支持视图扁平化）
    ///
    /// 扁平化原理：
    /// - 纯布局容器（无视觉效果、无事件）不创建真实 UIView
    /// - 子组件直接添加到最近的非扁平化祖先视图
    /// - 子组件的 frame 由 applyLayoutResults 统一处理偏移累加
    ///
    /// - Parameters:
    ///   - component: 组件
    /// - Returns: 创建的视图（扁平化组件返回临时容器）
    private func createViewTree(_ component: Component, isRoot: Bool = false) -> UIView {
        
        // 检查是否可以扁平化（根节点永远不扁平化）
        if !isRoot && component.canFlatten {
            component.isFlattened = true
            
            // 创建一个临时容器来收集子视图（不会真正添加到视图层级）
            let tempContainer = UIView()
            tempContainer.isHidden = true  // 标记为临时容器
            
            for child in component.children {
                let childView = createViewTree(child, isRoot: false)
                tempContainer.addSubview(childView)
            }
            
            // 返回临时容器，由父视图提取子视图
            return tempContainer
        }
        
        // 非扁平化：正常创建视图
        let view: UIView
        let createStart = CACurrentMediaTime()
        if let existingView = component.view {
            view = existingView
        } else if config.enableViewReuse, let recycledView = viewRecyclePool.dequeueView(forType: component.type) {
            view = recycledView
            component.view = view
            // 复用视图时需要强制应用样式，避免旧样式残留
            if let baseComponent = component as? BaseComponent {
                baseComponent.forceApplyStyle = true
            }
        } else {
            view = component.createView()
        }
        let createTime = (CACurrentMediaTime() - createStart) * 1000
        viewCreationStats.recordCreate(type: component.type, time: createTime)
        
        // 标记组件类型
        view.componentType = component.type
        view.accessibilityIdentifier = component.id
        
        // 注意：frame 偏移累加已在 applyLayoutResults 中统一处理
        
        // 递归创建子视图
        for (index, child) in component.children.enumerated() {
            let result = createViewTree(child, isRoot: false)
            
            // 检查是否是扁平化产生的临时容器
            if result.isHidden && result.componentType == nil {
                // 提取临时容器中的所有子视图，添加到当前视图
                let addStart = CACurrentMediaTime()
                for subview in result.subviews {
                    subview.removeFromSuperview()
                    view.addSubview(subview)
                }
                viewCreationStats.recordAddSubview(time: (CACurrentMediaTime() - addStart) * 1000)
            } else {
                // 正常添加子视图
                if result.superview !== view {
                    let addStart = CACurrentMediaTime()
                    view.addSubview(result)
                    viewCreationStats.recordAddSubview(time: (CACurrentMediaTime() - addStart) * 1000)
                }
            }
        }
        
        return view
    }
    
    /// 更新视图树
    private func updateViewTree(_ component: Component) {
        component.updateView()
        
        for child in component.children {
            updateViewTree(child)
        }
    }
    
    // MARK: - 组件克隆
    
    /// 深度克隆组件树
    /// 使用 Component 协议的 clone() 方法，确保组件特有属性被正确复制
    private func cloneComponentTree(_ component: Component) -> Component {
        // 使用组件自身的 clone 方法（包含组件特有属性）
        let cloned = component.clone()
        
        // 递归克隆子组件
        for child in component.children {
            let clonedChild = cloneComponentTree(child)
            clonedChild.parent = cloned
            cloned.children.append(clonedChild)
        }
        
        return cloned
    }
    
    // MARK: - 工具方法
    
    private func generateViewIdentifier(_ view: UIView) -> String {
        return "\(ObjectIdentifier(view))"
    }
}

// MARK: - 性能监控 (使用 PerformanceMonitor.swift 中的定义)

// MARK: - 便捷扩展

extension RenderEngine {
    
    /// 快速创建视图
    public func createView(
        from json: String,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return render(json: dict, containerSize: size)
    }
    
    /// 渲染并返回 RenderResult（包含组件引用）
    public func renderWithResult(
        templateName: String,
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) -> RenderResult? {
        guard let view = render(templateName: templateName, data: data, containerSize: containerSize),
              let component = getComponent(for: view) else {
            return nil
        }
        
        return RenderResult(view: view, component: component, engine: self)
    }
}

// MARK: - 异步渲染 API

extension RenderEngine {
    
    /// 异步渲染引擎实例
    public var asyncEngine: AsyncRenderEngine {
        return AsyncRenderEngine.shared
    }
    
    /// 从 JSON 异步渲染视图
    /// - Parameters:
    ///   - json: JSON 字典
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    ///   - completion: 完成回调（主线程）
    public func renderAsync(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) {
        asyncEngine.renderAsync(json: json, data: data, containerSize: containerSize, completion: completion)
    }
    
    /// 从模板名称异步渲染
    public func renderAsync(
        templateName: String,
        data: [String: Any]? = nil,
        containerSize: CGSize,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) {
        asyncEngine.renderAsync(templateName: templateName, data: data, containerSize: containerSize, completion: completion)
    }
    
    /// 异步增量更新
    public func updateAsync(
        view: UIView,
        data: [String: Any],
        containerSize: CGSize,
        completion: @escaping (Result<Int, RenderError>) -> Void
    ) {
        asyncEngine.updateAsync(view: view, data: data, containerSize: containerSize, completion: completion)
    }
}

// MARK: - Async/Await 支持 (iOS 13+)

@available(iOS 13.0, *)
extension RenderEngine {
    
    /// 使用 async/await 异步渲染 JSON
    public func render(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) async throws -> RenderOutput {
        try await asyncEngine.render(json: json, data: data, containerSize: containerSize)
    }
    
    /// 使用 async/await 异步渲染模板
    public func render(
        templateName: String,
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) async throws -> RenderOutput {
        try await asyncEngine.render(templateName: templateName, data: data, containerSize: containerSize)
    }
    
    /// 使用 async/await 异步更新
    public func update(
        view: UIView,
        data: [String: Any],
        containerSize: CGSize
    ) async throws -> Int {
        try await asyncEngine.update(view: view, data: data, containerSize: containerSize)
    }
}

// MARK: - 渲染结果

/// 渲染结果，封装视图和组件的引用
public final class RenderResult {
    
    public let view: UIView
    public let component: Component
    private weak var engine: RenderEngine?
    
    init(view: UIView, component: Component, engine: RenderEngine) {
        self.view = view
        self.component = component
        self.engine = engine
    }
    
    /// 更新数据
    @discardableResult
    public func update(data: [String: Any], containerSize: CGSize? = nil) -> Int {
        let size = containerSize ?? view.bounds.size
        return engine?.update(view: view, data: data, containerSize: size) ?? -1
    }
    
    /// 快速更新（只更新绑定）
    public func quickUpdate(data: [String: Any], containerSize: CGSize? = nil) {
        let size = containerSize ?? view.bounds.size
        engine?.quickUpdate(view: view, data: data, containerSize: size)
    }
    
    /// 清理资源
    public func cleanup() {
        engine?.cleanup(view: view)
    }
}

// MARK: - 批量并发渲染

/// 批量渲染任务
public struct BatchRenderTask {
    public let id: String
    public let json: [String: Any]
    public let data: [String: Any]?
    public let containerSize: CGSize
    
    public init(id: String, json: [String: Any], data: [String: Any]? = nil, containerSize: CGSize) {
        self.id = id
        self.json = json
        self.data = data
        self.containerSize = containerSize
    }
}

/// 批量渲染结果
public struct BatchRenderResult {
    public let id: String
    public let view: UIView?
    public let error: Error?
    
    public var isSuccess: Bool { view != nil }
}

/// 预处理结果（parse + layout 完成，等待 createView）
private struct PreparedRender {
    let id: String
    let component: Component
    let layoutResults: [String: LayoutResult]
}

extension RenderEngine {
    
    /// 批量并发渲染
    /// 
    /// 原理：
    /// 1. 子线程并发执行所有任务的 parse + bind + layout
    /// 2. 回到主线程串行执行 createView + updateView
    ///
    /// 性能提升：
    /// - 6个模板串行: ~10ms
    /// - 6个模板并发: ~3-4ms (理论值)
    ///
    /// - Parameters:
    ///   - tasks: 渲染任务列表
    ///   - completion: 完成回调（主线程）
    public func renderBatch(
        _ tasks: [BatchRenderTask],
        completion: @escaping ([BatchRenderResult]) -> Void
    ) {
        let totalStart = CACurrentMediaTime()
        
        guard !tasks.isEmpty else {
            completion([])
            return
        }
        
        // 子线程并发执行 parse + layout
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let prepareStart = CACurrentMediaTime()
            
            // 使用 DispatchGroup 等待所有任务完成
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "com.templatex.batch", attributes: .concurrent)
            
            // 线程安全的结果收集
            var preparedResults: [String: PreparedRender] = [:]
            var errors: [String: Error] = [:]
            var lock = os_unfair_lock()
            
            for task in tasks {
                group.enter()
                queue.async {
                    do {
                        // 1. Parse
                        guard let component = self.templateParser.parse(json: task.json) else {
                            throw RenderError.parseError("Failed to parse template: \(task.id)")
                        }
                        
                        // 2. Bind data
                        if let data = task.data {
                            self.dataBindingManager.bind(data: data, to: component)
                        }
                        
                        // 3. Layout (Yoga 是线程安全的)
                        let layoutResults = self.layoutEngine.calculateLayout(
                            for: component,
                            containerSize: task.containerSize
                        )
                        
                        // 4. 保存结果
                        let prepared = PreparedRender(
                            id: task.id,
                            component: component,
                            layoutResults: layoutResults
                        )
                        
                        os_unfair_lock_lock(&lock)
                        preparedResults[task.id] = prepared
                        os_unfair_lock_unlock(&lock)
                        
                    } catch {
                        os_unfair_lock_lock(&lock)
                        errors[task.id] = error
                        os_unfair_lock_unlock(&lock)
                    }
                    
                    group.leave()
                }
            }
            
            // 等待所有任务完成
            group.wait()
            
            let prepareTime = (CACurrentMediaTime() - prepareStart) * 1000
            
            // 回到主线程创建视图
            DispatchQueue.main.async {
                let createViewStart = CACurrentMediaTime()
                
                var results: [BatchRenderResult] = []
                results.reserveCapacity(tasks.count)
                
                // 按原始顺序处理结果
                for task in tasks {
                    if let prepared = preparedResults[task.id] {
                        // Apply layout
                        self.applyLayoutResults(prepared.layoutResults, to: prepared.component)
                        
                        // Create view tree (主线程)
                        let view = self.createViewTree(prepared.component)
                        
                        // Update view
                        self.updateViewTree(prepared.component)
                        
                        // Cache
                        let viewId = self.generateViewIdentifier(view)
                        self.renderedComponents[viewId] = prepared.component
                        
                        results.append(BatchRenderResult(id: task.id, view: view, error: nil))
                    } else if let error = errors[task.id] {
                        results.append(BatchRenderResult(id: task.id, view: nil, error: error))
                    }
                }
                
                let createViewTime = (CACurrentMediaTime() - createViewStart) * 1000
                let totalTime = (CACurrentMediaTime() - totalStart) * 1000
                
                TXLogger.trace("renderBatch: total=\(String(format: "%.2f", totalTime))ms | prepare=\(String(format: "%.2f", prepareTime))ms | createView=\(String(format: "%.2f", createViewTime))ms | count=\(tasks.count)")
                
                completion(results)
            }
        }
    }
    
    /// 批量同步渲染（子线程并发 parse+layout，当前线程串行 createView）
    /// 
    /// 适用于 viewDidLoad 等需要同步结果的场景
    /// 
    /// 原理：
    /// 1. 分发到子线程并发执行 parse + bind + layout
    /// 2. 主线程等待子线程完成（通过信号量）
    /// 3. 在主线程串行执行 createView + updateView
    /// 
    /// - Note: 必须在主线程调用（UIKit 要求）
    public func renderBatchSync(_ tasks: [BatchRenderTask]) -> [BatchRenderResult] {
        assert(Thread.isMainThread, "renderBatchSync must be called on main thread")
        
        let totalStart = CACurrentMediaTime()
        
        guard !tasks.isEmpty else {
            return []
        }
        
        // 阶段1: 子线程并发执行 parse + layout
        let semaphore = DispatchSemaphore(value: 0)
        var preparedResults: [String: PreparedRender] = [:]
        var errors: [String: Error] = [:]
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let prepareStart = CACurrentMediaTime()
            
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "com.templatex.batch.sync", attributes: .concurrent)
            var lock = os_unfair_lock()
            
            for task in tasks {
                group.enter()
                queue.async {
                    do {
                        guard let component = self.templateParser.parse(json: task.json) else {
                            throw RenderError.parseError("Failed to parse template: \(task.id)")
                        }
                        
                        if let data = task.data {
                            self.dataBindingManager.bind(data: data, to: component)
                        }
                        
                        let layoutResults = self.layoutEngine.calculateLayout(
                            for: component,
                            containerSize: task.containerSize
                        )
                        
                        let prepared = PreparedRender(
                            id: task.id,
                            component: component,
                            layoutResults: layoutResults
                        )
                        
                        os_unfair_lock_lock(&lock)
                        preparedResults[task.id] = prepared
                        os_unfair_lock_unlock(&lock)
                        
                    } catch {
                        os_unfair_lock_lock(&lock)
                        errors[task.id] = error
                        os_unfair_lock_unlock(&lock)
                    }
                    
                    group.leave()
                }
            }
            
            group.wait()
            
            let prepareTime = (CACurrentMediaTime() - prepareStart) * 1000
            TXLogger.trace("renderBatchSync: prepare=\(String(format: "%.2f", prepareTime))ms (concurrent)")
            
            // 通知主线程可以继续
            semaphore.signal()
        }
        
        // 阶段2: 主线程等待子线程完成
        semaphore.wait()
        
        // 阶段3: 主线程串行执行 createView（此时已经在主线程）
        let createViewStart = CACurrentMediaTime()
        var results: [BatchRenderResult] = []
        results.reserveCapacity(tasks.count)
        
        for task in tasks {
            if let prepared = preparedResults[task.id] {
                applyLayoutResults(prepared.layoutResults, to: prepared.component)
                let view = createViewTree(prepared.component)
                updateViewTree(prepared.component)
                
                let viewId = generateViewIdentifier(view)
                renderedComponents[viewId] = prepared.component
                
                results.append(BatchRenderResult(id: task.id, view: view, error: nil))
            } else if let error = errors[task.id] {
                results.append(BatchRenderResult(id: task.id, view: nil, error: error))
            }
        }
        
        let createViewTime = (CACurrentMediaTime() - createViewStart) * 1000
        let totalTime = (CACurrentMediaTime() - totalStart) * 1000
        
        TXLogger.trace("renderBatchSync: total=\(String(format: "%.2f", totalTime))ms | createView=\(String(format: "%.2f", createViewTime))ms | count=\(tasks.count)")
        
        return results
    }
}

// MARK: - Cell 场景优化 API

/// 高度计算任务
public struct HeightCalculationTask {
    public let id: String
    public let json: [String: Any]
    public let templateId: String
    public let data: [String: Any]?
    public let containerWidth: CGFloat
    
    public init(
        id: String,
        json: [String: Any],
        templateId: String,
        data: [String: Any]? = nil,
        containerWidth: CGFloat
    ) {
        self.id = id
        self.json = json
        self.templateId = templateId
        self.data = data
        self.containerWidth = containerWidth
    }
}

/// 高度计算结果
public struct HeightCalculationResult {
    public let id: String
    public let height: CGFloat
    public let error: Error?
    
    public var isSuccess: Bool { error == nil }
}

extension RenderEngine {
    
    // MARK: - 模板缓存渲染（Cell 场景）
    
    /// 使用模板缓存渲染（适用于 Cell 场景）
    ///
    /// 流程：
    /// 1. 检查 componentTemplateCache 是否存在该 templateId 的原型
    /// 2. 命中：clone → bind → layout → createView
    /// 3. 未命中：parse → cache 原型 → 继续上述流程
    ///
    /// 相比普通 render()，避免了重复 parse 开销
    ///
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - templateId: 模板标识符（缓存 key）
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    /// - Returns: 渲染的视图
    public func renderWithCache(
        json: [String: Any],
        templateId: String,
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) -> UIView? {
        let totalStart = CACurrentMediaTime()
        
        // 1. 获取或创建模板原型
        let prototypeStart = CACurrentMediaTime()
        let prototype: Component
        if let cached = componentTemplateCache[templateId] {
            prototype = cached
        } else {
            guard let parsed = templateParser.parse(json: json) else {
                return nil
            }
            componentTemplateCache[templateId] = parsed
            prototype = parsed
        }
        let prototypeTime = (CACurrentMediaTime() - prototypeStart) * 1000
        
        // 2. 克隆组件树
        let cloneStart = CACurrentMediaTime()
        let component = cloneComponentTree(prototype)
        let cloneTime = (CACurrentMediaTime() - cloneStart) * 1000
        
        // 3. 绑定数据
        let bindStart = CACurrentMediaTime()
        if let data = data {
            bindData(data, to: component)
        }
        let bindTime = (CACurrentMediaTime() - bindStart) * 1000
        
        // 4. 渲染（layout + createView + updateView）
        
        return render(component: component, containerSize: containerSize)
    }
    
    // MARK: - 高度计算（不创建视图）
    
    /// 计算模板高度（只计算布局，不创建视图）
    ///
    /// 用于 UICollectionView/UITableView 的 sizeForItemAt 回调
    /// 使用高度缓存避免重复计算，缓存 key 为 templateId + containerWidth + data["id"]
    ///
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - templateId: 模板标识符
    ///   - data: 绑定数据（需要包含 "id" 字段用于缓存）
    ///   - containerWidth: 容器宽度
    ///   - useCache: 是否使用高度缓存（默认 true）
    /// - Returns: 计算得到的高度
    public func calculateHeight(
        json: [String: Any],
        templateId: String,
        data: [String: Any]? = nil,
        containerWidth: CGFloat,
        useCache: Bool = true
    ) -> CGFloat {
        // 1. 尝试从缓存获取
        let cacheKey = makeHeightCacheKey(templateId: templateId, data: data, containerWidth: containerWidth)
        if useCache, let cachedHeight = heightCache[cacheKey] {
            return cachedHeight
        }
        
        let totalStart = CACurrentMediaTime()
        
        // 2. 获取或解析模板原型
        let prototype: Component
        if let cached = componentTemplateCache[templateId] {
            prototype = cached
        } else {
            guard let parsed = templateParser.parse(json: json) else {
                TXLogger.error("calculateHeight: failed to parse template \(templateId)")
                return 0
            }
            componentTemplateCache[templateId] = parsed
            prototype = parsed
        }
        
        // 3. 克隆 + 绑定数据
        let component = cloneComponentTree(prototype)
        if let data = data {
            bindData(data, to: component)
        }
        
        // 4. 计算布局（使用 NaN 高度让 Yoga 自动计算）
        let containerSize = CGSize(width: containerWidth, height: .nan)
        let layoutResults = layoutEngine.calculateLayout(for: component, containerSize: containerSize)
        
        // 5. 获取根组件高度
        let height = layoutResults[component.id]?.frame.height ?? 0
        
        // 6. 缓存结果
        if useCache {
            setHeightCache(key: cacheKey, height: height)
        }
        
        return height
    }
    
    // MARK: - 批量高度计算（并发）
    
    /// 批量并发计算高度
    ///
    /// 用于 UICollectionView prefetch 场景，子线程并发执行 parse + bind + layout
    ///
    /// - Parameters:
    ///   - tasks: 高度计算任务列表
    ///   - completion: 完成回调（主线程）
    public func calculateHeightsBatch(
        _ tasks: [HeightCalculationTask],
        completion: @escaping ([HeightCalculationResult]) -> Void
    ) {
        guard !tasks.isEmpty else {
            completion([])
            return
        }
                
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "com.templatex.height.batch", attributes: .concurrent)
            
            var results: [String: HeightCalculationResult] = [:]
            var lock = os_unfair_lock()
            
            for task in tasks {
                // 先检查缓存
                let cacheKey = makeHeightCacheKey(templateId: task.templateId, data: task.data, containerWidth: task.containerWidth)
                if let cachedHeight = heightCache[cacheKey] {
                    os_unfair_lock_lock(&lock)
                    results[task.id] = HeightCalculationResult(id: task.id, height: cachedHeight, error: nil)
                    os_unfair_lock_unlock(&lock)
                    continue
                }
                
                group.enter()
                queue.async {
                    do {
                        // 获取或解析模板原型
                        let prototype: Component
                        if let cached = self.componentTemplateCache[task.templateId] {
                            prototype = cached
                        } else {
                            guard let parsed = self.templateParser.parse(json: task.json) else {
                                throw RenderError.parseError("Failed to parse template: \(task.templateId)")
                            }
                            // 注意：这里可能有并发写入问题，但影响不大（最多重复解析）
                            self.componentTemplateCache[task.templateId] = parsed
                            prototype = parsed
                        }
                        
                        // 克隆 + 绑定
                        let component = self.cloneComponentTree(prototype)
                        if let data = task.data {
                            self.dataBindingManager.bind(data: data, to: component)
                        }
                        
                        // 计算布局
                        let containerSize = CGSize(width: task.containerWidth, height: .nan)
                        let layoutResults = self.layoutEngine.calculateLayout(for: component, containerSize: containerSize)
                        let height = layoutResults[component.id]?.frame.height ?? 0
                        
                        // 缓存结果
                        self.setHeightCache(key: cacheKey, height: height)
                        
                        os_unfair_lock_lock(&lock)
                        results[task.id] = HeightCalculationResult(id: task.id, height: height, error: nil)
                        os_unfair_lock_unlock(&lock)
                        
                    } catch {
                        os_unfair_lock_lock(&lock)
                        results[task.id] = HeightCalculationResult(id: task.id, height: 0, error: error)
                        os_unfair_lock_unlock(&lock)
                    }
                    
                    group.leave()
                }
            }
            
            group.wait()
                        
            // 按原始顺序返回结果
            let orderedResults = tasks.map { task in
                results[task.id] ?? HeightCalculationResult(id: task.id, height: 0, error: RenderError.unknown("Result not found"))
            }
            
            DispatchQueue.main.async {
                completion(orderedResults)
            }
        }
    }
    
    /// 批量同步计算高度
    ///
    /// 子线程并发执行，主线程等待结果
    /// 必须在主线程调用
    public func calculateHeightsBatchSync(_ tasks: [HeightCalculationTask]) -> [HeightCalculationResult] {
        assert(Thread.isMainThread, "calculateHeightsBatchSync must be called on main thread")
        
        guard !tasks.isEmpty else {
            return []
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var results: [HeightCalculationResult] = []
        
        calculateHeightsBatch(tasks) { batchResults in
            results = batchResults
            semaphore.signal()
        }
        
        semaphore.wait()
        return results
    }
    
    // MARK: - 缓存管理
    
    /// 清理模板原型缓存
    /// - Parameter templateId: 指定模板 ID，nil 表示清空全部
    public func clearTemplateCache(templateId: String? = nil) {
        if let templateId = templateId {
            componentTemplateCache.removeValue(forKey: templateId)
            TXLogger.info("Cleared template cache for: \(templateId)")
        } else {
            componentTemplateCache.removeAll()
            TXLogger.info("Cleared all template cache")
        }
    }
    
    /// 清理高度缓存
    /// - Parameter templateId: 指定模板 ID 前缀，nil 表示清空全部
    public func clearHeightCache(templateId: String? = nil) {
        if let templateId = templateId {
            let prefix = "\(templateId)_"
            let keysToRemove = heightCache.keys.filter { $0.hasPrefix(prefix) }
            for key in keysToRemove {
                heightCache.removeValue(forKey: key)
                if let index = heightCacheOrder.firstIndex(of: key) {
                    heightCacheOrder.remove(at: index)
                }
            }
            TXLogger.info("Cleared height cache for templateId: \(templateId), removed \(keysToRemove.count) entries")
        } else {
            heightCache.removeAll()
            heightCacheOrder.removeAll()
            TXLogger.info("Cleared all height cache")
        }
    }
    
    /// 获取模板缓存数量
    public var templateCacheCount: Int {
        return componentTemplateCache.count
    }
    
    /// 获取高度缓存数量
    public var heightCacheCount: Int {
        return heightCache.count
    }
    
    // MARK: - 高度缓存辅助方法
    
    /// 生成高度缓存 key
    /// 格式：templateId_width_dataId
    private func makeHeightCacheKey(templateId: String, data: [String: Any]?, containerWidth: CGFloat) -> String {
        let widthKey = String(format: "%.0f", containerWidth)
        
        // 尝试从 data 中获取 id 字段
        if let data = data {
            if let id = data["id"] as? String {
                return "\(templateId)_\(widthKey)_\(id)"
            } else if let id = data["id"] as? Int {
                return "\(templateId)_\(widthKey)_\(id)"
            } else if let id = data["_id"] as? String {
                return "\(templateId)_\(widthKey)_\(id)"
            }
        }
        
        // 没有 id，使用内存地址（不会缓存命中）
        let ptr = data.map { "\(ObjectIdentifier($0 as AnyObject))" } ?? "nil"
        return "\(templateId)_\(widthKey)_\(ptr)"
    }
    
    /// 设置高度缓存（LRU 策略）
    private func setHeightCache(key: String, height: CGFloat) {
        // 如果已存在，更新访问顺序
        if heightCache[key] != nil {
            if let index = heightCacheOrder.firstIndex(of: key) {
                heightCacheOrder.remove(at: index)
            }
            heightCacheOrder.append(key)
            heightCache[key] = height
            return
        }
        
        // 容量检查，移除最旧的
        while heightCache.count >= heightCacheCapacity && !heightCacheOrder.isEmpty {
            let oldest = heightCacheOrder.removeFirst()
            heightCache.removeValue(forKey: oldest)
        }
        
        // 插入新条目
        heightCache[key] = height
        heightCacheOrder.append(key)
    }
}
