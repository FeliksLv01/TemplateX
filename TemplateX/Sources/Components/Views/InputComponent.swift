import UIKit

// MARK: - Input 组件

/// 输入框组件
/// 支持单行/多行输入、placeholder、键盘类型等
public final class InputComponent: BaseComponent, ComponentFactory {
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "input" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = InputComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Properties
    
    /// 输入类型
    public enum InputType: String {
        case text
        case number
        case phone
        case email
        case password
        case multiline
    }
    
    /// 输入类型
    public var inputType: InputType = .text
    
    /// 占位文字
    public var placeholder: String?
    
    /// 占位文字颜色
    public var placeholderColor: UIColor = .placeholderText
    
    /// 当前文本
    public var text: String = ""
    
    /// 最大字符数
    public var maxLength: Int?
    
    /// 最大行数（多行模式）
    public var maxLines: Int = 0
    
    /// 是否禁用
    public var isDisabled: Bool = false
    
    /// 是否只读
    public var isReadOnly: Bool = false
    
    /// 自动大写类型
    public var autocapitalizationType: UITextAutocapitalizationType = .sentences
    
    /// 自动纠正
    public var autocorrectionType: UITextAutocorrectionType = .default
    
    /// 清除按钮模式
    public var clearButtonMode: UITextField.ViewMode = .whileEditing
    
    /// 返回键类型
    public var returnKeyType: UIReturnKeyType = .default
    
    // MARK: - 事件回调
    
    /// 文本变化
    public var onTextChange: ((String) -> Void)?
    
    /// 获得焦点
    public var onFocus: (() -> Void)?
    
    /// 失去焦点
    public var onBlur: (() -> Void)?
    
    /// 提交（按返回键）
    public var onSubmit: ((String) -> Void)?
    
    // MARK: - Private
    
    private weak var textField: UITextField?
    private weak var textView: UITextView?
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: InputComponent.typeIdentifier)
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        let cloned = InputComponent(id: self.id)
        cloned.jsonWrapper = self.jsonWrapper
        cloned.style = self.style.clone()
        cloned.events = self.events
        
        // 复制 Input 特有属性
        cloned.inputType = self.inputType
        cloned.placeholder = self.placeholder
        cloned.placeholderColor = self.placeholderColor
        cloned.text = self.text
        cloned.maxLength = self.maxLength
        cloned.maxLines = self.maxLines
        cloned.isDisabled = self.isDisabled
        cloned.isReadOnly = self.isReadOnly
        cloned.autocapitalizationType = self.autocapitalizationType
        cloned.autocorrectionType = self.autocorrectionType
        cloned.clearButtonMode = self.clearButtonMode
        cloned.returnKeyType = self.returnKeyType
        
        // 注意: 不在这里递归克隆子组件，由 RenderEngine.cloneComponentTree 统一处理
        
        return cloned
    }
    
    // MARK: - Parse
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
        
        // 输入框默认裁剪
        style.clipsToBounds = true
        
        // 解析输入特有属性
        if let props = json.props {
            parseInputProps(from: props)
        }
        
        // 解析事件
        if let eventsJson = json.events {
            events = eventsJson.rawDictionary
        }
    }
    
    private func parseInputProps(from props: JSONWrapper) {
        if let type = props.string("type") ?? props.string("inputType") {
            inputType = InputType(rawValue: type.lowercased()) ?? .text
        }
        
        placeholder = props.string("placeholder") ?? props.string("hint")
        placeholderColor = props.color("placeholderColor") ?? .placeholderText
        
        text = props.string("text") ?? props.string("value") ?? ""
        
        if let max = props.int("maxLength") {
            maxLength = max
        }
        
        maxLines = props.int("maxLines") ?? 0
        
        isDisabled = props.bool("disabled", default: false)
        isReadOnly = props.bool("readOnly", default: false)
        
        // 键盘相关
        if let returnType = props.string("returnKeyType") {
            returnKeyType = parseReturnKeyType(returnType)
        }
    }
    
    private func parseReturnKeyType(_ type: String) -> UIReturnKeyType {
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
    
    // MARK: - View
    
    public override func createView() -> UIView {
        if inputType == .multiline {
            return createTextView()
        } else {
            return createTextField()
        }
    }
    
    private func createTextField() -> UIView {
        // 优先从视图池获取
        let textField: TemplateXTextField
        if let recycled = ViewRecyclePool.shared.dequeueView(forType: "input") as? TemplateXTextField {
            textField = recycled
            TXLogger.verbose("InputComponent: reused TextField from pool")
        } else {
            textField = TemplateXTextField()
            TXLogger.verbose("InputComponent: created new TextField")
        }
        
        configureTextField(textField)
        
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        textField.delegate = textField
        textField.component = self
        
        self.textField = textField
        self.view = textField
        return textField
    }
    
    private func createTextView() -> UIView {
        let container = UIView()
        
        // 优先从视图池获取
        let textView: TemplateXTextView
        if let recycled = ViewRecyclePool.shared.dequeueView(forType: "input_multiline") as? TemplateXTextView {
            textView = recycled
            TXLogger.verbose("InputComponent: reused TextView from pool")
        } else {
            textView = TemplateXTextView()
            TXLogger.verbose("InputComponent: created new TextView")
        }
        
        configureTextView(textView)
        
        textView.delegate = textView
        textView.component = self
        
        container.addSubview(textView)
        textView.frame = container.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.textView = textView
        self.view = container
        return container
    }
    
    private func configureTextField(_ textField: UITextField) {
        textField.text = text
        
        // 从 style 读取文字样式
        textField.textColor = style.textColor ?? .label
        let fontSize = style.fontSize ?? 14
        let fontWeight = parseFontWeight(style.fontWeight)
        textField.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        
        // Placeholder
        if let placeholder = placeholder {
            textField.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
        
        // 键盘类型
        textField.keyboardType = keyboardType(for: inputType)
        textField.isSecureTextEntry = inputType == .password
        
        // 其他设置
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType
        textField.clearButtonMode = clearButtonMode
        textField.returnKeyType = returnKeyType
        
        textField.isEnabled = !isDisabled && !isReadOnly
        
        // 内边距 - 从 style 读取
        let padding = style.padding
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: padding.left, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: padding.right, height: 1))
        textField.rightViewMode = .always
    }
    
    private func configureTextView(_ textView: UITextView) {
        textView.text = text
        
        // 从 style 读取文字样式
        textView.textColor = style.textColor ?? .label
        let fontSize = style.fontSize ?? 14
        let fontWeight = parseFontWeight(style.fontWeight)
        textView.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        
        // 内边距 - 从 style 读取
        let padding = style.padding
        textView.textContainerInset = UIEdgeInsets(
            top: padding.top,
            left: padding.left,
            bottom: padding.bottom,
            right: padding.right
        )
        
        textView.keyboardType = keyboardType(for: inputType)
        textView.autocapitalizationType = autocapitalizationType
        textView.autocorrectionType = autocorrectionType
        textView.returnKeyType = returnKeyType
        
        textView.isEditable = !isDisabled && !isReadOnly
        
        // Placeholder - 使用 TemplateXTextView 的内置 placeholder 功能
        if let templateXTextView = textView as? TemplateXTextView {
            templateXTextView.placeholder = placeholder
            templateXTextView.placeholderColor = placeholderColor
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
    
    public override func updateView() {
        if let textField = textField {
            configureTextField(textField)
        }
        if let textView = textView {
            configureTextView(textView)
        }
        super.updateView()
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        let newText = textField.text ?? ""
        
        // 检查最大长度
        if let maxLength = maxLength, newText.count > maxLength {
            textField.text = String(newText.prefix(maxLength))
            return
        }
        
        text = textField.text ?? ""
        onTextChange?(text)
    }
    
    // MARK: - Public Methods
    
    /// 获取当前文本
    public func getText() -> String {
        return textField?.text ?? textView?.text ?? text
    }
    
    /// 设置文本
    public func setText(_ newText: String) {
        text = newText
        textField?.text = newText
        textView?.text = newText
    }
    
    /// 获取焦点
    public func focus() {
        textField?.becomeFirstResponder()
        textView?.becomeFirstResponder()
    }
    
    /// 失去焦点
    public func blur() {
        textField?.resignFirstResponder()
        textView?.resignFirstResponder()
    }
    
    /// 清空文本
    public func clear() {
        setText("")
        onTextChange?("")
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
        guard let maxLength = component?.maxLength else { return true }
        
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
        if let maxLength = component?.maxLength, newText.count > maxLength {
            textView.text = String(newText.prefix(maxLength))
            return
        }
        
        component?.text = textView.text ?? ""
        component?.onTextChange?(textView.text ?? "")
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        component?.onFocus?()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        component?.onBlur?()
    }
}
