import UIKit

// MARK: - 强类型值包装
// 用于 Props 中自动解析 JSON 字符串到 UIKit 类型

// MARK: - ColorValue

/// 颜色值（自动从 hex string 解析）
///
/// 支持格式：
/// - `"#RGB"` / `"#RRGGBB"` / `"#AARRGGBB"`
/// - `"rgb(255, 0, 0)"` / `"rgba(255, 0, 0, 0.5)"`
///
/// 用法：
/// ```swift
/// struct Props: ComponentProps {
///     var textColor: ColorValue?
/// }
/// // JSON: { "textColor": "#FF0000" }
/// // 使用: props.textColor?.color ?? .black
/// ```
public struct ColorValue: Codable, Equatable, Hashable {
    public let color: UIColor?
    
    public init(_ color: UIColor?) {
        self.color = color
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.color = UIColor(hexString: string)
        } else {
            self.color = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(color?.hexString)
    }
    
    public static func == (lhs: ColorValue, rhs: ColorValue) -> Bool {
        // UIColor 比较需要转换到相同色彩空间
        guard let lhsColor = lhs.color, let rhsColor = rhs.color else {
            return lhs.color == nil && rhs.color == nil
        }
        var lhsR: CGFloat = 0, lhsG: CGFloat = 0, lhsB: CGFloat = 0, lhsA: CGFloat = 0
        var rhsR: CGFloat = 0, rhsG: CGFloat = 0, rhsB: CGFloat = 0, rhsA: CGFloat = 0
        lhsColor.getRed(&lhsR, green: &lhsG, blue: &lhsB, alpha: &lhsA)
        rhsColor.getRed(&rhsR, green: &rhsG, blue: &rhsB, alpha: &rhsA)
        return lhsR == rhsR && lhsG == rhsG && lhsB == rhsB && lhsA == rhsA
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(color?.hexString)
    }
}

// MARK: - FontWeightValue

/// 字重值（自动从 string 解析）
///
/// 支持格式：
/// - 数字：`"100"` ~ `"900"`
/// - 名称：`"thin"`, `"light"`, `"regular"`, `"medium"`, `"semibold"`, `"bold"`, `"heavy"`, `"black"`
///
/// 用法：
/// ```swift
/// struct Props: ComponentProps {
///     var fontWeight: FontWeightValue?
/// }
/// // JSON: { "fontWeight": "bold" }
/// // 使用: props.fontWeight?.weight ?? .regular
/// ```
public struct FontWeightValue: Codable, Equatable, Hashable {
    public let weight: UIFont.Weight
    
    public init(_ weight: UIFont.Weight = .regular) {
        self.weight = weight
    }
    
    /// 从字符串解析字重（便捷初始化器）
    /// 用于从 ComponentStyle.fontWeight (String?) 创建 FontWeightValue
    public init(_ string: String?) {
        self.weight = Self.parse(string)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.weight = Self.parse(string)
        } else if let number = try? container.decode(Int.self) {
            self.weight = Self.parse(String(number))
        } else {
            self.weight = .regular
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.toString(weight))
    }
    
    private static func parse(_ str: String?) -> UIFont.Weight {
        guard let str = str?.lowercased() else { return .regular }
        switch str {
        case "thin", "100": return .thin
        case "ultralight", "extralight", "200": return .ultraLight
        case "light", "300": return .light
        case "regular", "normal", "400": return .regular
        case "medium", "500": return .medium
        case "semibold", "demibold", "600": return .semibold
        case "bold", "700": return .bold
        case "heavy", "extrabold", "800": return .heavy
        case "black", "900": return .black
        default: return .regular
        }
    }
    
    private static func toString(_ weight: UIFont.Weight) -> String {
        switch weight {
        case .thin: return "100"
        case .ultraLight: return "200"
        case .light: return "300"
        case .regular: return "400"
        case .medium: return "500"
        case .semibold: return "600"
        case .bold: return "700"
        case .heavy: return "800"
        case .black: return "900"
        default: return "400"
        }
    }
}

// MARK: - TextAlignValue

/// 文本对齐值
///
/// 支持格式：`"left"`, `"center"`, `"right"`, `"justified"`, `"start"`, `"end"`
public struct TextAlignValue: Codable, Equatable, Hashable {
    public let alignment: NSTextAlignment
    
    public init(_ alignment: NSTextAlignment = .left) {
        self.alignment = alignment
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.alignment = Self.parse(string)
        } else {
            self.alignment = .left
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.toString(alignment))
    }
    
    private static func parse(_ str: String?) -> NSTextAlignment {
        guard let str = str?.lowercased() else { return .left }
        switch str {
        case "left", "start": return .left
        case "center": return .center
        case "right", "end": return .right
        case "justified", "justify": return .justified
        case "natural": return .natural
        default: return .left
        }
    }
    
    private static func toString(_ alignment: NSTextAlignment) -> String {
        switch alignment {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .justified: return "justified"
        case .natural: return "natural"
        @unknown default: return "left"
        }
    }
}

// MARK: - ContentModeValue

/// 内容模式值（图片缩放方式）
///
/// 支持格式：
/// - `"fill"`, `"fit"`, `"cover"`, `"center"`
/// - `"scaleToFill"`, `"scaleAspectFit"`, `"scaleAspectFill"`
/// - `"top"`, `"bottom"`, `"left"`, `"right"`
public struct ContentModeValue: Codable, Equatable, Hashable {
    public let mode: UIView.ContentMode
    
    public init(_ mode: UIView.ContentMode = .scaleAspectFill) {
        self.mode = mode
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.mode = Self.parse(string)
        } else {
            self.mode = .scaleAspectFill
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.toString(mode))
    }
    
    private static func parse(_ str: String?) -> UIView.ContentMode {
        guard let str = str?.lowercased() else { return .scaleAspectFill }
        switch str {
        case "fill", "scaletofill": return .scaleToFill
        case "fit", "aspectfit", "scaleaspectfit": return .scaleAspectFit
        case "cover", "aspectfill", "scaleaspectfill", "centercrop": return .scaleAspectFill
        case "center": return .center
        case "top": return .top
        case "bottom": return .bottom
        case "left": return .left
        case "right": return .right
        case "topleft": return .topLeft
        case "topright": return .topRight
        case "bottomleft": return .bottomLeft
        case "bottomright": return .bottomRight
        default: return .scaleAspectFill
        }
    }
    
    private static func toString(_ mode: UIView.ContentMode) -> String {
        switch mode {
        case .scaleToFill: return "fill"
        case .scaleAspectFit: return "fit"
        case .scaleAspectFill: return "cover"
        case .center: return "center"
        case .top: return "top"
        case .bottom: return "bottom"
        case .left: return "left"
        case .right: return "right"
        case .topLeft: return "topLeft"
        case .topRight: return "topRight"
        case .bottomLeft: return "bottomLeft"
        case .bottomRight: return "bottomRight"
        case .redraw: return "redraw"
        @unknown default: return "cover"
        }
    }
}

// MARK: - LineBreakModeValue

/// 换行模式值
///
/// 支持格式：
/// - `"tail"`, `"head"`, `"middle"`, `"clip"`
/// - `"wordwrap"`, `"charwrap"`
/// - `"truncatingTail"`, `"truncatingHead"`, `"truncatingMiddle"`
public struct LineBreakModeValue: Codable, Equatable, Hashable {
    public let mode: NSLineBreakMode
    
    public init(_ mode: NSLineBreakMode = .byTruncatingTail) {
        self.mode = mode
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.mode = Self.parse(string)
        } else {
            self.mode = .byTruncatingTail
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.toString(mode))
    }
    
    private static func parse(_ str: String?) -> NSLineBreakMode {
        guard let str = str?.lowercased() else { return .byTruncatingTail }
        switch str {
        case "tail", "end", "truncatingtail": return .byTruncatingTail
        case "head", "start", "truncatinghead": return .byTruncatingHead
        case "middle", "truncatingmiddle": return .byTruncatingMiddle
        case "wordwrap", "wrap", "wordwrapping", "bywordwrapping": return .byWordWrapping
        case "charwrap", "char", "charwrapping", "bycharwrapping": return .byCharWrapping
        case "clip", "clipping", "byclipping": return .byClipping
        default: return .byTruncatingTail
        }
    }
    
    private static func toString(_ mode: NSLineBreakMode) -> String {
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
