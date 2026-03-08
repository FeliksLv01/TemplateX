import Foundation

/// 简单的服务注册中心
///
/// 用于管理 TemplateX 的可插拔服务（ImageLoader、LogProvider 等）
///
/// Usage:
/// ```swift
/// // App 启动时注册
/// TemplateX.registerImageLoader(SDWebImageLoader())
/// TemplateX.registerLogProvider(ConsoleLogProvider())
///
/// // 或直接使用 ServiceRegistry
/// ServiceRegistry.shared.registerImageLoader(SDWebImageLoader())
/// ```
public final class ServiceRegistry {
    
    public static let shared = ServiceRegistry()
    
    private init() {}
    
    // MARK: - ImageLoader
    
    private var _imageLoader: TemplateXImageLoader?
    
    /// 注册图片加载器
    ///
    /// - Parameter loader: 图片加载器实例
    public func registerImageLoader(_ loader: TemplateXImageLoader) {
        _imageLoader = loader
    }
    
    /// 获取图片加载器
    ///
    /// - Note: 必须先注册，否则触发 fatalError
    public var imageLoader: TemplateXImageLoader {
        guard let loader = _imageLoader else {
            fatalError("[TemplateX] ImageLoader not registered. Call TemplateX.registerImageLoader(...) at app launch.")
        }
        return loader
    }
    
    /// 检查是否已注册图片加载器
    public var hasImageLoader: Bool {
        return _imageLoader != nil
    }
    
    // MARK: - ActionHandler
    
    private var _actionHandler: TemplateXActionHandler?
    
    /// 注册事件动作处理器
    ///
    /// - Parameter handler: 动作处理器实例
    public func registerActionHandler(_ handler: TemplateXActionHandler) {
        _actionHandler = handler
    }
    
    /// 获取事件动作处理器
    ///
    /// - Note: 未注册时返回 nil，触发事件时会打 warning 日志
    public var actionHandler: TemplateXActionHandler? {
        return _actionHandler
    }
    
    /// 检查是否已注册事件动作处理器
    public var hasActionHandler: Bool {
        return _actionHandler != nil
    }
    
    // MARK: - LogProvider
    
    private var _logProvider: TemplateXLogProvider?
    
    /// 注册日志服务
    ///
    /// - Parameter provider: 日志服务实例
    public func registerLogProvider(_ provider: TemplateXLogProvider) {
        _logProvider = provider
    }
    
    /// 获取日志服务
    ///
    /// - Note: 未注册时返回默认实现（DefaultLogProvider）
    public var logProvider: TemplateXLogProvider {
        if let provider = _logProvider {
            return provider
        }
        // 默认使用 DefaultLogProvider
        let defaultProvider = DefaultLogProvider.shared
        _logProvider = defaultProvider
        return defaultProvider
    }
    
    /// 检查是否已注册日志服务
    public var hasLogProvider: Bool {
        return _logProvider != nil
    }
    
    // MARK: - Reset
    
    /// 重置所有服务（用于测试）
    public func reset() {
        _imageLoader = nil
        _actionHandler = nil
        _logProvider = nil
    }
}
