import UIKit

// MARK: - Button 组件

/// 按钮组件
/// 支持文字、图标、背景色、点击状态等
///
/// 文本样式从 style 读取：fontSize, fontWeight, textColor
final class ButtonComponent: TemplateXComponent<TemplateXButton, ButtonComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        /// 按钮标题
        var title: String?
        /// 按钮标题（别名）
        var text: String?
        /// 标题颜色（优先于 style.textColor）
        var titleColor: ColorValue?
        /// 左侧图标
        var iconLeft: String?
        /// 左侧图标（别名）
        var icon: String?
        /// 右侧图标
        var iconRight: String?
        /// 图标尺寸
        var iconSize: CGFloat?
        /// 图标与文字间距
        var iconSpacing: CGFloat?
        /// 是否禁用
        @Default<False> var disabled: Bool
        /// 高亮状态标题颜色
        var titleColorHighlighted: ColorValue?
        /// 禁用状态标题颜色
        var titleColorDisabled: ColorValue?
        /// 高亮状态背景色
        var backgroundColorHighlighted: ColorValue?
        /// 禁用状态背景色
        var backgroundColorDisabled: ColorValue?
        
        /// 按钮标题（兼容 title 和 text）
        var buttonTitle: String? { title ?? text }
        
        /// 左侧图标（兼容 iconLeft 和 icon）
        var leftIcon: String? { iconLeft ?? icon }
    }
    
    // MARK: - Type Identifier
    
    override class var typeIdentifier: String { "button" }
    
    // MARK: - 事件回调
    
    var onClick: (() -> Void)?
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let button = TemplateXButton(type: .custom)
        button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        return button
    }
    
    override func didParseProps() {
        // 按钮默认裁剪
        style.clipsToBounds = true
    }
    
    override func configureView(_ view: TemplateXButton) {
        // 标题
        view.setTitle(props.buttonTitle, for: .normal)
        
        // 文字颜色 - 优先从 props 读取，其次从 style 读取
        let titleColor = props.titleColor?.color ?? style.textColor ?? .white
        view.setTitleColor(titleColor, for: .normal)
        view.setTitleColor(
            props.titleColorHighlighted?.color ?? titleColor.withAlphaComponent(0.7),
            for: .highlighted
        )
        view.setTitleColor(
            props.titleColorDisabled?.color ?? titleColor.withAlphaComponent(0.5),
            for: .disabled
        )
        
        // 字体 - 从 style 读取
        let fontSize = style.fontSize ?? 14
        let fontWeight = style.fontWeight.flatMap { FontWeightValue($0).weight } ?? .regular
        view.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        
        // 背景色
        view.normalBackgroundColor = style.backgroundColor
        view.highlightedBackgroundColor = props.backgroundColorHighlighted?.color
            ?? style.backgroundColor?.withAlphaComponent(0.8)
        view.disabledBackgroundColor = props.backgroundColorDisabled?.color
            ?? style.backgroundColor?.withAlphaComponent(0.5)
        
        // 状态
        view.isEnabled = !props.disabled
        
        // 图标间距（只在有图标时应用）
        if props.leftIcon != nil || props.iconRight != nil {
            let spacing = props.iconSpacing ?? 4
            view.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: spacing)
            view.titleEdgeInsets = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: 0)
        } else {
            view.imageEdgeInsets = .zero
            view.titleEdgeInsets = .zero
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        guard !props.disabled else { return }
        onClick?()
    }
    
    // MARK: - Public Methods
    
    /// 设置禁用状态
    func setDisabled(_ disabled: Bool) {
        props.disabled = disabled
        (view as? UIButton)?.isEnabled = !disabled
    }
}

// MARK: - TemplateXButton

/// 自定义按钮视图
/// 支持不同状态下的背景色变化
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
}
