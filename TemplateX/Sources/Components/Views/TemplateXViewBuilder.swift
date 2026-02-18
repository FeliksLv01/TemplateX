import UIKit

// MARK: - TemplateXViewBuilder

/// TemplateXView 构建器
///
/// 参考 Lynx 的 LynxViewBuilder，使用 Builder 模式配置 TemplateXView。
///
/// 使用示例：
/// ```swift
/// let templateView = TemplateXView { builder in
///     builder.config = TemplateXConfig { config in
///         config.enablePerformanceMonitor = true
///     }
///     builder.screenSize = view.bounds.size
///     builder.fontScale = 1.0
///     builder.templateProvider = MyTemplateProvider()
/// }
///
/// templateView.preferredLayoutWidth = 375
/// templateView.preferredLayoutHeight = .nan
/// templateView.layoutWidthMode = .exact
/// templateView.layoutHeightMode = .atMost
///
/// templateView.loadTemplate(url: "home_card", data: data)
/// ```
public class TemplateXViewBuilder {
    
    // MARK: - Config
    
    /// 配置对象
    public var config: TemplateXConfig?
    
    // MARK: - Screen Metrics
    
    /// 屏幕尺寸（用于 rpx 计算）
    public var screenSize: CGSize = UIScreen.main.bounds.size
    
    /// 字体缩放比例
    public var fontScale: CGFloat = 1.0
    
    // MARK: - Providers
    
    /// 模板提供者
    public var templateProvider: TemplateXTemplateProvider?
    
    /// 图片加载器
    public var imageLoader: TemplateXImageLoader?
    
    // MARK: - Frame
    
    /// 初始 frame
    public var frame: CGRect = .zero
    
    // MARK: - Options
    
    /// 是否启用自动布局更新
    public var enableAutoLayout: Bool = true
    
    /// 是否启用 SyncFlush
    public var enableSyncFlush: Bool = true
    
    /// 是否启用异步渲染
    public var enableAsyncRendering: Bool = true
    
    /// 是否启用 UI 操作队列
    public var enableUIOperationQueue: Bool = true
    
    /// SyncFlush 超时时间（毫秒）
    public var syncFlushTimeoutMs: Int = 100
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - TemplateXViewSizeMode

/// 布局尺寸模式
///
/// 参考 Lynx 的 LynxViewSizeMode，定义视图的布局行为。
public enum TemplateXViewSizeMode {
    /// 精确尺寸（使用 preferredLayoutWidth/Height）
    case exact
    
    /// 最大尺寸（内容撑开，但不超过 preferredMaxLayoutWidth/Height）
    case atMost
    
    /// 包裹内容（自动根据内容计算尺寸）
    case wrapContent
}

// MARK: - TemplateXViewBuilderBlock

/// Builder 闭包类型
public typealias TemplateXViewBuilderBlock = (TemplateXViewBuilder) -> Void
