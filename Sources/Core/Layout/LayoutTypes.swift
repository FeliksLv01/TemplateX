import UIKit

// MARK: - 边距

/// 四边边距
public struct EdgeInsets: Equatable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat
    
    public static let zero = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    
    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
    
    public init(all: CGFloat) {
        self.top = all
        self.left = all
        self.bottom = all
        self.right = all
    }
    
    public init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
        self.top = vertical
        self.left = horizontal
        self.bottom = vertical
        self.right = horizontal
    }
    
    /// 转换为 UIEdgeInsets
    public var uiEdgeInsets: UIEdgeInsets {
        UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
}

// MARK: - Flexbox 属性

/// Flex 方向
public enum FlexDirection: String, Codable {
    case row = "row"
    case rowReverse = "row-reverse"
    case column = "column"
    case columnReverse = "column-reverse"
}

/// Flex 换行
public enum FlexWrap: String, Codable {
    case noWrap = "nowrap"
    case wrap = "wrap"
    case wrapReverse = "wrap-reverse"
}

/// 主轴对齐
public enum JustifyContent: String, Codable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center = "center"
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
    case spaceEvenly = "space-evenly"
}

/// 交叉轴对齐
public enum AlignItems: String, Codable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center = "center"
    case stretch = "stretch"
    case baseline = "baseline"
}

/// 子元素自身对齐
public enum AlignSelf: String, Codable {
    case auto = "auto"
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center = "center"
    case stretch = "stretch"
    case baseline = "baseline"
}

/// 多行对齐
public enum AlignContent: String, Codable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center = "center"
    case stretch = "stretch"
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
}

/// 定位类型
public enum PositionType: String, Codable {
    case relative = "relative"
    case absolute = "absolute"
}

/// 显示类型 (CSS display)
/// - flex: 正常显示和布局
/// - none: 不渲染，不占据布局空间
public enum Display: String, Codable {
    case flex = "flex"
    case none = "none"
}

/// 可见性 (CSS visibility)
/// - visible: 正常可见
/// - hidden: 不可见但占据空间（alpha=0 + 禁用交互）
public enum Visibility: String, Codable {
    case visible = "visible"
    case hidden = "hidden"
}

/// 溢出处理
public enum Overflow: String, Codable {
    case visible = "visible"
    case hidden = "hidden"
    case scroll = "scroll"
}

/// 文本对齐
public enum TextAlign: String, Codable {
    case left = "left"
    case center = "center"
    case right = "right"
    case justified = "justified"
    case start = "start"
    case end = "end"
    
    /// 转换为 NSTextAlignment
    public func toNSTextAlignment() -> NSTextAlignment {
        switch self {
        case .left, .start:
            return .left
        case .center:
            return .center
        case .right, .end:
            return .right
        case .justified:
            return .justified
        }
    }
}

// MARK: - Dimension

/// 尺寸类型 - 支持多种单位
public enum Dimension: Equatable {
    /// 自动计算
    case auto
    /// 固定点数
    case point(CGFloat)
    /// 百分比（0-100）
    case percent(CGFloat)
    
    /// 转为 CGFloat（百分比需要父容器尺寸）
    /// auto 返回 NaN，调用方需要特殊处理
    public func toPoints(relativeTo parentSize: CGFloat = 0) -> CGFloat {
        switch self {
        case .auto:
            return .nan  // auto 需要由布局引擎处理
        case .point(let value):
            return value
        case .percent(let value):
            return parentSize * value / 100.0
        }
    }
    
    /// 是否为自动
    public var isAuto: Bool {
        if case .auto = self { return true }
        return false
    }
}

// MARK: - 布局结果

/// 布局计算结果
public struct LayoutResult: Equatable {
    public var frame: CGRect = .zero
    public var contentSize: CGSize = .zero
    
    public init() {}
    
    public init(frame: CGRect) {
        self.frame = frame
        self.contentSize = frame.size
    }
}

// MARK: - 渐变样式

/// 渐变样式
public struct GradientStyle: Equatable {
    public enum Direction {
        case topToBottom
        case bottomToTop
        case leftToRight
        case rightToLeft
        case topLeftToBottomRight
        case topRightToBottomLeft
        case bottomLeftToTopRight
        case bottomRightToTopLeft
    }
    
    public var colors: [UIColor]
    public var locations: [CGFloat]?
    public var direction: Direction
    
    public init(colors: [UIColor], locations: [CGFloat]? = nil, direction: Direction = .topToBottom) {
        self.colors = colors
        self.locations = locations
        self.direction = direction
    }
}

/// 圆角
public struct CornerRadii: Equatable {
    public var topLeft: CGFloat
    public var topRight: CGFloat
    public var bottomLeft: CGFloat
    public var bottomRight: CGFloat
    
    public init(topLeft: CGFloat = 0, topRight: CGFloat = 0, bottomLeft: CGFloat = 0, bottomRight: CGFloat = 0) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
    
    public init(all: CGFloat) {
        self.topLeft = all
        self.topRight = all
        self.bottomLeft = all
        self.bottomRight = all
    }
}

// MARK: - ComponentStyle

/// 统一的组件样式
/// 合并了布局（Flexbox）、视觉和文本样式，符合 CSS 心智模型
public struct ComponentStyle: Equatable {
    
    // MARK: - 布局属性（Flexbox）
    
    /// 宽度（支持 auto、固定值、百分比）
    public var width: Dimension = .auto
    /// 高度（支持 auto、固定值、百分比）
    public var height: Dimension = .auto
    
    /// 最小宽度
    public var minWidth: CGFloat = 0
    /// 最小高度
    public var minHeight: CGFloat = 0
    /// 最大宽度
    public var maxWidth: CGFloat = .greatestFiniteMagnitude
    /// 最大高度
    public var maxHeight: CGFloat = .greatestFiniteMagnitude
    
    /// 外边距
    public var margin: EdgeInsets = .zero
    /// 内边距
    public var padding: EdgeInsets = .zero
    
    /// Flex 增长因子
    public var flexGrow: CGFloat = 0
    /// Flex 收缩因子
    public var flexShrink: CGFloat = 1
    /// Flex 基础尺寸（NaN 表示 auto）
    public var flexBasis: CGFloat = .nan
    
    /// Flex 方向（容器属性）
    public var flexDirection: FlexDirection = .column
    /// Flex 换行（容器属性）
    public var flexWrap: FlexWrap = .noWrap
    /// 主轴对齐（容器属性）
    public var justifyContent: JustifyContent = .flexStart
    /// 交叉轴对齐（容器属性）
    public var alignItems: AlignItems = .stretch
    /// 自身对齐
    public var alignSelf: AlignSelf = .auto
    /// 多行对齐（容器属性）
    public var alignContent: AlignContent = .flexStart
    
    /// 定位类型
    public var positionType: PositionType = .relative
    /// 定位偏移（top/left/bottom/right）
    public var position: EdgeInsets = .zero
    
    /// 宽高比
    public var aspectRatio: CGFloat = .nan
    
    /// 溢出处理
    public var overflow: Overflow = .visible
    
    // MARK: - 显示控制
    
    /// CSS display 属性
    /// - flex: 正常显示和布局
    /// - none: 不渲染，不占据布局空间
    public var display: Display = .flex
    
    /// CSS visibility 属性
    /// - visible: 正常可见
    /// - hidden: 不可见但占据空间（alpha=0 + 禁用交互）
    public var visibility: Visibility = .visible
    
    // MARK: - 视觉属性
    
    /// 背景色
    public var backgroundColor: UIColor?
    /// 渐变背景
    public var backgroundGradient: GradientStyle?
    
    /// 边框宽度
    public var borderWidth: CGFloat = 0
    /// 边框颜色
    public var borderColor: UIColor?
    /// 圆角半径
    public var cornerRadius: CGFloat = 0
    /// 单独设置每个角的圆角
    public var cornerRadii: CornerRadii?
    
    /// 阴影颜色
    public var shadowColor: UIColor?
    /// 阴影偏移
    public var shadowOffset: CGSize = .zero
    /// 阴影模糊半径
    public var shadowRadius: CGFloat = 0
    /// 阴影透明度
    public var shadowOpacity: Float = 0
    
    /// 透明度（0-1）
    public var opacity: CGFloat = 1
    
    /// 裁剪子视图
    public var clipsToBounds: Bool = false
    
    // MARK: - 文本样式
    
    /// 字体大小
    public var fontSize: CGFloat?
    /// 字重（如 "bold", "500" 等）
    public var fontWeight: String?
    /// 文本颜色
    public var textColor: UIColor?
    /// 文本对齐
    public var textAlign: TextAlign?
    /// 行高
    public var lineHeight: CGFloat?
    /// 字间距
    public var letterSpacing: CGFloat?
    /// 行数（0 表示不限制）
    public var numberOfLines: Int?
    
    // MARK: - Init
    
    public init() {}
    
    // MARK: - 便捷方法
    
    /// 是否影响布局的属性
    /// 这些属性变化时需要重新计算布局
    public static let layoutAffectingKeyPaths: Set<String> = [
        "width", "height", "minWidth", "minHeight", "maxWidth", "maxHeight",
        "margin", "padding", "flexGrow", "flexShrink", "flexBasis",
        "flexDirection", "flexWrap", "justifyContent", "alignItems", "alignSelf", "alignContent",
        "positionType", "position", "aspectRatio", "display",
        "fontSize", "fontWeight", "lineHeight", "letterSpacing", "numberOfLines"
    ]
    
    /// 判断两个样式是否需要重新布局
    public func needsRelayout(comparedTo other: ComponentStyle) -> Bool {
        // 布局相关属性比较
        return width != other.width ||
               height != other.height ||
               minWidth != other.minWidth ||
               minHeight != other.minHeight ||
               maxWidth != other.maxWidth ||
               maxHeight != other.maxHeight ||
               margin != other.margin ||
               padding != other.padding ||
               flexGrow != other.flexGrow ||
               flexShrink != other.flexShrink ||
               flexBasis != other.flexBasis ||
               flexDirection != other.flexDirection ||
               flexWrap != other.flexWrap ||
               justifyContent != other.justifyContent ||
               alignItems != other.alignItems ||
               alignSelf != other.alignSelf ||
               alignContent != other.alignContent ||
               positionType != other.positionType ||
               position != other.position ||
               aspectRatio != other.aspectRatio ||
               display != other.display ||
               // 文本相关也影响布局
               fontSize != other.fontSize ||
               fontWeight != other.fontWeight ||
               lineHeight != other.lineHeight ||
               letterSpacing != other.letterSpacing ||
               numberOfLines != other.numberOfLines
    }
    
    // MARK: - Clone
    
    /// 创建样式的完整副本
    public func clone() -> ComponentStyle {
        // ComponentStyle 是值类型（struct），直接返回 self 即可
        return self
    }
    
    // MARK: - Merging
    
    /// 合并样式变化（用于增量更新）
    /// - Parameter changes: 变化的样式属性字典
    /// - Returns: 合并后的新样式
    public func merging(_ changes: [String: Any]) -> ComponentStyle {
        var result = self
        
        for (key, value) in changes {
            switch key {
            // 布局属性
            case "width":
                if let dim = value as? Dimension {
                    result.width = dim
                }
            case "height":
                if let dim = value as? Dimension {
                    result.height = dim
                }
            case "minWidth":
                if let v = value as? CGFloat {
                    result.minWidth = v
                }
            case "minHeight":
                if let v = value as? CGFloat {
                    result.minHeight = v
                }
            case "maxWidth":
                if let v = value as? CGFloat {
                    result.maxWidth = v
                }
            case "maxHeight":
                if let v = value as? CGFloat {
                    result.maxHeight = v
                }
            case "margin":
                if let v = value as? EdgeInsets {
                    result.margin = v
                }
            case "padding":
                if let v = value as? EdgeInsets {
                    result.padding = v
                }
            case "flexGrow":
                if let v = value as? CGFloat {
                    result.flexGrow = v
                }
            case "flexShrink":
                if let v = value as? CGFloat {
                    result.flexShrink = v
                }
            case "flexBasis":
                if let v = value as? CGFloat {
                    result.flexBasis = v
                }
            case "flexDirection":
                if let v = value as? FlexDirection {
                    result.flexDirection = v
                }
            case "flexWrap":
                if let v = value as? FlexWrap {
                    result.flexWrap = v
                }
            case "justifyContent":
                if let v = value as? JustifyContent {
                    result.justifyContent = v
                }
            case "alignItems":
                if let v = value as? AlignItems {
                    result.alignItems = v
                }
            case "alignSelf":
                if let v = value as? AlignSelf {
                    result.alignSelf = v
                }
            case "alignContent":
                if let v = value as? AlignContent {
                    result.alignContent = v
                }
            case "positionType":
                if let v = value as? PositionType {
                    result.positionType = v
                }
            case "position":
                if let v = value as? EdgeInsets {
                    result.position = v
                }
            case "aspectRatio":
                if let v = value as? CGFloat {
                    result.aspectRatio = v
                }
            case "overflow":
                if let v = value as? Overflow {
                    result.overflow = v
                }
            
            // 显示控制
            case "display":
                if let v = value as? Display {
                    result.display = v
                }
            case "visibility":
                if let v = value as? Visibility {
                    result.visibility = v
                }
            
            // 视觉属性
            case "backgroundColor":
                if let v = value as? UIColor {
                    result.backgroundColor = v
                }
            case "backgroundGradient":
                if let v = value as? GradientStyle {
                    result.backgroundGradient = v
                }
            case "borderWidth":
                if let v = value as? CGFloat {
                    result.borderWidth = v
                }
            case "borderColor":
                if let v = value as? UIColor {
                    result.borderColor = v
                }
            case "cornerRadius":
                if let v = value as? CGFloat {
                    result.cornerRadius = v
                }
            case "cornerRadii":
                if let v = value as? CornerRadii {
                    result.cornerRadii = v
                }
            case "shadowColor":
                if let v = value as? UIColor {
                    result.shadowColor = v
                }
            case "shadowOffset":
                if let v = value as? CGSize {
                    result.shadowOffset = v
                }
            case "shadowRadius":
                if let v = value as? CGFloat {
                    result.shadowRadius = v
                }
            case "shadowOpacity":
                if let v = value as? Float {
                    result.shadowOpacity = v
                }
            case "opacity":
                if let v = value as? CGFloat {
                    result.opacity = v
                }
            case "clipsToBounds":
                if let v = value as? Bool {
                    result.clipsToBounds = v
                }
            
            // 文本样式
            case "fontSize":
                if let v = value as? CGFloat {
                    result.fontSize = v
                }
            case "fontWeight":
                if let v = value as? String {
                    result.fontWeight = v
                }
            case "textColor":
                if let v = value as? UIColor {
                    result.textColor = v
                }
            case "textAlign":
                if let v = value as? TextAlign {
                    result.textAlign = v
                }
            case "lineHeight":
                if let v = value as? CGFloat {
                    result.lineHeight = v
                }
            case "letterSpacing":
                if let v = value as? CGFloat {
                    result.letterSpacing = v
                }
            case "numberOfLines":
                if let v = value as? Int {
                    result.numberOfLines = v
                }
                
            default:
                break
            }
        }
        
        return result
    }
    
    /// 用另一个 ComponentStyle 替换当前样式（用于增量更新）
    /// - Parameter newStyle: 新的样式
    /// - Returns: 新样式（直接返回新样式，因为这是完整替换）
    public func merging(_ newStyle: ComponentStyle) -> ComponentStyle {
        // 直接使用新样式替换
        return newStyle
    }
}

// MARK: - 兼容性类型别名（deprecated）

/// 布局参数（已废弃，请使用 ComponentStyle）
@available(*, deprecated, renamed: "ComponentStyle")
public typealias LayoutParams = ComponentStyle

/// 样式参数（已废弃，请使用 ComponentStyle）
@available(*, deprecated, renamed: "ComponentStyle")
public typealias StyleParams = ComponentStyle
