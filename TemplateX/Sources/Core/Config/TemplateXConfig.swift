import UIKit

// MARK: - TemplateXConfig

/// TemplateX 配置对象
///
/// 参考 Lynx 的 LynxConfig，用于配置渲染行为。
/// 可以在全局级别（TemplateXEnv）或视图级别（TemplateXView）设置。
///
/// 使用示例：
/// ```swift
/// // 方式1: 使用 Builder 闭包
/// let config = TemplateXConfig { config in
///     config.enablePerformanceMonitor = true
///     config.enableSyncFlush = true
///     config.syncFlushTimeoutMs = 100
/// }
///
/// // 方式2: 直接创建并修改
/// var config = TemplateXConfig()
/// config.enablePerformanceMonitor = true
/// ```
public struct TemplateXConfig {
    
    // MARK: - 渲染配置
    
    /// 是否启用 Pipeline 渲染（默认 true）
    ///
    /// Pipeline 渲染：后台执行 parse + bind + layout，SyncFlush 同步等待
    public var enablePipelineRendering: Bool = true
    
    /// 是否启用 SyncFlush（默认 true）
    ///
    /// SyncFlush：在 layoutSubviews 时同步等待后台线程完成
    public var enableSyncFlush: Bool = true
    
    /// SyncFlush 超时时间（毫秒，默认 100）
    public var syncFlushTimeoutMs: Int = 100
    
    // MARK: - 布局配置
    
    /// 是否启用增量布局（Yoga 剪枝优化，默认 true）
    public var enableIncrementalLayout: Bool = true
    
    /// 是否启用布局缓存
    public var enableLayoutCache: Bool = true
    
    // MARK: - 视图复用
    
    /// 是否启用视图复用池（默认 true）
    public var enableViewRecycling: Bool = true
    
    /// 是否启用组件池（默认 true）
    public var enableComponentPool: Bool = true
    
    // MARK: - 性能监控
    
    /// 是否启用性能监控（默认 false）
    ///
    /// 启用后会在日志中输出渲染耗时
    public var enablePerformanceMonitor: Bool = false
    
    /// 是否启用详细日志（高频日志，默认 false）
    ///
    /// ⚠️ 会严重影响性能，仅用于调试
    public var enableVerboseLogging: Bool = false {
        didSet {
            TXLogger.verboseEnabled = enableVerboseLogging
        }
    }
    
    // MARK: - 线程策略
    
    /// 渲染线程策略
    public enum ThreadStrategy {
        /// 所有操作都在 UI 线程（最安全，但可能卡顿）
        case allOnUI
        
        /// 布局在后台线程，UI 操作在主线程（推荐）
        case layoutOnBackground
        
        /// 多线程并发（最高性能，需要注意线程安全）
        case multiThread
    }
    
    /// 渲染线程策略（默认 layoutOnBackground）
    public var threadStrategy: ThreadStrategy = .layoutOnBackground
    
    // MARK: - 异步渲染
    
    /// 是否启用异步渲染
    public var enableAsyncRendering: Bool = true
    
    /// 异步渲染队列优先级
    public var asyncRenderingQoS: DispatchQoS = .userInitiated
    
    // MARK: - 组件配置
    
    /// 自定义组件工厂（可以覆盖内置组件）
    public var componentFactories: [String: ComponentFactory.Type] = [:]
    
    // MARK: - Init
    
    /// 默认初始化
    public init() {}
    
    /// 使用 Builder 闭包初始化
    public init(_ builder: (inout TemplateXConfig) -> Void) {
        builder(&self)
    }
    
    // MARK: - Preset Configs
    
    /// 默认配置
    public static var `default`: TemplateXConfig {
        return TemplateXConfig()
    }
    
    /// 高性能配置（适用于列表/Cell 场景）
    public static var highPerformance: TemplateXConfig {
        return TemplateXConfig { config in
            config.enablePipelineRendering = true
            config.enableSyncFlush = true
            config.syncFlushTimeoutMs = 50  // 更短的超时
            config.enableIncrementalLayout = true
            config.enableViewRecycling = true
            config.enableComponentPool = true
            config.threadStrategy = .layoutOnBackground
        }
    }
    
    /// 调试配置
    public static var debug: TemplateXConfig {
        return TemplateXConfig { config in
            config.enablePerformanceMonitor = true
            config.enableVerboseLogging = true
            config.threadStrategy = .allOnUI  // 方便调试
        }
    }
    
    /// 最简配置（适用于简单场景）
    public static var simple: TemplateXConfig {
        return TemplateXConfig { config in
            config.enablePipelineRendering = false
            config.enableSyncFlush = false
            config.threadStrategy = .allOnUI
        }
    }
}
