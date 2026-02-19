import UIKit

// MARK: - Button 组件

/// 按钮组件
/// 支持文字、图标、背景色、点击状态等
final class ButtonComponent: TemplateXComponent<TemplateXButton, ButtonComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        var title: String?
        var text: String?
        var iconLeft: String?
        var icon: String?
        var iconRight: String?
        var iconSize: CGFloat?
        var iconSpacing: CGFloat?
        @Default<False> var disabled: Bool
        @Default<False> var loading: Bool
        var titleColorHighlighted: String?
        var titleColorDisabled: String?
        var backgroundColorHighlighted: String?
        var backgroundColorDisabled: String?
        
        /// 按钮标题（兼容 title 和 text）
        var buttonTitle: String? { title ?? text }
        
        /// 左侧图标（兼容 iconLeft 和 icon）
        var leftIcon: String? { iconLeft ?? icon }
    }
    
    // MARK: - ComponentFactory
    
    override class var typeIdentifier: String { "button" }
    
    // MARK: - 便捷属性访问器（供 DiffPatcher 等外部使用）
    
    var title: String? {
        get { props.buttonTitle }
        set { props.title = newValue }
    }
    
    var isDisabled: Bool {
        get { props.disabled }
        set { props.disabled = newValue }
    }
    
    var isLoading: Bool {
        get { props.loading }
        set { props.loading = newValue }
    }
    
    var iconLeft: String? {
        get { props.leftIcon }
        set { props.iconLeft = newValue }
    }
    
    var iconRight: String? {
        get { props.iconRight }
        set { props.iconRight = newValue }
    }
    
    // MARK: - 事件回调
    
    var onClick: (() -> Void)?
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let button = TemplateXButton(type: .custom)
        button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        self.view = button
        return button
    }
    
    override func didParseProps() {
        // 按钮默认裁剪
        style.clipsToBounds = true
    }
    
    override func configureView(_ view: TemplateXButton) {
        // 标题
        view.setTitle(props.buttonTitle, for: .normal)
        
        // 文字颜色 - 从 style 读取
        let titleColor = style.textColor ?? .white
        view.setTitleColor(titleColor, for: .normal)
        view.setTitleColor(
            parseColor(props.titleColorHighlighted) ?? titleColor.withAlphaComponent(0.7),
            for: .highlighted
        )
        view.setTitleColor(
            parseColor(props.titleColorDisabled) ?? titleColor.withAlphaComponent(0.5),
            for: .disabled
        )
        
        // 字体 - 从 style 读取
        let fontSize = style.fontSize ?? 14
        let fontWeight = parseFontWeight(style.fontWeight)
        view.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        
        // 背景色
        view.normalBackgroundColor = style.backgroundColor
        view.highlightedBackgroundColor = parseColor(props.backgroundColorHighlighted)
            ?? style.backgroundColor?.withAlphaComponent(0.8)
        view.disabledBackgroundColor = parseColor(props.backgroundColorDisabled)
            ?? style.backgroundColor?.withAlphaComponent(0.5)
        
        // 图标
        // TODO: 加载图标图片
        
        // 状态
        view.isEnabled = !props.disabled
        view.isLoading = props.loading
        
        // 图标间距
        let spacing = props.iconSpacing ?? 4
        view.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: spacing)
        view.titleEdgeInsets = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: 0)
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        guard !props.disabled && !props.loading else { return }
        onClick?()
    }
    
    // MARK: - Public Methods
    
    /// 设置加载状态
    func setLoading(_ loading: Bool) {
        props.loading = loading
        (view as? TemplateXButton)?.isLoading = loading
    }
    
    /// 设置禁用状态
    func setDisabled(_ disabled: Bool) {
        props.disabled = disabled
        (view as? UIButton)?.isEnabled = !disabled
    }
    
    // MARK: - Parse Helpers
    
    private func parseColor(_ colorString: String?) -> UIColor? {
        guard let str = colorString else { return nil }
        return UIColor(hexString: str)
    }
    
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
class TemplateXButton: UIButton {
    
    /// 正常背景色
    var normalBackgroundColor: UIColor? {
        didSet {
            updateBackgroundColor()
        }
    }
    
    /// 高亮背景色
    var highlightedBackgroundColor: UIColor?
    
    /// 禁用背景色
    var disabledBackgroundColor: UIColor?
    
    /// 加载中状态
    var isLoading: Bool = false {
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
    
    override var isHighlighted: Bool {
        didSet {
            updateBackgroundColor()
        }
    }
    
    override var isEnabled: Bool {
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if isLoading {
            loadingIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
}
