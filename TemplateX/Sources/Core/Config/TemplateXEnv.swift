import UIKit

// MARK: - TemplateXEnv

/// TemplateX 全局环境配置（单例）
///
/// 参考 Lynx 的 LynxEnv，用于配置全局参数和提供者。
/// 多个 TemplateXView 可以共享同一个 Env 配置。
///
/// 使用示例：
/// ```swift
/// // 在 App 启动时配置
/// TemplateXEnv.shared.config = TemplateXConfig { config in
///     config.enablePerformanceMonitor = true
///     config.enableSyncFlush = true
/// }
///
/// TemplateXEnv.shared.templateProvider = MyTemplateProvider()
/// TemplateXEnv.shared.imageLoader = MyImageLoader()
/// ```
public final class TemplateXEnv {
    
    // MARK: - Singleton
    
    /// 全局共享实例
    public static let shared = TemplateXEnv()
    
    private init() {
        // 初始化默认配置
        _config = TemplateXConfig()
    }
    
    // MARK: - Config
    
    private var _config: TemplateXConfig
    
    /// 全局配置
    public var config: TemplateXConfig {
        get { _config }
        set {
            _config = newValue
            applyConfig(newValue)
        }
    }
    
    /// 应用配置到引擎
    private func applyConfig(_ config: TemplateXConfig) {
        TemplateXRenderEngine.shared.config.enablePerformanceMonitor = config.enablePerformanceMonitor
        
        // 应用 Pipeline 配置
        var pipelineConfig = RenderPipelinePool.shared.defaultConfig
        pipelineConfig.syncFlushTimeoutMs = config.syncFlushTimeoutMs
        RenderPipelinePool.shared.defaultConfig = pipelineConfig
    }
    
    // MARK: - Providers
    
    /// 模板提供者
    public var templateProvider: TemplateXTemplateProvider?
    
    /// 图片加载器
    public var imageLoader: TemplateXImageLoader?
    
    /// 资源提供者（按类型注册）
    private var resourceProviders: [String: TemplateXResourceProvider] = [:]
    
    /// 注册资源提供者
    public func registerResourceProvider(_ provider: TemplateXResourceProvider, forType type: String) {
        resourceProviders[type] = provider
    }
    
    /// 获取资源提供者
    public func resourceProvider(forType type: String) -> TemplateXResourceProvider? {
        return resourceProviders[type]
    }
    
    // MARK: - Screen Metrics
    
    /// 屏幕尺寸（用于 rpx 等相对单位计算）
    /// 默认使用设备屏幕尺寸，可以设置虚拟尺寸（如分屏场景）
    public var screenSize: CGSize = UIScreen.main.bounds.size
    
    /// 字体缩放比例
    public var fontScale: CGFloat = 1.0
    
    /// 屏幕密度（pt to px）
    public var screenDensity: CGFloat {
        return UIScreen.main.scale
    }
    
    // MARK: - Debug & Devtool
    
    /// 是否启用调试模式
    public var debugEnabled: Bool = false {
        didSet {
            if debugEnabled {
                TXLogger.info("Debug mode enabled")
            }
        }
    }
    
    /// 是否启用 DevTool（远程调试）
    public var devtoolEnabled: Bool = false
    
    /// 是否启用触摸高亮
    public var highlightTouchEnabled: Bool = false
    
    /// 是否启用性能监控
    public var performanceMonitorEnabled: Bool {
        get { config.enablePerformanceMonitor }
        set { 
            var newConfig = config
            newConfig.enablePerformanceMonitor = newValue
            config = newConfig
        }
    }
    
    // MARK: - Locale
    
    /// 当前语言环境
    public var locale: String = Locale.current.identifier
    
    // MARK: - Memory Management
    
    /// 内存压力级别
    public enum MemoryPressureLevel: Int {
        case none = 0       // 正常
        case moderate = 1   // 中等压力
        case critical = 2   // 严重压力
    }
    
    /// 响应内存压力
    public func trimMemory(_ pressure: MemoryPressureLevel) {
        switch pressure {
        case .none:
            break
        case .moderate:
            // 清理部分缓存
            TemplateCache.shared.trimToCount(100)
            TXLogger.info("TemplateXEnv: trimMemory moderate")
        case .critical:
            // 清理所有缓存
            TemplateCache.shared.clear()
            if ServiceRegistry.shared.hasImageLoader {
                ServiceRegistry.shared.imageLoader.clearCache(type: .all)
            }
            TXLogger.info("TemplateXEnv: trimMemory critical")
        }
    }
    
    // MARK: - Lifecycle
    
    /// 生命周期监听器
    private var lifecycleListeners: [WeakLifecycleListener] = []
    
    /// 添加生命周期监听
    public func addLifecycleListener(_ listener: TemplateXLifecycleListener) {
        lifecycleListeners.append(WeakLifecycleListener(listener))
    }
    
    /// 移除生命周期监听
    public func removeLifecycleListener(_ listener: TemplateXLifecycleListener) {
        lifecycleListeners.removeAll { $0.value === listener }
    }
    
    /// 通知进入前台
    public func onEnterForeground() {
        cleanupWeakRefs()
        lifecycleListeners.forEach { $0.value?.onEnterForeground() }
    }
    
    /// 通知进入后台
    public func onEnterBackground() {
        cleanupWeakRefs()
        lifecycleListeners.forEach { $0.value?.onEnterBackground() }
    }
    
    private func cleanupWeakRefs() {
        lifecycleListeners.removeAll { $0.value == nil }
    }
    
    // MARK: - Init & Warmup
    
    /// 初始化（建议在 App 启动时调用）
    ///
    /// - Parameters:
    ///   - config: 全局配置
    ///   - templateProvider: 模板提供者
    ///   - imageLoader: 图片加载器
    public func initialize(
        config: TemplateXConfig? = nil,
        templateProvider: TemplateXTemplateProvider? = nil,
        imageLoader: TemplateXImageLoader? = nil
    ) {
        if let config = config {
            self.config = config
        }
        self.templateProvider = templateProvider
        self.imageLoader = imageLoader
        
        TXLogger.info("TemplateXEnv initialized")
    }
    
    /// 预热引擎
    public func warmUp(options: TemplateX.WarmUpOptions = .default) {
        TemplateX.warmUp(options: options)
    }
}

// MARK: - 弱引用包装

private class WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

/// 生命周期监听器弱引用包装
private class WeakLifecycleListener {
    weak var value: (any TemplateXLifecycleListener)?
    init(_ value: any TemplateXLifecycleListener) {
        self.value = value
    }
}

// MARK: - TemplateXLifecycleListener

/// 生命周期监听协议
public protocol TemplateXLifecycleListener: AnyObject {
    func onEnterForeground()
    func onEnterBackground()
}

// 提供默认实现
public extension TemplateXLifecycleListener {
    func onEnterForeground() {}
    func onEnterBackground() {}
}
