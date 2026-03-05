import UIKit

// MARK: - Input 组件

/// 输入框组件
/// 支持单行/多行输入、placeholder、键盘类型等
///
/// Props 只包含内容属性，文本样式统一从 style 读取：
/// - style.fontSize, style.fontWeight, style.textColor
final class InputComponent: TemplateXComponent<UIView, InputComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        @Default<TextInput> var inputType: String
        var placeholder: String?
        var placeholderColor: ColorValue?  // 使用强类型
        var text: String?
        var value: String?  // 别名
        var maxLength: Int?
        var maxLines: Int?
        @Default<False> var disabled: Bool
        @Default<False> var readOnly: Bool
        var returnKeyType: String?
        
        // 计算属性
        var resolvedText: String {
            text ?? value ?? ""
        }
        
        var resolvedInputType: InputType {
            InputType(rawValue: inputType.lowercased()) ?? .text
        }
    }
    
    // MARK: - ComponentFactory
    
    override class var typeIdentifier: String { "input" }
    
    // MARK: - 输入类型枚举
    
    enum InputType: String {
        case text
        case number
        case phone
        case email
        case password
        case multiline
    }
    
    // MARK: - 运行时属性
    
    /// 当前文本（运行时状态）
    var currentText: String = ""
    
    // MARK: - 事件回调
    
    /// 文本变化
    var onTextChange: ((String) -> Void)?
    
    /// 获得焦点
    var onFocus: (() -> Void)?
    
    /// 失去焦点
    var onBlur: (() -> Void)?
    
    /// 提交（按返回键）
    var onSubmit: ((String) -> Void)?
    
    // MARK: - Private
    
    private weak var textField: UITextField?
    private weak var textView: UITextView?
    
    // MARK: - Lifecycle
    
    override func didParseProps() {
        currentText = props.resolvedText
        // 输入框默认裁剪
        style.clipsToBounds = true
    }
    
    // MARK: - View
    
    override func createView() -> UIView {
        if props.resolvedInputType == .multiline {
            return createTextView()
        } else {
            return createTextField()
        }
    }
    
    private func createTextField() -> UIView {
        let textField = TemplateXTextField()
        
        configureTextField(textField)
        
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        textField.delegate = textField
        textField.component = self
        
        self.textField = textField
        return textField
    }
    
    private func createTextView() -> UIView {
        let container = UIView()
        
        let textView = TemplateXTextView()
        
        configureTextView(textView)
        
        textView.delegate = textView
        textView.component = self
        
        container.addSubview(textView)
        textView.frame = container.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.textView = textView
        return container
    }
    
    override func configureView(_ view: UIView) {
        // 由于 createView 已经配置了视图，这里只处理更新
        if let textField = self.textField {
            configureTextField(textField)
        }
        if let textView = self.textView {
            configureTextView(textView)
        }
    }
    
    private func configureTextField(_ textField: UITextField) {
        textField.text = currentText
        
        // 从 style 读取文字样式
        textField.textColor = style.textColor ?? .label
        let fontSize = style.fontSize ?? 14
        let fontWeight = FontWeightValue(style.fontWeight).weight
        textField.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        
        // Placeholder
        if let placeholder = props.placeholder {
            let placeholderColor = props.placeholderColor?.color ?? .placeholderText
            textField.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
        
        // 键盘类型
        textField.keyboardType = keyboardType(for: props.resolvedInputType)
        textField.isSecureTextEntry = props.resolvedInputType == .password
        
        // 返回键类型
        textField.returnKeyType = parseReturnKeyType(props.returnKeyType)
        
        // 启用状态
        textField.isEnabled = !props.disabled && !props.readOnly
        
        // 内边距 - 从 style 读取
        let padding = style.padding
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: padding.left, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: padding.right, height: 1))
        textField.rightViewMode = .always
    }
    
    private func configureTextView(_ textView: UITextView) {
        textView.text = currentText
        
        // 从 style 读取文字样式
        textView.textColor = style.textColor ?? .label
        let fontSize = style.fontSize ?? 14
        let fontWeight = FontWeightValue(style.fontWeight).weight
        textView.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        
        // 内边距 - 从 style 读取
        let padding = style.padding
        textView.textContainerInset = UIEdgeInsets(
            top: padding.top,
            left: padding.left,
            bottom: padding.bottom,
            right: padding.right
        )
        
        textView.keyboardType = keyboardType(for: props.resolvedInputType)
        textView.returnKeyType = parseReturnKeyType(props.returnKeyType)
        
        // 启用状态
        textView.isEditable = !props.disabled && !props.readOnly
        
        // Placeholder - 使用 TemplateXTextView 的内置 placeholder 功能
        if let templateXTextView = textView as? TemplateXTextView {
            templateXTextView.placeholder = props.placeholder
            templateXTextView.placeholderColor = props.placeholderColor?.color ?? .placeholderText
        }
    }
    
    private func keyboardType(for inputType: InputType) -> UIKeyboardType {
        switch inputType {
        case .text, .password, .multiline:
            return .default
        case .number:
            return .numberPad
        case .phone:
            return .phonePad
        case .email:
            return .emailAddress
        }
    }
    
    private func parseReturnKeyType(_ type: String?) -> UIReturnKeyType {
        guard let type = type else { return .default }
        switch type.lowercased() {
        case "go": return .go
        case "next": return .next
        case "search": return .search
        case "send": return .send
        case "done": return .done
        case "join": return .join
        default: return .default
        }
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        let newText = textField.text ?? ""
        
        // 检查最大长度
        if let maxLength = props.maxLength, newText.count > maxLength {
            textField.text = String(newText.prefix(maxLength))
            return
        }
        
        currentText = textField.text ?? ""
        onTextChange?(currentText)
    }
    
    // MARK: - Public Methods
    
    /// 获取当前文本
    func getText() -> String {
        return textField?.text ?? textView?.text ?? currentText
    }
    
    /// 设置文本
    func setText(_ newText: String) {
        currentText = newText
        textField?.text = newText
        textView?.text = newText
    }
    
    /// 获取焦点
    func focus() {
        textField?.becomeFirstResponder()
        textView?.becomeFirstResponder()
    }
    
    /// 失去焦点
    func blur() {
        textField?.resignFirstResponder()
        textView?.resignFirstResponder()
    }
    
    /// 清空文本
    func clear() {
        setText("")
        onTextChange?("")
    }
}

// MARK: - TemplateXTextField

/// 自定义输入框
class TemplateXTextField: UITextField, UITextFieldDelegate {
    
    weak var component: InputComponent?
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        component?.onFocus?()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        component?.onBlur?()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        component?.onSubmit?(textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let maxLength = component?.props.maxLength else { return true }
        
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        return updatedText.count <= maxLength
    }
}

// MARK: - TemplateXTextView

/// 自定义多行输入框
class TemplateXTextView: UITextView, UITextViewDelegate {
    
    weak var component: InputComponent?
    
    /// 占位文字
    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
            updatePlaceholder()
        }
    }
    
    /// 占位文字颜色
    var placeholderColor: UIColor = .placeholderText {
        didSet {
            placeholderLabel.textColor = placeholderColor
        }
    }
    
    /// 占位标签
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.textColor = placeholderColor
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupPlaceholder()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlaceholder()
    }
    
    private func setupPlaceholder() {
        addSubview(placeholderLabel)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.frame = CGRect(
            x: textContainerInset.left + textContainer.lineFragmentPadding,
            y: textContainerInset.top,
            width: bounds.width - textContainerInset.left - textContainerInset.right - textContainer.lineFragmentPadding * 2,
            height: bounds.height - textContainerInset.top - textContainerInset.bottom
        )
        placeholderLabel.font = font
    }
    
    private func updatePlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        
        let newText = textView.text ?? ""
        
        // 检查最大长度
        if let maxLength = component?.props.maxLength, newText.count > maxLength {
            textView.text = String(newText.prefix(maxLength))
            return
        }
        
        component?.currentText = textView.text ?? ""
        component?.onTextChange?(textView.text ?? "")
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        component?.onFocus?()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        component?.onBlur?()
    }
}
