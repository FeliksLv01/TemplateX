import UIKit

// MARK: - Button 组件

/// 按钮组件
/// 支持文字、图标、背景色、点击状态等
public final class ButtonComponent: BaseComponent, ComponentFactory {
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "button" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = ButtonComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Properties
    
    /// 按钮文字
    public var title: String?
    
    /// 按下时的文字颜色
    public var titleColorHighlighted: UIColor?
    
    /// 禁用时的文字颜色
    public var titleColorDisabled: UIColor?
    
    /// 图标（左侧）
    public var iconLeft: String?
    
    /// 图标（右侧）
    public var iconRight: String?
    
    /// 图标大小
    public var iconSize: CGFloat = 16
    
    /// 图标与文字间距
    public var iconSpacing: CGFloat = 4
    
    /// 按下时的背景色
    public var backgroundColorHighlighted: UIColor?
    
    /// 禁用时的背景色
    public var backgroundColorDisabled: UIColor?
    
    /// 是否禁用
    public var isDisabled: Bool = false
    
    /// 是否显示加载中
    public var isLoading: Bool = false
    
    /// 点击事件
    public var onClick: (() -> Void)?
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: ButtonComponent.typeIdentifier)
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        let cloned = ButtonComponent(id: self.id)
        cloned.jsonWrapper = self.jsonWrapper
        cloned.style = self.style.clone()
        cloned.events = self.events
        
        // 复制 Button 特有属性
        cloned.title = self.title
        cloned.titleColorHighlighted = self.titleColorHighlighted
        cloned.titleColorDisabled = self.titleColorDisabled
        cloned.iconLeft = self.iconLeft
        cloned.iconRight = self.iconRight
        cloned.iconSize = self.iconSize
        cloned.iconSpacing = self.iconSpacing
        cloned.backgroundColorHighlighted = self.backgroundColorHighlighted
        cloned.backgroundColorDisabled = self.backgroundColorDisabled
        cloned.isDisabled = self.isDisabled
        cloned.isLoading = self.isLoading
        
        // 注意: 不在这里递归克隆子组件，由 RenderEngine.cloneComponentTree 统一处理
        
        return cloned
    }
    
    // MARK: - Parse
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
        
        // 按钮默认裁剪
        style.clipsToBounds = true
        
        // 解析按钮特有属性
        if let props = json.props {
            parseButtonProps(from: props)
        }
        
        // 解析事件
        if let eventsJson = json.events {
            events = eventsJson.rawDictionary
        }
    }
    
    private func parseButtonProps(from props: JSONWrapper) {
        title = props.string("title") ?? props.string("text")
        
        titleColorHighlighted = props.color("titleColorHighlighted")
        titleColorDisabled = props.color("titleColorDisabled")
        
        iconLeft = props.string("iconLeft") ?? props.string("icon")
        iconRight = props.string("iconRight")
        
        if let size = props.cgFloat("iconSize") {
            iconSize = size
        }
        
        if let spacing = props.cgFloat("iconSpacing") {
            iconSpacing = spacing
        }
        
        backgroundColorHighlighted = props.color("backgroundColorHighlighted")
        backgroundColorDisabled = props.color("backgroundColorDisabled")
        
        isDisabled = props.bool("disabled", default: false)
        isLoading = props.bool("loading", default: false)
    }
    
    // MARK: - View
    
    public override func createView() -> UIView {
        let button = TemplateXButton(type: .custom)
        configureButton(button)
        
        button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        
        self.view = button
        return button
    }
    
    private func configureButton(_ button: TemplateXButton) {
        // 标题
        button.setTitle(title, for: .normal)
        
        // 文字颜色 - 从 style 读取
        let titleColor = style.textColor ?? .white
        button.setTitleColor(titleColor, for: .normal)
        button.setTitleColor(titleColorHighlighted ?? titleColor.withAlphaComponent(0.7), for: .highlighted)
        button.setTitleColor(titleColorDisabled ?? titleColor.withAlphaComponent(0.5), for: .disabled)
        
        // 字体 - 从 style 读取
        let fontSize = style.fontSize ?? 14
        let fontWeight = parseFontWeight(style.fontWeight)
        button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        
        // 背景色
        button.normalBackgroundColor = style.backgroundColor
        button.highlightedBackgroundColor = backgroundColorHighlighted ?? style.backgroundColor?.withAlphaComponent(0.8)
        button.disabledBackgroundColor = backgroundColorDisabled ?? style.backgroundColor?.withAlphaComponent(0.5)
        
        // 图标
        if iconLeft != nil {
            // TODO: 加载图标图片
            // button.setImage(UIImage(named: iconLeft), for: .normal)
        }
        
        // 状态
        button.isEnabled = !isDisabled
        button.isLoading = isLoading
        
        // 图标间距
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: iconSpacing)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: iconSpacing, bottom: 0, right: 0)
    }
    
    public override func updateView() {
        if let button = view as? TemplateXButton {
            configureButton(button)
        }
        super.updateView()
    }
    
    @objc private func handleTap() {
        guard !isDisabled && !isLoading else { return }
        onClick?()
    }
    
    // MARK: - Public Methods
    
    /// 设置加载状态
    public func setLoading(_ loading: Bool) {
        isLoading = loading
        (view as? TemplateXButton)?.isLoading = loading
    }
    
    /// 设置禁用状态
    public func setDisabled(_ disabled: Bool) {
        isDisabled = disabled
        (view as? UIButton)?.isEnabled = !disabled
    }
    
    // MARK: - Parse Helpers
    
    private func parseFontWeight(_ weight: String?) -> UIFont.Weight {
        guard let weight = weight else { return .regular }
        switch weight.lowercased() {
        case "thin", "100": return .thin
        case "ultralight", "200": return .ultraLight
        case "light", "300": return .light
        case "regular", "normal", "400": return .regular
        case "medium", "500": return .medium
        case "semibold", "600": return .semibold
        case "bold", "700": return .bold
        case "heavy", "800": return .heavy
        case "black", "900": return .black
        default: return .regular
        }
    }
}

// MARK: - TemplateXButton

/// 自定义按钮视图
public class TemplateXButton: UIButton {
    
    /// 正常背景色
    public var normalBackgroundColor: UIColor? {
        didSet {
            updateBackgroundColor()
        }
    }
    
    /// 高亮背景色
    public var highlightedBackgroundColor: UIColor?
    
    /// 禁用背景色
    public var disabledBackgroundColor: UIColor?
    
    /// 加载中状态
    public var isLoading: Bool = false {
        didSet {
            updateLoadingState()
        }
    }
    
    /// 加载指示器
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = .white
        return indicator
    }()
    
    /// 保存的标题
    private var savedTitle: String?
    
    public override var isHighlighted: Bool {
        didSet {
            updateBackgroundColor()
        }
    }
    
    public override var isEnabled: Bool {
        didSet {
            updateBackgroundColor()
        }
    }
    
    private func updateBackgroundColor() {
        if !isEnabled {
            backgroundColor = disabledBackgroundColor ?? normalBackgroundColor?.withAlphaComponent(0.5)
        } else if isHighlighted {
            backgroundColor = highlightedBackgroundColor ?? normalBackgroundColor?.withAlphaComponent(0.8)
        } else {
            backgroundColor = normalBackgroundColor
        }
    }
    
    private func updateLoadingState() {
        if isLoading {
            savedTitle = title(for: .normal)
            setTitle(nil, for: .normal)
            
            addSubview(loadingIndicator)
            loadingIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
            loadingIndicator.startAnimating()
            
            isUserInteractionEnabled = false
        } else {
            setTitle(savedTitle, for: .normal)
            loadingIndicator.stopAnimating()
            loadingIndicator.removeFromSuperview()
            
            isUserInteractionEnabled = true
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if isLoading {
            loadingIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
}
