import UIKit

// MARK: - Image 组件

/// 图片组件
final class ImageComponent: TemplateXComponent<UIImageView, ImageComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        /// 图片 URL
        var src: String = ""
        /// 图片 URL（别名）
        var url: String?
        /// 图片 URL（别名）
        var source: String?
        /// 占位图
        var placeholder: String?
        /// 缩放模式
        var scaleType: ContentModeValue?
        /// 缩放模式（别名）
        var contentMode: ContentModeValue?
        /// 着色
        var tintColor: ColorValue?
        
        /// 获取实际图片 URL（兼容多种 key）
        var imageUrl: String { url ?? source ?? src }
        
        /// 获取缩放模式
        var resolvedContentMode: UIView.ContentMode {
            scaleType?.mode ?? contentMode?.mode ?? .scaleAspectFill
        }
    }
    
    // MARK: - Type Identifier
    
    override class var typeIdentifier: String { "image" }
    
    // MARK: - 缓存
    
    private var _previousUrl: String?
    private var _previousContentMode: UIView.ContentMode?
    private var _previousTintColor: UIColor?
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = props.resolvedContentMode
        return imageView
    }
    
    override func didParseProps() {
        // 图片默认裁剪
        style.clipsToBounds = true
    }
    
    override func configureView(_ view: UIImageView) {
        let needsFullUpdate = forceApplyStyle || _previousContentMode == nil
        
        let currentContentMode = props.resolvedContentMode
        let currentTintColor = props.tintColor?.color
        let currentUrl = props.imageUrl
        
        // 设置内容模式
        if needsFullUpdate || _previousContentMode != currentContentMode {
            view.contentMode = currentContentMode
            _previousContentMode = currentContentMode
        }
        
        // 着色
        if needsFullUpdate || _previousTintColor != currentTintColor {
            if let tint = currentTintColor {
                view.tintColor = tint
            }
            _previousTintColor = currentTintColor
        }
        
        // 加载图片（只在 URL 变化时加载）
        if needsFullUpdate || _previousUrl != currentUrl {
            loadImage(into: view)
            _previousUrl = currentUrl
        }
    }
    
    // MARK: - Private
    
    private func loadImage(into imageView: UIImageView) {
        guard !props.imageUrl.isEmpty else { return }
        
        ServiceRegistry.shared.imageLoader.loadImage(
            url: props.imageUrl,
            placeholder: props.placeholder,
            into: imageView
        ) { [weak imageView, weak self] image in
            guard let imageView = imageView, let image = image else { return }
            imageView.image = self?.applyTintIfNeeded(image) ?? image
        }
    }
    
    private func applyTintIfNeeded(_ image: UIImage) -> UIImage {
        guard props.tintColor?.color != nil else { return image }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
