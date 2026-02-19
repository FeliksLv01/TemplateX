import UIKit

// MARK: - Image 组件

/// 图片组件
final class ImageComponent: TemplateXComponent<UIImageView, ImageComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        var src: String = ""
        var url: String?
        var source: String?
        var placeholder: String?
        var scaleType: String?
        var contentMode: String?
        var tintColor: String?
        
        /// 获取实际图片 URL（兼容多种 key）
        var imageUrl: String { url ?? source ?? src }
        
        /// 获取缩放模式
        var resolvedScaleType: String? { scaleType ?? contentMode }
    }
    
    // MARK: - ComponentFactory
    
    override class var typeIdentifier: String { "image" }
    
    // MARK: - 便捷属性访问器（供 DataBindingManager 等外部使用）
    
    var src: String {
        get { props.imageUrl }
        set { props.src = newValue }
    }
    
    var placeholder: String? {
        get { props.placeholder }
        set { props.placeholder = newValue }
    }
    
    var scaleType: String? {
        get { props.resolvedScaleType }
        set { props.scaleType = newValue }
    }
    
    var tintColor: UIColor? {
        get { parseColor(props.tintColor) }
        set { props.tintColor = newValue?.hexString }
    }
    
    // MARK: - 缓存
    
    private var _lastLoadedUrl: String?
    private var _lastScaleType: String?
    private var _lastTintColor: String?
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = parseScaleType(props.resolvedScaleType)
        self.view = imageView
        return imageView
    }
    
    override func didParseProps() {
        // 图片默认裁剪
        style.clipsToBounds = true
    }
    
    override func configureView(_ view: UIImageView) {
        let needsFullUpdate = forceApplyStyle || _lastScaleType == nil
        
        // 设置内容模式
        if needsFullUpdate || _lastScaleType != props.resolvedScaleType {
            view.contentMode = parseScaleType(props.resolvedScaleType)
            _lastScaleType = props.resolvedScaleType
        }
        
        // 着色
        if needsFullUpdate || _lastTintColor != props.tintColor {
            if let tintStr = props.tintColor, let tint = parseColor(tintStr) {
                view.tintColor = tint
            }
            _lastTintColor = props.tintColor
        }
        
        // 加载图片（只在 URL 变化时加载）
        if needsFullUpdate || _lastLoadedUrl != props.imageUrl {
            loadImage(into: view)
            _lastLoadedUrl = props.imageUrl
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
        guard props.tintColor != nil else { return image }
        return image.withRenderingMode(.alwaysTemplate)
    }
    
    private func parseColor(_ colorString: String?) -> UIColor? {
        guard let str = colorString else { return nil }
        return UIColor(hexString: str)
    }
    
    private func parseScaleType(_ str: String?) -> UIView.ContentMode {
        guard let str = str else { return .scaleAspectFill }
        switch str.lowercased() {
        case "fill", "scaletofill": return .scaleToFill
        case "fit", "aspectfit", "scaleaspectfit": return .scaleAspectFit
        case "cover", "aspectfill", "scaleaspectfill", "centercrop": return .scaleAspectFill
        case "center": return .center
        case "top": return .top
        case "bottom": return .bottom
        case "left": return .left
        case "right": return .right
        default: return .scaleAspectFill
        }
    }
}
