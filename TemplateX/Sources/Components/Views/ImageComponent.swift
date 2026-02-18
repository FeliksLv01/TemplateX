import UIKit

// MARK: - Image 组件

/// 图片组件
public final class ImageComponent: BaseComponent, ComponentFactory {
    
    // MARK: - 图片属性
    
    public var src: String = ""
    public var placeholder: String?
    public var scaleType: ScaleType = .scaleAspectFill
    public var tintColor: UIColor?
    
    // MARK: - 缓存（性能优化）
    
    /// 上次加载的图片 URL（避免重复加载）
    private var _lastLoadedSrc: String?
    private var _lastAppliedScaleType: ScaleType?
    private var _lastAppliedTintColor: UIColor?
    
    /// 图片缩放模式
    public enum ScaleType: String {
        case scaleToFill = "scaleToFill"
        case scaleAspectFit = "aspectFit"
        case scaleAspectFill = "aspectFill"
        case center = "center"
        case top = "top"
        case bottom = "bottom"
        case left = "left"
        case right = "right"
        
        var contentMode: UIView.ContentMode {
            switch self {
            case .scaleToFill: return .scaleToFill
            case .scaleAspectFit: return .scaleAspectFit
            case .scaleAspectFill: return .scaleAspectFill
            case .center: return .center
            case .top: return .top
            case .bottom: return .bottom
            case .left: return .left
            case .right: return .right
            }
        }
    }
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "image" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = ImageComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: ImageComponent.typeIdentifier)
    }
    
    // MARK: - Parse
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
        
        // 图片默认裁剪
        style.clipsToBounds = true
        
        // 解析图片特有属性
        if let props = json.props {
            parseImageProps(from: props)
        }
    }
    
    private func parseImageProps(from props: JSONWrapper) {
        // 图片地址
        if let s = props.string("src") { src = s }
        if let s = props.string("url") { src = s }
        if let s = props.string("source") { src = s }
        
        // 占位图
        placeholder = props.string("placeholder")
        
        // 缩放模式
        if let mode = props.string("scaleType") ?? props.string("contentMode") {
            scaleType = parseScaleType(mode)
        }
        
        // 着色
        tintColor = props.color("tintColor")
    }
    
    // MARK: - View
    
    public override func createView() -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = scaleType.contentMode
        imageView.clipsToBounds = true
        self.view = imageView
        return imageView
    }
    
    public override func updateView() {
        super.updateView()
        
        guard let imageView = view as? UIImageView else { return }
        
        let needsFullUpdate = forceApplyStyle || _lastAppliedScaleType == nil
        
        // 设置内容模式
        if needsFullUpdate || _lastAppliedScaleType != scaleType {
            imageView.contentMode = scaleType.contentMode
            _lastAppliedScaleType = scaleType
        }
        
        // 着色
        if needsFullUpdate || _lastAppliedTintColor != tintColor {
            if let tint = tintColor {
                imageView.tintColor = tint
            }
            _lastAppliedTintColor = tintColor
        }
        
        // 加载图片（只在 src 变化时加载）
        if needsFullUpdate || _lastLoadedSrc != src {
            loadImage(into: imageView)
            _lastLoadedSrc = src
        }
    }
    
    /// 加载图片（通过 ServiceRegistry.imageLoader）
    private func loadImage(into imageView: UIImageView) {
        guard !src.isEmpty else { return }
        
        // 使用 ServiceRegistry 获取图片加载器
        ServiceRegistry.shared.imageLoader.loadImage(
            url: src,
            placeholder: placeholder,
            into: imageView
        ) { [weak imageView, weak self] image in
            guard let imageView = imageView, let image = image else { return }
            imageView.image = self?.applyTintIfNeeded(image) ?? image
        }
    }
    
    private func applyTintIfNeeded(_ image: UIImage) -> UIImage {
        guard tintColor != nil else { return image }
        return image.withRenderingMode(.alwaysTemplate)
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        // 使用原 id，确保 Diff 算法能正确匹配组件
        let cloned = ImageComponent(id: self.id)
        // 复制基础属性
        cloned.style = self.style
        cloned.bindings = self.bindings
        cloned.events = self.events
        cloned.jsonWrapper = self.jsonWrapper
        // 复制图片特有属性
        cloned.src = self.src
        cloned.placeholder = self.placeholder
        cloned.scaleType = self.scaleType
        cloned.tintColor = self.tintColor
        return cloned
    }
    
    // MARK: - Diff
    
    public override func needsUpdate(with other: Component) -> Bool {
        guard let otherImage = other as? ImageComponent else { return true }
        
        if src != otherImage.src { return true }
        if scaleType != otherImage.scaleType { return true }
        if tintColor != otherImage.tintColor { return true }
        
        return super.needsUpdate(with: other)
    }
    
    // MARK: - Parse Helpers
    
    private func parseScaleType(_ str: String) -> ScaleType {
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
