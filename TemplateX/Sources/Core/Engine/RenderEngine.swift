import UIKit
import os.lock

// MARK: - 渲染错误

/// 渲染错误类型
public enum RenderError: Error, LocalizedError {
    case parseError(String)
    case layoutError(String)
    case viewCreationError(String)
    case bindingError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .parseError(let msg): return "Parse error: \(msg)"
        case .layoutError(let msg): return "Layout error: \(msg)"
        case .viewCreationError(let msg): return "View creation error: \(msg)"
        case .bindingError(let msg): return "Binding error: \(msg)"
        case .unknown(let msg): return "Unknown error: \(msg)"
        }
    }
}

// MARK: - 渲染引擎

/// 模板渲染引擎
/// 核心职责：
/// 1. 解析模板 -> 组件树
/// 2. 计算布局
/// 3. 创建/更新视图
/// 4. 支持增量更新（Diff）
public final class TemplateXRenderEngine {
    
    // MARK: - 单例
    
    public static let shared = TemplateXRenderEngine()
    
    // MARK: - 配置
    
    /// 渲染配置
    public struct Config {
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
        component = templateCache.get(templateName)
        
        // 2. 缓存未命中，加载模板
        if component == nil {
            component = TemplateLoader.shared.loadFromBundle(name: templateName)
            if let c = component {
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
        
        // 0. 预处理 ListComponent：计算 Cell 最大高度，更新 style.height
        preProcessListComponents(component, containerWidth: containerSize.width)
        
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
                createViewTree(component)
            }
        } else {
            rootView = createViewTree(component)
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
        
        // 移除组件缓存
        renderedComponents.removeValue(forKey: viewId)
        renderedData.removeValue(forKey: viewId)
    }
    
    /// 清理所有缓存
    public func clearAllCache() {
        renderedComponents.removeAll()
        renderedData.removeAll()
        templateCache.clear()
    }
    
    // MARK: - 数据绑定
    
    /// 绑定数据到组件树
    private func bindData(_ data: [String: Any], to component: Component) {
        dataBindingManager.bind(data: data, to: component)
    }
    
    // MARK: - ListComponent 预处理
    
    /// 预处理 ListComponent：在 Yoga 布局前计算 Cell 最大高度，更新 style.height
    ///
    /// 解决问题：横向滚动列表的高度需要根据 Cell 内容动态计算，但 Yoga 布局时无法获取 Cell 高度
    /// 方案：在布局前遍历所有 ListComponent，如果开启了 autoAdjustHeight，则预先计算 Cell 最大高度
    /// 预处理 ListComponent：在 Yoga 布局前计算 Cell 最大高度，更新 style.height
    ///
    /// 解决问题：横向滚动列表的高度需要根据 Cell 内容动态计算，但 Yoga 布局时无法获取 Cell 高度
    /// 方案：在布局前遍历所有 ListComponent，如果开启了 autoAdjustHeight，则预先计算 Cell 最大高度
    ///
    /// - Parameters:
    ///   - component: 根组件
    ///   - containerWidth: 容器宽度
    public func preProcessListComponents(_ component: Component, containerWidth: CGFloat) {
        // 使用栈模拟递归
        var stack: [Component] = [component]
        
        TXLogger.debug("[preProcess] START: root=\(component.id), type=\(type(of: component)), children.count=\(component.children.count)")
        
        while let comp = stack.popLast() {
            TXLogger.debug("[preProcess] visiting: id=\(comp.id), type=\(type(of: comp)), children.count=\(comp.children.count)")
            
            // 调试：检查 ListComponent
            if let listComponent = comp as? ListComponent {
                TXLogger.debug("[preProcess] ListComponent: id=\(listComponent.id), autoAdjustHeight=\(listComponent.props.autoAdjustHeight), itemHeight=\(String(describing: listComponent.props.itemHeight)), cellTemplate=\(listComponent.cellTemplate != nil), dataSource.count=\(listComponent.dataSource.count)")
            }
            
            // 检查是否是 ListComponent 且开启了 autoAdjustHeight
            if let listComponent = comp as? ListComponent,
               listComponent.props.autoAdjustHeight,
               listComponent.props.itemHeight == nil,
               let cellTemplate = listComponent.cellTemplate,
               !listComponent.dataSource.isEmpty {
                
                let itemWidth = listComponent.props.itemWidth ?? (containerWidth - listComponent.contentInset.left - listComponent.contentInset.right)
                let templateId = listComponent.cellTemplateId ?? "list_cell_\(listComponent.id)"
                var maxHeight: CGFloat = 0
                
                // 遍历所有数据计算高度，取最大值
                for (index, itemData) in listComponent.dataSource.enumerated() {
                    var context: [String: Any] = ["item": itemData, "index": index]
                    if let dictData = itemData as? [String: Any] {
                        for (key, value) in dictData {
                            context[key] = value
                        }
                    }
                    
                    let height = calculateHeight(
                        json: cellTemplate.rawDictionary,
                        templateId: templateId,
                        data: context,
                        containerWidth: itemWidth,
                        useCache: true
                    )
                    maxHeight = max(maxHeight, height)
                }
                
                // 更新 style.height 和缓存
                if maxHeight > 0 {
                    let insets = listComponent.contentInset
                    let listHeight = maxHeight + insets.top + insets.bottom
                    listComponent.style.height = .point(listHeight)
                    listComponent.cachedMaxItemHeight = maxHeight
                    TXLogger.debug("[RenderEngine] preProcessListComponents: \(listComponent.id) height=\(listHeight), cellMaxHeight=\(maxHeight)")
                }
            }
            
            // 子组件入栈
            stack.append(contentsOf: comp.children)
        }
    }
    
    // MARK: - 布局
    
    /// 应用布局结果到组件树
    ///
    /// - Parameters:
    ///   - results: Yoga 计算的布局结果（相对坐标）
    ///   - component: 目标组件
    private func applyLayoutResults(
        _ results: [String: LayoutResult],
        to component: Component
    ) {
        // 获取 Yoga 计算的相对坐标
        if let result = results[component.id] {
            component.layoutResult = result
        }
        
        // 递归处理子组件
        for child in component.children {
            applyLayoutResults(results, to: child)
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
    
    /// 创建视图树
    ///
    /// - Parameters:
    ///   - component: 组件
    /// - Returns: 创建的视图
    private func createViewTree(_ component: Component) -> UIView {
        // 检查解析错误
        if let baseComponent = component as? BaseComponent, let error = baseComponent.parseError {
            let errorView = Self.createErrorView(for: error, componentType: component.type)
            component.view = errorView
            return errorView
        }
        
        // 创建视图
        let view: UIView
        let createStart = CACurrentMediaTime()
        if let existingView = component.view {
            view = existingView
        } else {
            view = component.createView()
        }
        let createTime = (CACurrentMediaTime() - createStart) * 1000
        viewCreationStats.recordCreate(type: component.type, time: createTime)
        
        // 标记组件 ID
        view.accessibilityIdentifier = component.id
        
        // 递归创建子视图
        for child in component.children {
            let childView = createViewTree(child)
            if childView.superview !== view {
                let addStart = CACurrentMediaTime()
                view.addSubview(childView)
                viewCreationStats.recordAddSubview(time: (CACurrentMediaTime() - addStart) * 1000)
            }
        }
        
        return view
    }
    
    /// 创建错误视图
    /// - Debug: 红色背景 + 错误信息
    /// - Release: 空视图（隐藏）
    private static func createErrorView(for error: Error, componentType: String) -> UIView {
        #if DEBUG
        let container = UIView()
        container.backgroundColor = UIColor.red.withAlphaComponent(0.3)
        container.layer.borderColor = UIColor.red.cgColor
        container.layer.borderWidth = 1
        
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .red
        label.textAlignment = .center
        
        // 提取关键错误信息
        let errorMessage = extractErrorMessage(from: error)
        label.text = "[\(componentType)] Parse Error:\n\(errorMessage)"
        
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        return container
        #else
        // Release 模式：返回隐藏的空视图
        let view = UIView()
        view.isHidden = true
        return view
        #endif
    }
    
    /// 从 DecodingError 提取关键信息
    private static func extractErrorMessage(from error: Error) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, _):
                return "Missing key: \(key.stringValue)"
            case .typeMismatch(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                return "Type mismatch at '\(path)': expected \(type)"
            case .valueNotFound(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                return "Null value at '\(path)': expected \(type)"
            case .dataCorrupted(let context):
                return "Data corrupted: \(context.debugDescription)"
            @unknown default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
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
    
    /// 生成视图标识符
    public func generateViewIdentifier(_ view: UIView) -> String {
        return "\(ObjectIdentifier(view))"
    }
    
    /// 缓存组件（供外部使用，如预加载场景）
    public func cacheComponent(_ component: Component, forViewId viewId: String) {
        renderedComponents[viewId] = component
    }
}

// MARK: - 性能监控 (使用 PerformanceMonitor.swift 中的定义)

// MARK: - 便捷扩展

extension TemplateXRenderEngine {
    
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



// MARK: - 渲染结果

/// 渲染结果，封装视图和组件的引用
public final class RenderResult {
    
    public let view: UIView
    public let component: Component
    private weak var engine: TemplateXRenderEngine?
    
    init(view: UIView, component: Component, engine: TemplateXRenderEngine) {
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

extension TemplateXRenderEngine {
    
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

extension TemplateXRenderEngine {
    
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
                TXLogger.error("[RenderEngine] renderWithCache FAILED: parse returned nil, templateId=\(templateId), json.keys=\(json.keys)")
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
        
        // 3.5 预处理 ListComponent（计算 autoAdjustHeight 列表的高度）
        preProcessListComponents(component, containerWidth: containerWidth)
        
        // 4. 计算布局（使用 NaN 高度让 Yoga 自动计算）
        let containerSize = CGSize(width: containerWidth, height: .nan)
        let layoutResults = layoutEngine.calculateLayout(for: component, containerSize: containerSize)
        
        // 5. 获取根组件高度（包含 margin）
        let frameHeight = layoutResults[component.id]?.frame.height ?? 0
        let marginTop = component.style.margin.top
        let marginBottom = component.style.margin.bottom
        let height = frameHeight + marginTop + marginBottom
        
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

// MARK: - Pipeline 渲染 API

extension TemplateXRenderEngine {
    
    /// 创建渲染管道
    /// 
    /// 用于需要 SyncFlush 机制的场景，如 TemplateXView
    /// 
    /// - Returns: 新的 RenderPipeline 实例
    func createPipeline() -> RenderPipeline {
        return RenderPipelinePool.shared.acquire()
    }
    
    /// 归还渲染管道到池中
    /// 
    /// - Parameter pipeline: 要归还的管道
    func releasePipeline(_ pipeline: RenderPipeline) {
        RenderPipelinePool.shared.release(pipeline)
    }
    
    /// 使用管道渲染（同步，支持 SyncFlush）
    /// 
    /// 这是一个便捷方法，内部创建管道、启动渲染、等待完成
    /// 
    /// 流程：
    /// 1. 后台执行 parse + bind + layout
    /// 2. 生成 UI 操作入队
    /// 3. SyncFlush 等待后台完成并执行 UI 操作
    /// 
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    ///   - timeoutMs: SyncFlush 超时时间（毫秒）
    /// - Returns: 渲染的视图
    public func renderWithPipeline(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize,
        timeoutMs: Int = 100
    ) -> UIView? {
        let pipeline = createPipeline()
        pipeline.config.syncFlushTimeoutMs = timeoutMs
        pipeline.config.enablePerformanceMonitor = config.enablePerformanceMonitor
        
        // 启动渲染
        pipeline.start(json: json, data: data, containerSize: containerSize)
        
        // SyncFlush 等待并执行
        let view = pipeline.syncFlush()
        
        // 缓存组件
        if let view = view, let component = pipeline.rootComponent {
            let viewId = generateViewIdentifier(view)
            renderedComponents[viewId] = component
        }
        
        // 归还管道
        releasePipeline(pipeline)
        
        return view
    }
    
    /// 使用管道渲染（使用缓存的模板原型）
    /// 
    /// 适用于 Cell 场景，结合模板原型缓存和 SyncFlush 机制
    /// 
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - templateId: 模板标识符（缓存 key）
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    ///   - timeoutMs: SyncFlush 超时时间（毫秒）
    /// - Returns: 渲染的视图
    public func renderWithPipelineCache(
        json: [String: Any],
        templateId: String,
        data: [String: Any]? = nil,
        containerSize: CGSize,
        timeoutMs: Int = 100
    ) -> UIView? {
        // 获取或创建模板原型
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
        
        let pipeline = createPipeline()
        pipeline.config.syncFlushTimeoutMs = timeoutMs
        pipeline.config.enablePerformanceMonitor = config.enablePerformanceMonitor
        
        // 使用原型启动渲染
        pipeline.startWithPrototype(prototype: prototype, data: data, containerSize: containerSize)
        
        // SyncFlush 等待并执行
        let view = pipeline.syncFlush()
        
        // 缓存组件
        if let view = view, let component = pipeline.rootComponent {
            let viewId = generateViewIdentifier(view)
            renderedComponents[viewId] = component
        }
        
        // 归还管道
        releasePipeline(pipeline)
        
        return view
    }
}
