import UIKit
import TemplateX
import SDWebImage
import SDWebImageWebPCoder

/// SDWebImage 图片加载器
///
/// 基于 SDWebImage 的 TemplateXImageLoader 实现，支持 WebP 格式。
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
/// Podfile 配置：
/// ```ruby
/// pod 'TemplateX'
/// pod 'TemplateXService'  # 或 pod 'TemplateXService/Image'
/// ```
public final class SDWebImageLoader: TemplateXImageLoader {
    
    public init() {
        // 注册 WebP 解码器
        SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
    }
    
    public func loadImage(
        url: String,
        placeholder: String?,
        into imageView: UIImageView,
        completion: ((UIImage?) -> Void)?
    ) {
        // 本地图片（Assets）
        if let localImage = UIImage(named: url) {
            imageView.image = localImage
            completion?(localImage)
            return
        }
        
        // 占位图
        let placeholderImage = placeholder.flatMap { UIImage(named: $0) }
        
        // 网络图片
        guard let imageURL = URL(string: url) else {
            imageView.image = placeholderImage
            completion?(nil)
            return
        }
        
        imageView.sd_setImage(with: imageURL, placeholderImage: placeholderImage) { image, error, cacheType, url in
            completion?(image)
        }
    }
    
    public func cancelLoad(for imageView: UIImageView) {
        imageView.sd_cancelCurrentImageLoad()
    }
    
    public func prefetchImages(urls: [String]) {
        let imageURLs = urls.compactMap { URL(string: $0) }
        SDWebImagePrefetcher.shared.prefetchURLs(imageURLs)
    }
    
    public func clearCache(type: ImageCacheType) {
        switch type {
        case .memory:
            SDImageCache.shared.clearMemory()
        case .disk:
            SDImageCache.shared.clearDisk()
        case .all:
            SDImageCache.shared.clearMemory()
            SDImageCache.shared.clearDisk()
        }
    }
    
    /// 预热 SDWebImage
    ///
    /// 触发 SDWebImageManager 和 SDImageCache 的单例初始化。
    /// 避免首次加载图片时的 ~3ms 初始化开销。
    public func warmUp() {
        // 触发 SDWebImageManager 单例初始化
        _ = SDWebImageManager.shared
        // 触发 SDImageCache 单例初始化
        _ = SDImageCache.shared
        // 触发 SDWebImageDownloader 单例初始化
        _ = SDWebImageDownloader.shared
    }
}
