import UIKit
import os

// MARK: - 日志系统

/// TemplateX 日志工具（基于 os.Logger，iOS 14+）
/// 
/// 使用示例：
/// ```swift
/// TXLog.trace("render completed in \(time)ms")
/// TXLog.error("failed to parse template")
/// ```
///
/// 日志级别控制：
/// - 生产环境：默认只输出 error/fault
/// - 调试环境：可通过 Console.app 或 `log` 命令查看所有级别
@available(iOS 14.0, *)
public enum TXLog {
    
    /// 主日志器
    private static let logger = Logger(subsystem: "com.templatex", category: "render")
    
    /// 性能追踪日志器
    private static let perfLogger = Logger(subsystem: "com.templatex", category: "performance")
    
    /// 是否启用 verbose 日志（高频日志，影响性能）
    /// 默认关闭，需要调试时手动开启
    public static var verboseEnabled = false
    
    /// 错误日志（始终输出）
    @inline(__always)
    public static func error(_ message: String) {
        logger.error("❌ \(message, privacy: .public)")
    }
    
    /// 警告日志
    @inline(__always)
    public static func warning(_ message: String) {
        logger.warning("⚠️ \(message, privacy: .public)")
    }
    
    /// 信息日志
    @inline(__always)
    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
    
    /// 调试日志（仅在 DEBUG 模式或连接调试器时可见）
    @inline(__always)
    public static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
    
    /// 性能追踪日志（使用 signpost 兼容 Instruments）
    @inline(__always)
    public static func trace(_ message: String) {
        perfLogger.trace("\(message, privacy: .public)")
    }
    
    /// 详细日志（每个组件创建等高频日志）
    /// 
    /// ⚠️ 默认关闭，需要调试时设置 `TXLog.verboseEnabled = true`
    /// 原因：os.Logger 在多线程并发时有内部同步开销，高频日志会严重影响性能
    @inline(__always)
    public static func verbose(_ message: String) {
        #if DEBUG
        if verboseEnabled {
            perfLogger.trace("📝 \(message, privacy: .public)")
        }
        #endif
    }
}

/// iOS 14 以下的兼容版本
public enum TXLogLegacy {
    
    /// 是否启用日志（生产环境建议关闭）
    public static var isEnabled = true
    
    /// 是否启用 verbose 日志（默认关闭）
    public static var verboseEnabled = false
    
    @inline(__always)
    public static func error(_ message: String) {
        if isEnabled { print("[TemplateX][Error] \(message)") }
    }
    
    @inline(__always)
    public static func warning(_ message: String) {
        if isEnabled { print("[TemplateX][Warn] \(message)") }
    }
    
    @inline(__always)
    public static func info(_ message: String) {
        if isEnabled { print("[TemplateX] \(message)") }
    }
    
    @inline(__always)
    public static func debug(_ message: String) {
        #if DEBUG
        if isEnabled { print("[TemplateX][Debug] \(message)") }
        #endif
    }
    
    @inline(__always)
    public static func trace(_ message: String) {
        #if DEBUG
        if isEnabled { print("[TemplateX][Trace] \(message)") }
        #endif
    }
    
    @inline(__always)
    public static func verbose(_ message: String) {
        #if DEBUG
        if isEnabled && verboseEnabled { print("[TemplateX][Verbose] \(message)") }
        #endif
    }
}

// MARK: - 统一日志接口（自动选择实现）

/// 统一日志接口，自动根据 iOS 版本选择实现
public enum TXLogger {
    
    /// 是否启用 verbose 日志（高频日志，默认关闭）
    /// 
    /// ⚠️ 开启会严重影响性能，仅用于调试
    public static var verboseEnabled: Bool {
        get {
            if #available(iOS 14.0, *) {
                return TXLog.verboseEnabled
            } else {
                return TXLogLegacy.verboseEnabled
            }
        }
        set {
            if #available(iOS 14.0, *) {
                TXLog.verboseEnabled = newValue
            } else {
                TXLogLegacy.verboseEnabled = newValue
            }
        }
    }
    
    @inline(__always)
    public static func error(_ message: String) {
        if #available(iOS 14.0, *) {
            TXLog.error(message)
        } else {
            TXLogLegacy.error(message)
        }
    }
    
    @inline(__always)
    public static func warning(_ message: String) {
        if #available(iOS 14.0, *) {
            TXLog.warning(message)
        } else {
            TXLogLegacy.warning(message)
        }
    }
    
    @inline(__always)
    public static func info(_ message: String) {
        if #available(iOS 14.0, *) {
            TXLog.info(message)
        } else {
            TXLogLegacy.info(message)
        }
    }
    
    @inline(__always)
    public static func debug(_ message: String) {
        if #available(iOS 14.0, *) {
            TXLog.debug(message)
        } else {
            TXLogLegacy.debug(message)
        }
    }
    
    @inline(__always)
    public static func trace(_ message: String) {
        if #available(iOS 14.0, *) {
            TXLog.trace(message)
        } else {
            TXLogLegacy.trace(message)
        }
    }
    
    @inline(__always)
    public static func verbose(_ message: String) {
        if #available(iOS 14.0, *) {
            TXLog.verbose(message)
        } else {
            TXLogLegacy.verbose(message)
        }
    }
}

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
///   "type": "view",
///   "props": { "width": -1, "height": 100, "backgroundColor": "#FF0000" }
/// }
/// """
/// let view = TemplateX.render(json: json)
/// ```
public enum TemplateX {
    
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
        return RenderEngine.shared.render(
            templateName: templateName,
            data: data,
            containerSize: size
        )
    }
    
    /// 从 JSON 字典渲染视图
    public static func render(
        json: [String: Any],
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        return RenderEngine.shared.render(
            json: json,
            data: data,
            containerSize: size
        )
    }
    
    /// 从 JSON 字符串渲染视图
    public static func render(
        json jsonString: String,
        data: [String: Any]? = nil,
        size: CGSize = CGSize(width: UIScreen.main.bounds.width, height: .nan)
    ) -> UIView? {
        return RenderEngine.shared.createView(from: jsonString, size: size)
    }
    
    // MARK: - 配置
    
    /// 引擎配置
    public static var config: RenderEngine.Config {
        get { RenderEngine.shared.config }
        set { RenderEngine.shared.config = newValue }
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
        ImageLoader.shared.clearCache()
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
        
        // 4. 触发 RenderEngine 单例初始化
        _ = RenderEngine.shared
        
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
