import UIKit

// MARK: - Text 组件

/// 文本组件
final class TextComponent: TemplateXComponent<UILabel, TextComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        var text: String = ""
        var fontSize: CGFloat?
        var fontWeight: String?
        var color: String?
        var textAlign: String?
        var numberOfLines: Int?
        var lineBreakMode: String?
        var lineHeight: CGFloat?
        var letterSpacing: CGFloat?
        
        // CodingKeys 处理别名
        enum CodingKeys: String, CodingKey {
            case text, fontSize, fontWeight, color, textColor
            case textAlign, textAlignment, numberOfLines, lines
            case lineBreakMode, ellipsize, lineHeight, letterSpacing
        }
        
        init() {}
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
            fontSize = try c.decodeIfPresent(CGFloat.self, forKey: .fontSize)
            fontWeight = try c.decodeIfPresent(String.self, forKey: .fontWeight)
            // 处理别名：优先 color，其次 textColor
            if let colorVal = try c.decodeIfPresent(String.self, forKey: .color) {
                color = colorVal
            } else {
                color = try c.decodeIfPresent(String.self, forKey: .textColor)
            }
            // 处理别名：优先 textAlign，其次 textAlignment
            if let alignVal = try c.decodeIfPresent(String.self, forKey: .textAlign) {
                textAlign = alignVal
            } else {
                textAlign = try c.decodeIfPresent(String.self, forKey: .textAlignment)
            }
            // 处理别名：优先 numberOfLines，其次 lines
            if let linesVal = try c.decodeIfPresent(Int.self, forKey: .numberOfLines) {
                numberOfLines = linesVal
            } else {
                numberOfLines = try c.decodeIfPresent(Int.self, forKey: .lines)
            }
            // 处理别名：优先 lineBreakMode，其次 ellipsize
            if let modeVal = try c.decodeIfPresent(String.self, forKey: .lineBreakMode) {
                lineBreakMode = modeVal
            } else {
                lineBreakMode = try c.decodeIfPresent(String.self, forKey: .ellipsize)
            }
            lineHeight = try c.decodeIfPresent(CGFloat.self, forKey: .lineHeight)
            letterSpacing = try c.decodeIfPresent(CGFloat.self, forKey: .letterSpacing)
        }
        
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(text, forKey: .text)
            try c.encodeIfPresent(fontSize, forKey: .fontSize)
            try c.encodeIfPresent(fontWeight, forKey: .fontWeight)
            try c.encodeIfPresent(color, forKey: .color)
            try c.encodeIfPresent(textAlign, forKey: .textAlign)
            try c.encodeIfPresent(numberOfLines, forKey: .numberOfLines)
            try c.encodeIfPresent(lineBreakMode, forKey: .lineBreakMode)
            try c.encodeIfPresent(lineHeight, forKey: .lineHeight)
            try c.encodeIfPresent(letterSpacing, forKey: .letterSpacing)
        }
    }
    
    // MARK: - ComponentFactory
    
    override class var typeIdentifier: String { "text" }
    
    // MARK: - 便捷属性访问器（供 DataBindingManager 等外部使用）
    
    var text: String {
        get { props.text }
        set { props.text = newValue }
    }
    
    var fontSize: CGFloat? {
        get { props.fontSize }
        set { props.fontSize = newValue }
    }
    
    var fontWeight: String? {
        get { props.fontWeight }
        set { props.fontWeight = newValue }
    }
    
    var textColor: UIColor? {
        get { parseColor(props.color) }
        set { props.color = newValue?.hexString }
    }
    
    var textAlignment: NSTextAlignment {
        get { parseTextAlignment(props.textAlign) ?? .left }
        set { props.textAlign = textAlignmentToString(newValue) }
    }
    
    var numberOfLines: Int {
        get { props.numberOfLines ?? 0 }
        set { props.numberOfLines = newValue }
    }
    
    var lineBreakMode: NSLineBreakMode {
        get { parseLineBreakMode(props.lineBreakMode) }
        set { props.lineBreakMode = lineBreakModeToString(newValue) }
    }
    
    var lineHeight: CGFloat? {
        get { props.lineHeight }
        set { props.lineHeight = newValue }
    }
    
    var letterSpacing: CGFloat? {
        get { props.letterSpacing }
        set { props.letterSpacing = newValue }
    }
    
    // MARK: - 缓存（性能优化）
    
    private var _cachedFont: UIFont?
    private var _cachedFontSize: CGFloat = 0
    private var _cachedFontWeight: UIFont.Weight = .regular
    private var _lastProps: Props?
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let label = UILabel()
        label.backgroundColor = .clear
        self.view = label
        return label
    }
    
    override func configureView(_ view: UILabel) {
        // 脏检查：只在 props 变化时更新
        guard forceApplyStyle || _lastProps != props else { return }
        _lastProps = props
        
        // 基础属性
        view.text = props.text
        view.numberOfLines = props.numberOfLines ?? 0
        view.lineBreakMode = parseLineBreakMode(props.lineBreakMode)
        
        // 颜色：props > style > 默认
        view.textColor = parseColor(props.color) ?? style.textColor ?? .black
        
        // 对齐：props > style > 默认
        view.textAlignment = parseTextAlignment(props.textAlign) ?? style.textAlign?.toNSTextAlignment() ?? .left
        
        // 字体
        view.font = getFont()
        
        // 富文本属性（行高/字间距）
        if props.lineHeight != nil || props.letterSpacing != nil {
            applyAttributedText(to: view)
        }
    }
    
    override func didParseProps() {
        // 从 style 补充缺失的属性
        if props.fontSize == nil, let fs = style.fontSize {
            props.fontSize = fs
        }
        if props.fontWeight == nil, let fw = style.fontWeight {
            props.fontWeight = fw
        }
        if props.color == nil, style.textColor != nil {
            // textColor 已经在 style 中，configureView 会处理
        }
        if props.numberOfLines == nil, let lines = style.numberOfLines {
            props.numberOfLines = lines
        }
        if props.lineHeight == nil, let lh = style.lineHeight {
            props.lineHeight = lh
        }
        if props.letterSpacing == nil, let ls = style.letterSpacing {
            props.letterSpacing = ls
        }
    }
    
    // MARK: - Private
    
    private func getFont() -> UIFont {
        let size = props.fontSize ?? style.fontSize ?? 14
        let weight = parseFontWeight(props.fontWeight ?? style.fontWeight)
        
        // 缓存优化
        if let cached = _cachedFont, _cachedFontSize == size, _cachedFontWeight == weight {
            return cached
        }
        
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        _cachedFont = font
        _cachedFontSize = size
        _cachedFontWeight = weight
        return font
    }
    
    private func applyAttributedText(to label: UILabel) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: getFont(),
            .foregroundColor: label.textColor ?? .black
        ]
        
        // 行高
        if let lh = props.lineHeight ?? style.lineHeight {
            let paragraphStyle = NSMutableParagraphStyle()
            // lineHeight 解析：
            // - 如果 <= 4，认为是倍数（如 1.3 表示 1.3 倍行高）
            // - 如果 > 4，认为是像素值（如 20 表示 20pt 行高）
            let fontSize = props.fontSize ?? style.fontSize ?? 14
            let actualLineHeight: CGFloat
            if lh <= 4 {
                actualLineHeight = fontSize * lh
            } else {
                actualLineHeight = lh
            }
            paragraphStyle.minimumLineHeight = actualLineHeight
            paragraphStyle.maximumLineHeight = actualLineHeight
            paragraphStyle.alignment = label.textAlignment
            attributes[.paragraphStyle] = paragraphStyle
        }
        
        // 字间距
        if let ls = props.letterSpacing ?? style.letterSpacing {
            attributes[.kern] = ls
        }
        
        label.attributedText = NSAttributedString(string: props.text, attributes: attributes)
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
    
    private func parseTextAlignment(_ str: String?) -> NSTextAlignment? {
        guard let str = str else { return nil }
        switch str.lowercased() {
        case "left", "start": return .left
        case "center": return .center
        case "right", "end": return .right
        case "justified", "justify": return .justified
        default: return nil
        }
    }
    
    private func parseLineBreakMode(_ str: String?) -> NSLineBreakMode {
        guard let str = str else { return .byTruncatingTail }
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
    
    private func textAlignmentToString(_ alignment: NSTextAlignment) -> String {
        switch alignment {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .justified: return "justified"
        case .natural: return "left"
        @unknown default: return "left"
        }
    }
    
    private func lineBreakModeToString(_ mode: NSLineBreakMode) -> String {
        switch mode {
        case .byTruncatingTail: return "tail"
        case .byTruncatingHead: return "head"
        case .byTruncatingMiddle: return "middle"
        case .byWordWrapping: return "wordwrap"
        case .byCharWrapping: return "charwrap"
        case .byClipping: return "clip"
        @unknown default: return "tail"
        }
    }
}
