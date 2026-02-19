import UIKit

// MARK: - TemplateX 主入口

/// TemplateX - 高性能动态模板渲染引擎
///
/// 使用示例:
/// ```swift
/// // 从 Bundle 加载模板并渲染
/// let view = TemplateX.render("home_card", data: ["title": "Hello"])
/// containerView.addSubview(view)
///
/// // 从 JSON 字符串渲染
/// let json = """
/// {
///   "type": "container",
///   "props": { "width": -1, "height": 100, "backgroundColor": "#FF0000" }
/// }
/// """
/// let view = TemplateX.render(json: json)
/// ```
public enum TemplateX {
    
    // MARK: - 渲染模式配置
    
    /// 是否使用 Pipeline 渲染（默认开启）
    /// 
    /// Pipeline 渲染借鉴 Lynx 架构，后台执行 parse + bind + layout，
    /// 然后 SyncFlush 批量执行 UI 操作，可减少页面跳转白屏时间
    public static var usePipelineRendering: Bool = true
    
    // MARK: - 渲染 API
    
    /// 从模板名称渲染视图
    /// - Parameters:
    ///   - templateName: 模板名称（Bundle 中的 JSON 文件）
    ///   - data: 绑定数据
    ///   - size: 容器尺寸，默认为屏幕宽度
    /// - Returns: 渲染后的 UIView
    public static func render(
        _ templateName: String,
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        // 先加载模板 JSON
        guard let json = TemplateLoader.shared.loadJSONFromBundle(name: templateName) else {
            TXLogger.error("Failed to load template: \(templateName)")
            return nil
        }
        return render(json: json, data: data, size: size)
    }
    
    /// 从 JSON 字典渲染视图
    public static func render(
        json: [String: Any],
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        if usePipelineRendering {
            return TemplateXRenderEngine.shared.renderWithPipeline(
                json: json,
                data: data,
                containerSize: size
            )
        } else {
            return TemplateXRenderEngine.shared.render(
                json: json,
                data: data,
                containerSize: size
            )
        }
    }
    
    /// 从 JSON 字符串渲染视图
    public static func render(
        json jsonString: String,
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            TXLogger.error("Failed to parse JSON string")
            return nil
        }
        return render(json: json, data: data, size: size)
    }
    
    // MARK: - 传统渲染 API（不使用 Pipeline）
    
    /// 使用传统方式渲染（同步，不使用 Pipeline）
    public static func renderSync(
        json: [String: Any],
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        return TemplateXRenderEngine.shared.render(
            json: json,
            data: data,
            containerSize: size
        )
    }
    
    // MARK: - 配置
    
    /// 引擎配置
    public static var config: TemplateXRenderEngine.Config {
        get { TemplateXRenderEngine.shared.config }
        set { TemplateXRenderEngine.shared.config = newValue }
    }
    
    /// 启用性能监控
    public static func enablePerformanceMonitor(_ enabled: Bool = true) {
        config.enablePerformanceMonitor = enabled
    }
    
    // MARK: - 组件注册
    
    /// 注册自定义组件
    public static func register(_ factory: ComponentFactory.Type) {
        ComponentRegistry.shared.register(factory)
    }
    
    // MARK: - 缓存管理
    
    /// 清除模板缓存
    public static func clearTemplateCache() {
        TemplateCache.shared.clear()
    }
    
    /// 清除图片缓存
    public static func clearImageCache() {
        if ServiceRegistry.shared.hasImageLoader {
            ServiceRegistry.shared.imageLoader.clearCache(type: .all)
        }
    }
    
    /// 清除所有缓存
    public static func clearAllCache() {
        clearTemplateCache()
        clearImageCache()
    }
    
    // MARK: - 预热
    
    /// 预热配置
    public struct WarmUpOptions {
        /// 是否预热视图池（UITextField/UITextView 等重型视图）
        /// 默认开启，可以消除首次渲染 Input 组件的延迟
        public var warmUpViews: Bool = true
        
        /// 视图预热配置
        public var viewWarmUpConfig: ViewRecyclePool.WarmUpConfig = .default
        
        /// Yoga 节点池预热数量
        public var yogaNodeCount: Int = 64
        
        public init() {}
        
        /// 默认配置
        public static var `default`: WarmUpOptions { WarmUpOptions() }
        
        /// 最小配置（不预热视图）
        public static var minimal: WarmUpOptions {
            var options = WarmUpOptions()
            options.warmUpViews = false
            options.yogaNodeCount = 32
            return options
        }
    }
    
    /// 预热引擎（建议在 App 启动时调用）
    /// 
    /// 预热内容：
    /// 1. ComponentRegistry 初始化（加载所有组件类元数据）
    /// 2. Yoga 节点池预分配
    /// 3. TemplateParser 单例初始化
    /// 4. 视图池预热（UITextField/UITextView 等重型视图）
    ///
    /// 使用示例：
    /// ```swift
    /// func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) {
    ///     // 方式1: 异步预热（推荐）
    ///     DispatchQueue.global(qos: .userInitiated).async {
    ///         TemplateX.warmUp()
    ///     }
    ///     
    ///     // 方式2: 带配置的预热
    ///     TemplateX.warmUp(options: .minimal)
    /// }
    /// ```
    ///
    /// - Note: 视图预热部分会自动切换到主线程执行
    public static func warmUp(options: WarmUpOptions = .default) {
        let start = CACurrentMediaTime()
        
        // 1. 触发 ComponentRegistry 单例初始化（加载所有组件类）
        _ = ComponentRegistry.shared
        
        // 2. 触发 TemplateParser 单例初始化
        _ = TemplateParser.shared
        
        // 3. 预热 Yoga 节点池
        YogaLayoutEngine.shared.warmUp(nodeCount: options.yogaNodeCount)
        
        // 4. 触发 TemplateXRenderEngine 单例初始化
        _ = TemplateXRenderEngine.shared
        
        let coreElapsed = (CACurrentMediaTime() - start) * 1000
        
        // 5. 视图预热（必须在主线程）
        if options.warmUpViews {
            let viewWarmUp = {
                let viewStart = CACurrentMediaTime()
                ViewRecyclePool.shared.warmUp(config: options.viewWarmUpConfig)
                let viewElapsed = (CACurrentMediaTime() - viewStart) * 1000
                let totalElapsed = (CACurrentMediaTime() - start) * 1000
                TXLogger.info("TemplateX.warmUp completed in \(String(format: "%.2f", totalElapsed))ms (core=\(String(format: "%.2f", coreElapsed))ms, views=\(String(format: "%.2f", viewElapsed))ms)")
            }
            
            if Thread.isMainThread {
                viewWarmUp()
            } else {
                DispatchQueue.main.async {
                    viewWarmUp()
                }
            }
        } else {
            TXLogger.info("TemplateX.warmUp completed in \(String(format: "%.2f", coreElapsed))ms (views skipped)")
        }
    }
    
    /// 简化版预热（无配置）
    public static func warmUp() {
        warmUp(options: .default)
    }
    
    /// 预加载模板
    public static func preload(_ templateName: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let component = TemplateLoader.shared.loadFromBundle(name: templateName) {
                TemplateCache.shared.set(templateName, component: component)
            }
        }
    }
    
    // MARK: - Pipeline 渲染 API（借鉴 Lynx 架构）
    
    /// 使用 Pipeline 渲染（后台执行 parse + bind + layout，SyncFlush 同步等待）
    ///
    /// 适用场景：
    /// - 页面跳转时需要快速渲染，避免白屏
    /// - 卡片/组件嵌入场景
    ///
    /// 原理：
    /// 1. 后台线程执行 parse + bind + layout
    /// 2. UI 操作入队（不立即执行）
    /// 3. 调用方可在合适时机（如 layoutSubviews）调用 syncFlush 等待完成并执行 UI 操作
    ///
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - data: 绑定数据
    ///   - size: 容器尺寸
    /// - Returns: 渲染后的 UIView
    public static func renderWithPipeline(
        json: [String: Any],
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        return TemplateXRenderEngine.shared.renderWithPipeline(
            json: json,
            data: data,
            containerSize: size
        )
    }
    
    /// 使用 Pipeline + 模板缓存渲染
    ///
    /// 结合模板原型缓存和 Pipeline 渲染，适用于 Cell 场景
    ///
    /// - Parameters:
    ///   - json: 模板 JSON
    ///   - templateId: 模板标识符（缓存 key）
    ///   - data: 绑定数据
    ///   - size: 容器尺寸
    /// - Returns: 渲染后的 UIView
    public static func renderWithPipelineCache(
        json: [String: Any],
        templateId: String,
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        return TemplateXRenderEngine.shared.renderWithPipelineCache(
            json: json,
            templateId: templateId,
            data: data,
            containerSize: size
        )
    }
    
    // MARK: - TemplateXView 工厂方法
    
    /// 创建 TemplateXView（支持 SyncFlush 的视图容器）
    ///
    /// TemplateXView 类似 Lynx 的 LynxView，在 layoutSubviews 时自动调用 syncFlush
    /// 确保在首次布局时模板已渲染完成
    ///
    /// 使用示例：
    /// ```swift
    /// let templateView = TemplateX.createView(frame: bounds)
    /// templateView.loadTemplate(json: template, data: data)
    /// view.addSubview(templateView)
    /// ```
    ///
    /// - Parameters:
    ///   - frame: 视图 frame
    ///   - enableSyncFlush: 是否启用 SyncFlush（默认 true）
    /// - Returns: TemplateXView 实例
    public static func createView(
        frame: CGRect = .zero,
        enableSyncFlush: Bool = true
    ) -> TemplateXView {
        let view = TemplateXView(frame: frame)
        view.enableSyncFlush = enableSyncFlush
        return view
    }
    
    // MARK: - Pipeline 管理
    
    /// 创建渲染管道（适用于需要精细控制的场景）
    ///
    /// 使用示例：
    /// ```swift
    /// let pipeline = TemplateX.createPipeline()
    /// pipeline.start(json: template, data: data, containerSize: size)
    /// // ... 做其他事情 ...
    /// pipeline.syncFlush()  // 等待完成并执行 UI 操作
    /// let rootView = pipeline.rootView
    /// TemplateX.releasePipeline(pipeline)
    /// ```
    static func createPipeline() -> RenderPipeline {
        return TemplateXRenderEngine.shared.createPipeline()
    }
    
    /// 释放渲染管道（放回池中复用）
    static func releasePipeline(_ pipeline: RenderPipeline) {
        TemplateXRenderEngine.shared.releasePipeline(pipeline)
    }
    
    // MARK: - Pipeline 配置
    
    /// 默认的 Pipeline 配置
    /// 
    /// 修改此配置会影响后续创建的所有 Pipeline
    static var defaultPipelineConfig: RenderPipeline.Config {
        get { RenderPipelinePool.shared.defaultConfig }
        set { RenderPipelinePool.shared.defaultConfig = newValue }
    }
    
    /// 全局 SyncFlush 超时时间（毫秒）
    /// 
    /// 这是 `defaultPipelineConfig.syncFlushTimeoutMs` 的便捷访问
    public static var syncFlushTimeoutMs: Int {
        get { defaultPipelineConfig.syncFlushTimeoutMs }
        set { 
            var config = defaultPipelineConfig
            config.syncFlushTimeoutMs = newValue
            defaultPipelineConfig = config
        }
    }
}

// MARK: - Service 注册

extension TemplateX {
    
    /// 注册图片加载器
    ///
    /// **必须在 App 启动时调用**，否则首次加载图片时会触发 fatalError。
    ///
    /// 使用示例：
    /// ```swift
    /// // AppDelegate.swift
    /// import TemplateXService
    ///
    /// func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) {
    ///     TemplateX.registerImageLoader(SDWebImageLoader())
    /// }
    /// ```
    ///
    /// - Parameter loader: 图片加载器实例
    public static func registerImageLoader(_ loader: TemplateXImageLoader) {
        ServiceRegistry.shared.registerImageLoader(loader)
    }
    
    /// 注册日志服务
    ///
    /// 如果不调用此方法，会使用默认的 DefaultLogProvider（iOS 14+ 使用 os.Logger，iOS 14- 静默）。
    ///
    /// 使用示例：
    /// ```swift
    /// import TemplateXService
    ///
    /// TemplateX.registerLogProvider(ConsoleLogProvider())
    /// ```
    ///
    /// - Parameter provider: 日志服务实例
    public static func registerLogProvider(_ provider: TemplateXLogProvider) {
        ServiceRegistry.shared.registerLogProvider(provider)
    }
    
    /// 获取当前图片加载器
    ///
    /// - Note: 如果未注册 ImageLoader，会触发 fatalError
    public static var imageLoader: TemplateXImageLoader {
        ServiceRegistry.shared.imageLoader
    }
    
    /// 获取当前日志服务
    public static var logProvider: TemplateXLogProvider {
        ServiceRegistry.shared.logProvider
    }
}

// MARK: - 版本信息

extension TemplateX {
    
    /// 版本号
    public static let version = "1.0.0"
    
    /// 版本信息
    public static var versionInfo: String {
        """
        TemplateX v\(version)
        - Yoga Layout Engine
        - High Performance Expression Engine
        - View Tree Diff & Reuse
        """
    }
}
