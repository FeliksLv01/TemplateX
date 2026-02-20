import UIKit

// MARK: - TemplateXView

/// TemplateX 视图容器
/// 
/// 类似 Lynx 的 LynxView，支持：
/// - 异步加载模板
/// - SyncFlush 避免白屏
/// - 自动布局更新
/// - Builder 模式配置
/// - 布局尺寸模式
/// 
/// 使用示例：
/// ```swift
/// // 方式1: Builder 模式（推荐）
/// let templateView = TemplateXView { builder in
///     builder.config = TemplateXConfig { config in
///         config.enablePerformanceMonitor = true
///     }
///     builder.screenSize = view.bounds.size
///     builder.fontScale = 1.0
/// }
/// 
/// templateView.preferredLayoutWidth = 375
/// templateView.preferredLayoutHeight = .nan
/// templateView.layoutWidthMode = .exact
/// templateView.layoutHeightMode = .atMost
/// 
/// view.addSubview(templateView)
/// templateView.loadTemplate(url: "home_card", data: data)
/// 
/// // 方式2: 传统方式
/// let templateView = TemplateXView()
/// templateView.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
/// view.addSubview(templateView)
/// templateView.loadTemplate(json: template, data: data)
/// ```
public class TemplateXView: UIView {
    
    // MARK: - 布局属性（参考 Lynx）
    
    /// 宽度布局模式
    public var layoutWidthMode: TemplateXViewSizeMode = .exact
    
    /// 高度布局模式
    public var layoutHeightMode: TemplateXViewSizeMode = .atMost
    
    /// 首选布局宽度
    public var preferredLayoutWidth: CGFloat = UIScreen.main.bounds.width
    
    /// 首选布局高度
    public var preferredLayoutHeight: CGFloat = CGFloat.nan
    
    /// 最大布局宽度（layoutWidthMode = .atMost 时生效）
    public var preferredMaxLayoutWidth: CGFloat = UIScreen.main.bounds.width
    
    /// 最大布局高度（layoutHeightMode = .atMost 时生效）
    public var preferredMaxLayoutHeight: CGFloat = CGFloat.nan
    
    // MARK: - 配置
    
    /// 配置对象
    public var config: TemplateXConfig? {
        didSet {
            applyConfig()
        }
    }
    
    /// 屏幕尺寸（用于 rpx 计算）
    public var screenSize: CGSize = UIScreen.main.bounds.size
    
    /// 字体缩放比例
    public var fontScale: CGFloat = 1.0
    
    /// 是否启用 SyncFlush（默认 true）
    /// 
    /// 启用时：在 layoutSubviews 中等待后台线程完成再渲染
    /// 禁用时：后台完成后回调主线程渲染（可能有短暂白屏）
    public var enableSyncFlush: Bool = true
    
    /// 是否启用自动布局更新（默认 true）
    /// 
    /// 启用时：frame 变化会触发重新布局
    public var enableAutoLayout: Bool = true
    
    /// SyncFlush 超时时间（毫秒）
    public var syncFlushTimeoutMs: Int = 100 {
        didSet {
            operationQueue.timeoutMs = syncFlushTimeoutMs
        }
    }
    
    // MARK: - Providers
    
    /// 模板提供者（如果为 nil，使用 TemplateXEnv.shared.templateProvider）
    public var templateProvider: TemplateXTemplateProvider?
    
    /// 图片加载器（如果为 nil，使用 TemplateXEnv.shared.imageLoader）
    public var imageLoader: TemplateXImageLoader?
    
    // MARK: - 状态
    
    /// 加载状态
    public enum LoadState {
        case idle           // 空闲
        case loading        // 加载中
        case loaded         // 加载完成
        case error(Error)   // 加载失败
    }
    
    /// 当前加载状态
    public private(set) var loadState: LoadState = .idle
    
    /// 当前渲染的组件树
    public private(set) var rootComponent: Component?
    
    /// 当前渲染的内容视图
    public private(set) var contentView: UIView?
    
    /// 当前模板 URL
    private var templateURL: String?
    
    /// 当前模板 JSON
    private var templateJSON: [String: Any]?
    
    /// 当前绑定数据
    private var templateData: [String: Any]?
    
    /// 模板 ID（用于缓存）
    private var templateId: String?
    
    // MARK: - 内部组件
    
    /// UI 操作队列
    private let operationQueue = UIOperationQueue()
    
    /// 渲染引擎
    private let renderEngine = TemplateXRenderEngine.shared
    
    /// 后台队列
    private let backgroundQueue = DispatchQueue(
        label: "com.templatex.view.background",
        qos: .userInitiated
    )
    
    /// 是否需要在 layoutSubviews 时 flush
    private var needsFlushOnLayout = false
    
    /// 上次的 bounds
    private var lastBounds: CGRect = .zero
    
    /// 是否已完成首次布局
    private var isLayoutFinished = false
    
    // MARK: - 回调
    
    /// 加载完成回调
    public var onLoadComplete: ((UIView?) -> Void)?
    
    /// 加载失败回调
    public var onLoadError: ((Error) -> Void)?
    
    /// 布局完成回调
    public var onLayoutComplete: ((CGSize) -> Void)?
    
    /// 内容尺寸变化回调（用于自适应高度场景）
    public var onContentSizeChanged: ((CGSize) -> Void)?
    
    // MARK: - Init
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    /// Builder 模式初始化
    ///
    /// 使用示例：
    /// ```swift
    /// let templateView = TemplateXView { builder in
    ///     builder.config = TemplateXConfig { config in
    ///         config.enablePerformanceMonitor = true
    ///     }
    ///     builder.screenSize = view.bounds.size
    ///     builder.fontScale = 1.0
    /// }
    /// ```
    public convenience init(builder: TemplateXViewBuilderBlock) {
        let viewBuilder = TemplateXViewBuilder()
        builder(viewBuilder)
        self.init(frame: viewBuilder.frame)
        applyBuilder(viewBuilder)
    }
    
    private func setup() {
        clipsToBounds = true
        operationQueue.timeoutMs = syncFlushTimeoutMs
    }
    
    /// 应用 Builder 配置
    private func applyBuilder(_ builder: TemplateXViewBuilder) {
        self.config = builder.config
        self.screenSize = builder.screenSize
        self.fontScale = builder.fontScale
        self.templateProvider = builder.templateProvider
        self.imageLoader = builder.imageLoader
        self.enableAutoLayout = builder.enableAutoLayout
        self.enableSyncFlush = builder.enableSyncFlush
        self.syncFlushTimeoutMs = builder.syncFlushTimeoutMs
    }
    
    /// 应用配置
    private func applyConfig() {
        guard let config = config else { return }
        enableSyncFlush = config.enableSyncFlush
        syncFlushTimeoutMs = config.syncFlushTimeoutMs
    }
    
    // MARK: - 加载模板（URL）
    
    /// 通过 URL 加载模板
    ///
    /// - Parameters:
    ///   - url: 模板 URL（通过 templateProvider 加载）
    ///   - data: 绑定数据
    public func loadTemplate(url: String, data: [String: Any]? = nil) {
        self.templateURL = url
        self.templateData = data
        self.templateId = url
        
        loadState = .loading
        
        // 获取 provider
        let provider = templateProvider ?? TemplateXEnv.shared.templateProvider
        
        if let provider = provider {
            // 使用 provider 加载
            provider.loadTemplate(url: url) { [weak self] result in
                switch result {
                case .success(let json):
                    self?.loadTemplate(json: json, data: data, templateId: url)
                case .failure(let error):
                    self?.loadState = .error(error)
                    self?.onLoadError?(error)
                }
            }
        } else {
            // 尝试从 Bundle 加载
            if let json = BundleTemplateProvider().loadTemplateSync(url: url) {
                loadTemplate(json: json, data: data, templateId: url)
            } else {
                let error = TemplateXProviderError.templateNotFound(url)
                loadState = .error(error)
                onLoadError?(error)
            }
        }
    }
    
    // MARK: - 加载模板（JSON）
    
    /// 加载模板（异步）
    /// 
    /// 流程：
    /// 1. 后台线程执行 parse → bind → layout
    /// 2. 生成 UI 操作入队
    /// 3. layoutSubviews 时 SyncFlush 执行 UI 操作
    /// 
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - data: 绑定数据
    ///   - templateId: 模板 ID（可选，用于缓存）
    public func loadTemplate(
        json: [String: Any],
        data: [String: Any]? = nil,
        templateId: String? = nil
    ) {
        // 保存参数
        self.templateJSON = json
        self.templateData = data
        self.templateId = templateId
        
        // 更新状态
        loadState = .loading
        operationQueue.markPreparing()
        needsFlushOnLayout = true
        
        // 在主线程捕获容器尺寸，避免后台线程 sync 回主线程造成死锁
        let containerSize = effectiveContainerSize
        
        // 后台执行渲染准备
        backgroundQueue.async { [weak self] in
            self?.prepareRenderInBackground(containerSize: containerSize)
        }
        
        // 触发 layoutSubviews
        setNeedsLayout()
    }
    
    /// 更新数据（增量更新）
    /// 
    /// - Parameter data: 新数据
    public func updateData(_ data: [String: Any]) {
        self.templateData = data
        
        guard let rootComponent = rootComponent, let contentView = contentView else {
            // 还没有渲染过，重新加载
            if let json = templateJSON {
                loadTemplate(json: json, data: data, templateId: templateId)
            }
            return
        }
        
        // 使用简化的增量更新流程（不使用扁平化）
        // 注意：TemplateXView 首次渲染时为每个组件都创建了 UIView，不使用扁平化，
        // 所以增量更新时也不能使用 DiffPatcher.apply()（它会应用扁平化偏移逻辑）
        let containerSize = effectiveContainerSize
        
        // 1. 克隆组件树并绑定新数据
        let newComponent = cloneComponentTree(rootComponent)
        DataBindingManager.shared.bind(data: data, to: newComponent)
        
        // 2. 计算 Diff
        let diffResult = ViewDiffer.shared.diff(oldTree: rootComponent, newTree: newComponent)
        
        // 3. 如果有变化，应用 Diff
        if diffResult.hasDiff {
            applyDiff(diffResult, to: rootComponent, containerSize: containerSize)
        }
    }
    
    /// 应用 Diff 结果
    private func applyDiff(
        _ diffResult: DiffResult,
        to rootComponent: Component,
        containerSize: CGSize
    ) {
        // 1. 应用属性变化（从新组件复制到旧组件）
        for operation in diffResult.operations {
            if case .update(let componentId, let newComponent, let changes) = operation {
                applyUpdateOperation(componentId: componentId, newComponent: newComponent, changes: changes, in: rootComponent)
            }
            // 注意：insert/delete/move/replace 操作涉及视图层级变化，
            // 目前 TemplateXView 的场景主要是数据绑定更新，暂不处理这些操作
        }
        
        // 2. 重新计算布局
        let layoutResults = YogaLayoutEngine.shared.calculateLayout(for: rootComponent, containerSize: containerSize)
        
        // 3. 应用布局结果（不使用扁平化偏移）
        applyLayoutResults(layoutResults, to: rootComponent)
        
        // 4. 更新视图 frame 和属性
        updateViewFrames(rootComponent)
        updateViewProperties(rootComponent)
    }
    
    /// 应用更新操作
    private func applyUpdateOperation(
        componentId: String,
        newComponent: Component,
        changes: PropertyChanges,
        in rootComponent: Component
    ) {
        // 查找目标组件
        guard let component = findComponentById(componentId, in: rootComponent) else { return }
        
        // 应用样式变化
        if let styleChanges = changes.styleChanges {
            component.style = component.style.merging(styleChanges)
        }
        
        // 应用绑定变化
        if let bindingChanges = changes.bindingChanges {
            for (key, value) in bindingChanges {
                if key == "__componentNeedsUpdate" { continue }
                component.bindings[key] = value
            }
        }
        
        // 复制组件特有属性
        copyComponentSpecificProperties(from: newComponent, to: component)
    }
    
    /// 根据 ID 查找组件
    private func findComponentById(_ id: String, in component: Component) -> Component? {
        if component.id == id { return component }
        for child in component.children {
            if let found = findComponentById(id, in: child) {
                return found
            }
        }
        return nil
    }
    
    /// 复制组件特有属性
    private func copyComponentSpecificProperties(from source: Component, to target: Component) {
        // TextComponent
        if let sourceText = source as? TextComponent,
           let targetText = target as? TextComponent {
            targetText.text = sourceText.text
            targetText.fontSize = sourceText.fontSize
            targetText.fontWeight = sourceText.fontWeight
            targetText.textColor = sourceText.textColor
            targetText.textAlignment = sourceText.textAlignment
            targetText.numberOfLines = sourceText.numberOfLines
            targetText.lineBreakMode = sourceText.lineBreakMode
            targetText.lineHeight = sourceText.lineHeight
            targetText.letterSpacing = sourceText.letterSpacing
            return
        }
        
        // ImageComponent
        if let sourceImage = source as? ImageComponent,
           let targetImage = target as? ImageComponent {
            targetImage.src = sourceImage.src
            targetImage.scaleType = sourceImage.scaleType
            targetImage.placeholder = sourceImage.placeholder
            targetImage.tintColor = sourceImage.tintColor
            return
        }
        
        // ButtonComponent
        if let sourceButton = source as? ButtonComponent,
           let targetButton = target as? ButtonComponent {
            targetButton.title = sourceButton.title
            targetButton.isDisabled = sourceButton.isDisabled
            targetButton.iconLeft = sourceButton.iconLeft
            targetButton.iconRight = sourceButton.iconRight
            return
        }
        
        // InputComponent
        if let sourceInput = source as? InputComponent,
           let targetInput = target as? InputComponent {
            targetInput.text = sourceInput.text
            targetInput.placeholder = sourceInput.placeholder
            targetInput.inputType = sourceInput.inputType
            targetInput.isDisabled = sourceInput.isDisabled
            targetInput.isReadOnly = sourceInput.isReadOnly
            return
        }
    }
    
    /// 更新视图属性
    private func updateViewProperties(_ component: Component) {
        component.updateView()
        for child in component.children {
            updateViewProperties(child)
        }
    }
    
    /// 深度克隆组件树
    private func cloneComponentTree(_ component: Component) -> Component {
        let cloned = component.clone()
        for child in component.children {
            let clonedChild = cloneComponentTree(child)
            clonedChild.parent = cloned
            cloned.children.append(clonedChild)
        }
        return cloned
    }
    
    /// 重新加载
    public func reload() {
        if let url = templateURL {
            loadTemplate(url: url, data: templateData)
        } else if let json = templateJSON {
            loadTemplate(json: json, data: templateData, templateId: templateId)
        }
    }
    
    // MARK: - 布局尺寸计算
    
    /// 计算有效的容器尺寸
    private var effectiveContainerSize: CGSize {
        var width: CGFloat
        var height: CGFloat
        
        switch layoutWidthMode {
        case .exact:
            width = preferredLayoutWidth.isNaN ? bounds.width : preferredLayoutWidth
        case .atMost:
            width = preferredMaxLayoutWidth.isNaN ? bounds.width : preferredMaxLayoutWidth
        case .wrapContent:
            width = CGFloat.nan
        }
        
        switch layoutHeightMode {
        case .exact:
            height = preferredLayoutHeight.isNaN ? bounds.height : preferredLayoutHeight
        case .atMost:
            height = preferredMaxLayoutHeight.isNaN ? bounds.height : preferredMaxLayoutHeight
        case .wrapContent:
            height = CGFloat.nan
        }
        
        return CGSize(width: width, height: height)
    }
    
    /// intrinsicContentSize 支持（用于 Auto Layout）
    public override var intrinsicContentSize: CGSize {
        guard let component = rootComponent else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        
        let frame = component.layoutResult.frame
        return CGSize(
            width: layoutWidthMode == .wrapContent ? frame.width : UIView.noIntrinsicMetric,
            height: layoutHeightMode == .wrapContent || layoutHeightMode == .atMost ? frame.height : UIView.noIntrinsicMetric
        )
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // 检查是否需要 SyncFlush
        if enableSyncFlush && needsFlushOnLayout {
            syncFlush()
        }
        
        // 检查 bounds 变化
        if enableAutoLayout && bounds != lastBounds && contentView != nil {
            lastBounds = bounds
            relayout()
        }
    }
    
    /// 同步刷新
    public func syncFlush() {
        needsFlushOnLayout = false
        operationQueue.syncFlush()
    }
    
    /// 触发重新布局
    public func triggerLayout() {
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    /// 重新布局
    private func relayout() {
        guard let component = rootComponent, let _ = contentView else { return }
        
        // 重新计算布局
        let layoutResults = YogaLayoutEngine.shared.calculateLayout(
            for: component,
            containerSize: effectiveContainerSize
        )
        
        // 应用布局
        applyLayoutResults(layoutResults, to: component)
        
        // 更新视图 frame
        updateViewFrames(component)
        
        // 检查内容尺寸变化
        let newContentSize = component.layoutResult.frame.size
        onContentSizeChanged?(newContentSize)
        
        // 更新 intrinsicContentSize
        if layoutWidthMode == .wrapContent || layoutHeightMode == .wrapContent || layoutHeightMode == .atMost {
            invalidateIntrinsicContentSize()
        }
        
        isLayoutFinished = true
        onLayoutComplete?(bounds.size)
    }
    
    // MARK: - 后台渲染
    
    /// 后台准备渲染（parse + bind + layout）
    /// - Parameter containerSize: 容器尺寸（在主线程捕获）
    private func prepareRenderInBackground(containerSize: CGSize) {
        guard let json = templateJSON else {
            operationQueue.markError(TemplateXViewError.noTemplate)
            return
        }
        
        do {
            // 1. 解析模板
            guard let component = TemplateParser.shared.parse(json: json) else {
                throw TemplateXViewError.parseFailed
            }
            
            // 2. 绑定数据
            if let data = templateData {
                DataBindingManager.shared.bind(data: data, to: component)
            }
            
            // 3. 计算布局（使用传入的 containerSize，避免死锁）
            let layoutResults = YogaLayoutEngine.shared.calculateLayout(
                for: component,
                containerSize: containerSize
            )
            
            // 4. 应用布局结果到组件
            applyLayoutResults(layoutResults, to: component)
            
            // 5. 生成 UI 操作并入队
            generateUIOperations(for: component, isRoot: true)
            
            // 6. 保存组件树
            DispatchQueue.main.async { [weak self] in
                self?.rootComponent = component
            }
            
            // 7. 标记完成
            operationQueue.markReady()
            
        } catch {
            operationQueue.markError(error)
            DispatchQueue.main.async { [weak self] in
                self?.loadState = .error(error)
                self?.onLoadError?(error)
            }
        }
    }
    
    /// 生成 UI 操作
    private func generateUIOperations(for component: Component, isRoot: Bool) {
        // 创建视图操作
        operationQueue.enqueue { [weak self] in
            guard let self = self else { return }
            
            // 创建视图
            let view = component.createView()
            component.view = view
            
            // 设置 frame
            view.frame = component.layoutResult.frame
            
            // 如果是根组件，添加到容器
            if isRoot {
                // 移除旧的内容视图
                self.contentView?.removeFromSuperview()
                
                // 添加新视图
                self.addSubview(view)
                self.contentView = view
                
                // 更新状态
                self.loadState = .loaded
                self.isLayoutFinished = true
                self.onLoadComplete?(view)
                
                // 通知内容尺寸
                self.onContentSizeChanged?(component.layoutResult.frame.size)
                
                // 更新 intrinsicContentSize
                self.invalidateIntrinsicContentSize()
            }
            
            // 更新视图属性
            component.updateView()
        }
        
        // 递归处理子组件
        for child in component.children {
            generateUIOperations(for: child, isRoot: false)
            
            // 添加子视图操作
            operationQueue.enqueue {
                guard let parentView = component.view, let childView = child.view else { return }
                parentView.addSubview(childView)
            }
        }
    }
    
    /// 应用布局结果（简单版本，不处理扁平化）
    /// 
    /// 因为 TemplateXView 使用 generateUIOperations 创建视图，每个组件都有独立的 UIView，
    /// 不使用扁平化优化，所以 frame 保持 Yoga 返回的相对坐标即可。
    private func applyLayoutResults(_ results: [String: LayoutResult], to component: Component) {
        if let result = results[component.id] {
            component.layoutResult = result
        }
        
        for child in component.children {
            applyLayoutResults(results, to: child)
        }
    }
    
    /// 更新视图 frame
    private func updateViewFrames(_ component: Component) {
        component.view?.frame = component.layoutResult.frame
        for child in component.children {
            updateViewFrames(child)
        }
    }
    
    // MARK: - 查找视图
    
    /// 根据 name 查找视图
    public func findView(withName name: String) -> UIView? {
        return findComponent(withName: name, in: rootComponent)?.view
    }
    
    /// 根据 name 查找组件
    private func findComponent(withName name: String, in component: Component?) -> Component? {
        guard let component = component else { return nil }
        
        if component.id == name {
            return component
        }
        
        for child in component.children {
            if let found = findComponent(withName: name, in: child) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - 信息获取
    
    /// 是否已完成布局
    public var isLayoutComplete: Bool {
        return isLayoutFinished
    }
    
    /// 根视图宽度
    public var rootWidth: CGFloat {
        return rootComponent?.layoutResult.frame.width ?? 0
    }
    
    /// 根视图高度
    public var rootHeight: CGFloat {
        return rootComponent?.layoutResult.frame.height ?? 0
    }
    
    // MARK: - 清理
    
    /// 清理视图
    public func clear() {
        contentView?.removeFromSuperview()
        contentView = nil
        rootComponent = nil
        templateURL = nil
        templateJSON = nil
        templateData = nil
        templateId = nil
        loadState = .idle
        isLayoutFinished = false
        operationQueue.reset()
    }
    
    /// 重置视图和 layer
    public func resetViewAndLayer() {
        clear()
    }
    
    deinit {
        clear()
    }
}

// MARK: - 错误类型

/// TemplateXView 错误
public enum TemplateXViewError: Error, LocalizedError {
    case noTemplate
    case parseFailed
    case layoutFailed
    
    public var errorDescription: String? {
        switch self {
        case .noTemplate:
            return "No template JSON provided"
        case .parseFailed:
            return "Failed to parse template"
        case .layoutFailed:
            return "Failed to calculate layout"
        }
    }
}

// MARK: - 便捷初始化

extension TemplateXView {
    
    /// 便捷初始化（直接加载模板 JSON）
    public convenience init(
        json: [String: Any],
        data: [String: Any]? = nil,
        frame: CGRect = .zero
    ) {
        self.init(frame: frame)
        loadTemplate(json: json, data: data)
    }
    
    /// 便捷初始化（通过 URL 加载模板）
    public convenience init(
        url: String,
        data: [String: Any]? = nil,
        frame: CGRect = .zero
    ) {
        self.init(frame: frame)
        loadTemplate(url: url, data: data)
    }
}

// MARK: - 生命周期

extension TemplateXView: TemplateXLifecycleListener {
    
    public func onEnterForeground() {
        // 恢复动画等
    }
    
    public func onEnterBackground() {
        // 暂停动画等
    }
}
