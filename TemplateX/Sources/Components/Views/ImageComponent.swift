import UIKit

// MARK: - Image 组件

/// 图片组件
final class ImageComponent: TemplateXComponent<UIImageView, ImageComponent.Props> {
    
    // MARK: - Props
    
    enum SourceType: String, Codable, Equatable {
        case network
        case local
    }
    
    struct Props: ComponentProps {
        var src: String = ""
        var url: String?
        var source: String?
        var placeholder: String?
        var scaleType: ContentModeValue?
        var contentMode: ContentModeValue?
        var tintColor: ColorValue?
        var sourceType: SourceType?
        
        var imageUrl: String { url ?? source ?? src }
        
        var resolvedSourceType: SourceType { sourceType ?? .network }
        
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
        let imageUrl = props.imageUrl
        guard !imageUrl.isEmpty else { return }
        
        switch props.resolvedSourceType {
        case .local:
            let image = UIImage(named: imageUrl)
            imageView.image = applyTintIfNeeded(image ?? UIImage())
            
        case .network:
            ServiceRegistry.shared.imageLoader.loadImage(
                url: imageUrl,
                placeholder: props.placeholder,
                into: imageView
            ) { [weak imageView, weak self] image in
                guard let imageView = imageView, let image = image else { return }
                imageView.image = self?.applyTintIfNeeded(image) ?? image
            }
        }
    }
    
    private func applyTintIfNeeded(_ image: UIImage) -> UIImage {
        guard props.tintColor?.color != nil else { return image }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
