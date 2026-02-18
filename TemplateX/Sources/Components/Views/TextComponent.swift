import UIKit

// MARK: - Text 组件

/// 文本组件
public final class TextComponent: BaseComponent, ComponentFactory {
    
    // MARK: - 文本属性
    
    public var text: String = ""
    public var fontSize: CGFloat = 14
    public var fontWeight: UIFont.Weight = .regular
    public var textColor: UIColor = .black
    public var textAlignment: NSTextAlignment = .left
    public var numberOfLines: Int = 0
    public var lineBreakMode: NSLineBreakMode = .byTruncatingTail
    public var lineHeight: CGFloat?
    public var letterSpacing: CGFloat?
    
    // MARK: - 缓存（性能优化）
    
    /// 缓存的字体（避免重复创建 UIFont）
    private var _cachedFont: UIFont?
    private var _cachedFontSize: CGFloat = 0
    private var _cachedFontWeight: UIFont.Weight = .regular
    
    /// 获取或创建字体（带缓存）
    private func getFont() -> UIFont {
        if let cached = _cachedFont, _cachedFontSize == fontSize, _cachedFontWeight == fontWeight {
            return cached
        }
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        _cachedFont = font
        _cachedFontSize = fontSize
        _cachedFontWeight = fontWeight
        return font
    }
    
    /// 上次应用的文本属性（用于脏检查）
    private var _lastAppliedText: String?
    private var _lastAppliedTextColor: UIColor?
    private var _lastAppliedTextAlignment: NSTextAlignment?
    private var _lastAppliedNumberOfLines: Int?
    private var _lastAppliedLineBreakMode: NSLineBreakMode?
    private var _lastAppliedLineHeight: CGFloat?
    private var _lastAppliedLetterSpacing: CGFloat?
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "text" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = TextComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: TextComponent.typeIdentifier)
    }
    
    // MARK: - Parse
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
        
        // 解析文本特有属性（从 style 和 props 中读取）
        parseTextFromStyle()
        
        if let props = json.props {
            parseTextProps(from: props)
        }
    }
    
    /// 从 style 中解析文本属性
    private func parseTextFromStyle() {
        // fontSize 和 textColor 现在在 style 中
        if let fs = style.fontSize, fs > 0 {
            fontSize = fs
        }
        if let color = style.textColor {
            textColor = color
        }
        if let align = style.textAlign {
            textAlignment = align.toNSTextAlignment()
        }
        if let weight = style.fontWeight {
            fontWeight = parseFontWeight(weight)
        }
        if let lines = style.numberOfLines {
            numberOfLines = lines
        }
        if let lh = style.lineHeight {
            lineHeight = lh
        }
        if let ls = style.letterSpacing {
            letterSpacing = ls
        }
    }
    
    private func parseTextProps(from props: JSONWrapper) {
        // 文本内容
        if let t = props.string("text") { text = t }
        
        // 字体大小（props 优先级高于 style）
        if let size = props.cgFloat("fontSize") {
            fontSize = size
        }
        
        // 字重
        if let weight = props.string("fontWeight") {
            fontWeight = parseFontWeight(weight)
        } else if let weight = props.int("fontWeight") {
            fontWeight = parseFontWeight(weight)
        }
        
        // 颜色（props 优先级高于 style）
        if let color = props.color("color") ?? props.color("textColor") {
            textColor = color
        }
        
        // 对齐
        if let align = props.string("textAlign") ?? props.string("textAlignment") {
            textAlignment = parseTextAlignment(align)
        }
        
        // 行数
        if let lines = props.int("lines") ?? props.int("numberOfLines") {
            numberOfLines = lines
        }
        
        // 截断模式
        if let mode = props.string("ellipsize") ?? props.string("lineBreakMode") {
            lineBreakMode = parseLineBreakMode(mode)
        }
        
        // 行高
        if let lh = props.cgFloat("lineHeight") {
            lineHeight = lh
        }
        
        // 字间距
        if let ls = props.cgFloat("letterSpacing") {
            letterSpacing = ls
        }
    }
    
    // MARK: - View
    
    public override func createView() -> UIView {
        let label = UILabel()
        label.backgroundColor = .clear  // 确保背景透明
        label.numberOfLines = numberOfLines
        label.lineBreakMode = lineBreakMode
        self.view = label
        return label
    }
    
    public override func updateView() {
        super.updateView()
        
        guard let label = view as? UILabel else { return }
        
        // 使用脏检查优化：只更新变化的属性
        let needsFullUpdate = forceApplyStyle || _lastAppliedText == nil
        
        // 文本内容
        if needsFullUpdate || _lastAppliedText != text {
            label.text = text
            _lastAppliedText = text
        }
        
        // 文本颜色
        if needsFullUpdate || _lastAppliedTextColor != textColor {
            label.textColor = textColor
            _lastAppliedTextColor = textColor
        }
        
        // 文本对齐
        if needsFullUpdate || _lastAppliedTextAlignment != textAlignment {
            label.textAlignment = textAlignment
            _lastAppliedTextAlignment = textAlignment
        }
        
        // 行数
        if needsFullUpdate || _lastAppliedNumberOfLines != numberOfLines {
            label.numberOfLines = numberOfLines
            _lastAppliedNumberOfLines = numberOfLines
        }
        
        // 截断模式
        if needsFullUpdate || _lastAppliedLineBreakMode != lineBreakMode {
            label.lineBreakMode = lineBreakMode
            _lastAppliedLineBreakMode = lineBreakMode
        }
        
        // 字体（使用缓存）
        if needsFullUpdate || _cachedFontSize != fontSize || _cachedFontWeight != fontWeight {
            label.font = getFont()
        }
        
        // 富文本属性（行高或字间距）
        let hasRichTextAttributes = lineHeight != nil || letterSpacing != nil
        let richTextChanged = _lastAppliedLineHeight != lineHeight || _lastAppliedLetterSpacing != letterSpacing
        
        if hasRichTextAttributes && (needsFullUpdate || richTextChanged) {
            applyAttributedText(to: label)
            _lastAppliedLineHeight = lineHeight
            _lastAppliedLetterSpacing = letterSpacing
        }
    }
    
    private func applyAttributedText(to label: UILabel) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: getFont(),
            .foregroundColor: textColor
        ]
        
        // 行高
        if let lh = lineHeight {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.minimumLineHeight = lh
            paragraphStyle.maximumLineHeight = lh
            paragraphStyle.alignment = textAlignment
            attributes[.paragraphStyle] = paragraphStyle
        }
        
        // 字间距
        if let ls = letterSpacing {
            attributes[.kern] = ls
        }
        
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        // 使用原 id，确保 Diff 算法能正确匹配组件
        let cloned = TextComponent(id: self.id)
        // 复制基础属性
        cloned.style = self.style
        cloned.bindings = self.bindings
        cloned.events = self.events
        cloned.jsonWrapper = self.jsonWrapper
        // 复制文本特有属性
        cloned.text = self.text
        cloned.fontSize = self.fontSize
        cloned.fontWeight = self.fontWeight
        cloned.textColor = self.textColor
        cloned.textAlignment = self.textAlignment
        cloned.numberOfLines = self.numberOfLines
        cloned.lineBreakMode = self.lineBreakMode
        cloned.lineHeight = self.lineHeight
        cloned.letterSpacing = self.letterSpacing
        return cloned
    }
    
    // MARK: - Diff
    
    public override func needsUpdate(with other: Component) -> Bool {
        guard let otherText = other as? TextComponent else { return true }
        
        if text != otherText.text { return true }
        if fontSize != otherText.fontSize { return true }
        if fontWeight != otherText.fontWeight { return true }
        if textColor != otherText.textColor { return true }
        if textAlignment != otherText.textAlignment { return true }
        if numberOfLines != otherText.numberOfLines { return true }
        
        return super.needsUpdate(with: other)
    }
    
    // MARK: - Parse Helpers
    
    private func parseFontWeight(_ str: String) -> UIFont.Weight {
        switch str.lowercased() {
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
    
    private func parseFontWeight(_ num: Int) -> UIFont.Weight {
        switch num {
        case 100: return .thin
        case 200: return .ultraLight
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default: return .regular
        }
    }
    
    private func parseTextAlignment(_ str: String) -> NSTextAlignment {
        switch str.lowercased() {
        case "left", "start": return .left
        case "center": return .center
        case "right", "end": return .right
        case "justified", "justify": return .justified
        default: return .left
        }
    }
    
    private func parseLineBreakMode(_ str: String) -> NSLineBreakMode {
        switch str.lowercased() {
        case "end", "tail", "truncatingtail": return .byTruncatingTail
        case "start", "head", "truncatinghead": return .byTruncatingHead
        case "middle", "truncatingmiddle": return .byTruncatingMiddle
        case "wrap", "wordwrap", "wordwrapping": return .byWordWrapping
        case "char", "charwrap", "charwrapping": return .byCharWrapping
        case "clip", "clipping": return .byClipping
        default: return .byTruncatingTail
        }
    }
}
