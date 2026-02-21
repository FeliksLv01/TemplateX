import UIKit

// MARK: - ImageCacheType

/// 图片缓存类型
public enum ImageCacheType {
    case memory
    case disk
    case all
}

// MARK: - TemplateXImageLoader

/// 图片加载器协议
///
/// 用于加载图片，需要上层注册实现（如 SDWebImage）。
///
/// 使用示例：
/// ```swift
/// // 1. 实现协议（或使用 TemplateXService/Image）
/// import TemplateXService
///
/// // 2. 注册（App 启动时）
/// TemplateX.registerImageLoader(SDWebImageLoader())
/// ```
public protocol TemplateXImageLoader: AnyObject {
    
    /// 加载图片到 ImageView
    ///
    /// - Parameters:
    ///   - url: 图片 URL（支持本地图片名和网络 URL）
    ///   - placeholder: 占位图名称
    ///   - imageView: 目标 ImageView
    ///   - completion: 完成回调
    func loadImage(
        url: String,
        placeholder: String?,
        into imageView: UIImageView,
        completion: ((UIImage?) -> Void)?
    )
    
    /// 取消图片加载
    ///
    /// - Parameter imageView: 目标 ImageView
    func cancelLoad(for imageView: UIImageView)
    
    /// 预加载图片
    ///
    /// - Parameter urls: 图片 URL 列表
    func prefetchImages(urls: [String])
    
    /// 清除缓存
    ///
    /// - Parameter type: 缓存类型
    func clearCache(type: ImageCacheType)
    
    /// 预热图片加载器
    ///
    /// 触发懒加载的单例初始化，避免首次使用时的开销。
    /// 建议在 App 启动时的后台线程调用。
    func warmUp()
}

// MARK: - Default Implementation

public extension TemplateXImageLoader {
    func cancelLoad(for imageView: UIImageView) {}
    func prefetchImages(urls: [String]) {}
    func clearCache(type: ImageCacheType) {}
    func warmUp() {}
}
