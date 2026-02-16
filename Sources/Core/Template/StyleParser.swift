import UIKit

// MARK: - StyleKey 枚举

/// 样式属性 key 枚举
/// 将字符串 key 映射为枚举值，避免重复字符串比较
/// 使用哈希表 O(1) 查找，比逐个字符串比较更高效
enum StyleKey: Int {
    // 尺寸
    case width, height
    case minWidth, minHeight, maxWidth, maxHeight
    
    // 边距
    case margin, padding
    case marginTop, marginLeft, marginBottom, marginRight
    case marginHorizontal, marginVertical
    case paddingTop, paddingLeft, paddingBottom, paddingRight
    case paddingHorizontal, paddingVertical
    
    // Flex
    case flexGrow, flexShrink, flexBasis
    case flexDirection, flexWrap
    case justifyContent, alignItems, alignSelf, alignContent
    
    // 定位
    case position, positionType
    case top, left, bottom, right
    
    // 其他布局
    case aspectRatio, overflow
    
    // 显示控制
    case display, visibility
    
    // 背景
    case backgroundColor
    
    // 圆角和边框
    case cornerRadius, borderRadius
    case borderWidth, borderColor
    
    // 阴影
    case shadowColor, shadowOffset, shadowRadius, shadowOpacity
    
    // 透明度和裁剪
    case opacity, clipsToBounds
    
    // 文本
    case fontSize, fontWeight
    case textColor, color
    case textAlign
    case lineHeight, letterSpacing
    case numberOfLines, lines
    
    // 静态映射表：字符串 -> 枚举
    // 一次初始化，后续 O(1) 查找
    private static let keyMap: [String: StyleKey] = {
        var map = [String: StyleKey]()
        map.reserveCapacity(64)
        
        // 尺寸
        map["width"] = .width
        map["height"] = .height
        map["minWidth"] = .minWidth
        map["minHeight"] = .minHeight
        map["maxWidth"] = .maxWidth
        map["maxHeight"] = .maxHeight
        
        // 边距
        map["margin"] = .margin
        map["padding"] = .padding
        map["marginTop"] = .marginTop
        map["marginLeft"] = .marginLeft
        map["marginBottom"] = .marginBottom
        map["marginRight"] = .marginRight
        map["marginHorizontal"] = .marginHorizontal
        map["marginVertical"] = .marginVertical
        map["paddingTop"] = .paddingTop
        map["paddingLeft"] = .paddingLeft
        map["paddingBottom"] = .paddingBottom
        map["paddingRight"] = .paddingRight
        map["paddingHorizontal"] = .paddingHorizontal
        map["paddingVertical"] = .paddingVertical
        
        // Flex
        map["flexGrow"] = .flexGrow
        map["flexShrink"] = .flexShrink
        map["flexBasis"] = .flexBasis
        map["flexDirection"] = .flexDirection
        map["flexWrap"] = .flexWrap
        map["justifyContent"] = .justifyContent
        map["alignItems"] = .alignItems
        map["alignSelf"] = .alignSelf
        map["alignContent"] = .alignContent
        
        // 定位
        map["position"] = .position
        map["positionType"] = .positionType
        map["top"] = .top
        map["left"] = .left
        map["bottom"] = .bottom
        map["right"] = .right
        
        // 其他布局
        map["aspectRatio"] = .aspectRatio
        map["overflow"] = .overflow
        
        // 显示控制
        map["display"] = .display
        map["visibility"] = .visibility
        
        // 背景
        map["backgroundColor"] = .backgroundColor
        
        // 圆角和边框
        map["cornerRadius"] = .cornerRadius
        map["borderRadius"] = .borderRadius
        map["borderWidth"] = .borderWidth
        map["borderColor"] = .borderColor
        
        // 阴影
        map["shadowColor"] = .shadowColor
        map["shadowOffset"] = .shadowOffset
        map["shadowRadius"] = .shadowRadius
        map["shadowOpacity"] = .shadowOpacity
        
        // 透明度和裁剪
        map["opacity"] = .opacity
        map["clipsToBounds"] = .clipsToBounds
        
        // 文本
        map["fontSize"] = .fontSize
        map["fontWeight"] = .fontWeight
        map["textColor"] = .textColor
        map["color"] = .color
        map["textAlign"] = .textAlign
        map["lineHeight"] = .lineHeight
        map["letterSpacing"] = .letterSpacing
        map["numberOfLines"] = .numberOfLines
        map["lines"] = .lines
        
        return map
    }()
    
    /// 从字符串获取 StyleKey
    @inline(__always)
    static func from(_ string: String) -> StyleKey? {
        keyMap[string]
    }
}

// MARK: - 枚举解析映射表

/// FlexDirection 静态映射
private let flexDirectionMap: [String: FlexDirection] = [
    "row": .row,
    "row-reverse": .rowReverse,
    "column": .column,
    "column-reverse": .columnReverse
]

/// FlexWrap 静态映射
private let flexWrapMap: [String: FlexWrap] = [
    "nowrap": .noWrap,
    "wrap": .wrap,
    "wrap-reverse": .wrapReverse
]

/// JustifyContent 静态映射
private let justifyContentMap: [String: JustifyContent] = [
    "flex-start": .flexStart,
    "flex-end": .flexEnd,
    "center": .center,
    "space-between": .spaceBetween,
    "space-around": .spaceAround,
    "space-evenly": .spaceEvenly
]

/// AlignItems 静态映射
private let alignItemsMap: [String: AlignItems] = [
    "flex-start": .flexStart,
    "flex-end": .flexEnd,
    "center": .center,
    "stretch": .stretch,
    "baseline": .baseline
]

/// AlignSelf 静态映射
private let alignSelfMap: [String: AlignSelf] = [
    "auto": .auto,
    "flex-start": .flexStart,
    "flex-end": .flexEnd,
    "center": .center,
    "stretch": .stretch,
    "baseline": .baseline
]

/// AlignContent 静态映射
private let alignContentMap: [String: AlignContent] = [
    "flex-start": .flexStart,
    "flex-end": .flexEnd,
    "center": .center,
    "stretch": .stretch,
    "space-between": .spaceBetween,
    "space-around": .spaceAround
]

/// PositionType 静态映射
private let positionTypeMap: [String: PositionType] = [
    "relative": .relative,
    "absolute": .absolute
]

/// Overflow 静态映射
private let overflowMap: [String: Overflow] = [
    "visible": .visible,
    "hidden": .hidden,
    "scroll": .scroll
]

/// Display 静态映射
private let displayMap: [String: Display] = [
    "flex": .flex,
    "none": .none
]

/// Visibility 静态映射
private let visibilityMap: [String: Visibility] = [
    "visible": .visible,
    "hidden": .hidden
]

/// TextAlign 静态映射
private let textAlignMap: [String: TextAlign] = [
    "left": .left,
    "center": .center,
    "right": .right,
    "justified": .justified,
    "start": .start,
    "end": .end
]

// MARK: - StyleParser

/// 样式批量解析器
/// 优化策略：一次遍历 JSON 字典，根据 StyleKey 分发到对应属性
/// 相比逐属性查询，减少了大量重复的字典查找
enum StyleParser {
    
    /// 批量解析样式（高性能版本）
    /// 一次遍历 JSON 字典，批量设置所有属性
    static func parse(from rawDict: [String: Any]) -> ComponentStyle {
        var style = ComponentStyle()
        
        // 临时变量，用于处理需要合并的属性
        var hasMarginH = false, marginH: CGFloat = 0
        var hasMarginV = false, marginV: CGFloat = 0
        var hasPaddingH = false, paddingH: CGFloat = 0
        var hasPaddingV = false, paddingV: CGFloat = 0
        var hasColor = false
        var colorValue: UIColor?
        
        // 一次遍历所有键值对
        for (key, value) in rawDict {
            guard let styleKey = StyleKey.from(key) else { continue }
            
            switch styleKey {
            // ========== 尺寸 ==========
            case .width:
                style.width = parseDimension(value)
            case .height:
                style.height = parseDimension(value)
            case .minWidth:
                if let v = toCGFloat(value) { style.minWidth = v }
            case .minHeight:
                if let v = toCGFloat(value) { style.minHeight = v }
            case .maxWidth:
                if let v = toCGFloat(value) { style.maxWidth = v }
            case .maxHeight:
                if let v = toCGFloat(value) { style.maxHeight = v }
                
            // ========== 边距 ==========
            case .margin:
                style.margin = parseEdgeInsets(value)
            case .padding:
                style.padding = parseEdgeInsets(value)
            case .marginTop:
                if let v = toCGFloat(value) { style.margin.top = v }
            case .marginLeft:
                if let v = toCGFloat(value) { style.margin.left = v }
            case .marginBottom:
                if let v = toCGFloat(value) { style.margin.bottom = v }
            case .marginRight:
                if let v = toCGFloat(value) { style.margin.right = v }
            case .marginHorizontal:
                if let v = toCGFloat(value) { hasMarginH = true; marginH = v }
            case .marginVertical:
                if let v = toCGFloat(value) { hasMarginV = true; marginV = v }
            case .paddingTop:
                if let v = toCGFloat(value) { style.padding.top = v }
            case .paddingLeft:
                if let v = toCGFloat(value) { style.padding.left = v }
            case .paddingBottom:
                if let v = toCGFloat(value) { style.padding.bottom = v }
            case .paddingRight:
                if let v = toCGFloat(value) { style.padding.right = v }
            case .paddingHorizontal:
                if let v = toCGFloat(value) { hasPaddingH = true; paddingH = v }
            case .paddingVertical:
                if let v = toCGFloat(value) { hasPaddingV = true; paddingV = v }
                
            // ========== Flex ==========
            case .flexGrow:
                if let v = toCGFloat(value) { style.flexGrow = v }
            case .flexShrink:
                if let v = toCGFloat(value) { style.flexShrink = v }
            case .flexBasis:
                if let v = toCGFloat(value) { style.flexBasis = v }
            case .flexDirection:
                if let str = value as? String, let e = flexDirectionMap[str] {
                    style.flexDirection = e
                }
            case .flexWrap:
                if let str = value as? String, let e = flexWrapMap[str] {
                    style.flexWrap = e
                }
            case .justifyContent:
                if let str = value as? String, let e = justifyContentMap[str] {
                    style.justifyContent = e
                }
            case .alignItems:
                if let str = value as? String, let e = alignItemsMap[str] {
                    style.alignItems = e
                }
            case .alignSelf:
                if let str = value as? String, let e = alignSelfMap[str] {
                    style.alignSelf = e
                }
            case .alignContent:
                if let str = value as? String, let e = alignContentMap[str] {
                    style.alignContent = e
                }
                
            // ========== 定位 ==========
            case .position:
                // "position" 可能是 positionType 的别名
                if let str = value as? String, let e = positionTypeMap[str] {
                    style.positionType = e
                }
            case .positionType:
                if let str = value as? String, let e = positionTypeMap[str] {
                    style.positionType = e
                }
            case .top:
                if let v = toCGFloat(value) { style.position.top = v }
            case .left:
                if let v = toCGFloat(value) { style.position.left = v }
            case .bottom:
                if let v = toCGFloat(value) { style.position.bottom = v }
            case .right:
                if let v = toCGFloat(value) { style.position.right = v }
                
            // ========== 其他布局 ==========
            case .aspectRatio:
                if let v = toCGFloat(value) { style.aspectRatio = v }
            case .overflow:
                if let str = value as? String, let e = overflowMap[str] {
                    style.overflow = e
                }
                
            // ========== 显示控制 ==========
            case .display:
                if let str = value as? String, let e = displayMap[str] {
                    style.display = e
                }
            case .visibility:
                if let str = value as? String, let e = visibilityMap[str] {
                    style.visibility = e
                }
                
            // ========== 背景 ==========
            case .backgroundColor:
                style.backgroundColor = parseColor(value)
                
            // ========== 圆角和边框 ==========
            case .cornerRadius, .borderRadius:
                if let v = toCGFloat(value) { style.cornerRadius = v }
            case .borderWidth:
                if let v = toCGFloat(value) { style.borderWidth = v }
            case .borderColor:
                style.borderColor = parseColor(value)
                
            // ========== 阴影 ==========
            case .shadowColor:
                style.shadowColor = parseColor(value)
            case .shadowOffset:
                if let arr = value as? [Any], arr.count >= 2 {
                    let x = (arr[0] as? Double) ?? (arr[0] as? Int).map { Double($0) } ?? 0
                    let y = (arr[1] as? Double) ?? (arr[1] as? Int).map { Double($0) } ?? 0
                    style.shadowOffset = CGSize(width: x, height: y)
                }
            case .shadowRadius:
                if let v = toCGFloat(value) { style.shadowRadius = v }
            case .shadowOpacity:
                if let v = toCGFloat(value) { style.shadowOpacity = Float(v) }
                
            // ========== 透明度和裁剪 ==========
            case .opacity:
                if let v = toCGFloat(value) { style.opacity = v }
            case .clipsToBounds:
                if let b = value as? Bool { style.clipsToBounds = b }
                
            // ========== 文本 ==========
            case .fontSize:
                if let v = toCGFloat(value) { style.fontSize = v }
            case .fontWeight:
                if let str = value as? String { style.fontWeight = str }
            case .textColor:
                style.textColor = parseColor(value)
            case .color:
                // "color" 作为 textColor 的备选
                hasColor = true
                colorValue = parseColor(value)
            case .textAlign:
                if let str = value as? String, let e = textAlignMap[str] {
                    style.textAlign = e
                }
            case .lineHeight:
                if let v = toCGFloat(value) { style.lineHeight = v }
            case .letterSpacing:
                if let v = toCGFloat(value) { style.letterSpacing = v }
            case .numberOfLines, .lines:
                if let i = value as? Int {
                    style.numberOfLines = i
                } else if let d = value as? Double {
                    style.numberOfLines = Int(d)
                }
            }
        }
        
        // 后处理：合并快捷属性
        if hasMarginH {
            style.margin.left = marginH
            style.margin.right = marginH
        }
        if hasMarginV {
            style.margin.top = marginV
            style.margin.bottom = marginV
        }
        if hasPaddingH {
            style.padding.left = paddingH
            style.padding.right = paddingH
        }
        if hasPaddingV {
            style.padding.top = paddingV
            style.padding.bottom = paddingV
        }
        
        // textColor 优先级高于 color
        if style.textColor == nil && hasColor {
            style.textColor = colorValue
        }
        
        return style
    }
    
    // MARK: - 私有辅助方法
    
    /// 转换为 CGFloat
    @inline(__always)
    private static func toCGFloat(_ value: Any) -> CGFloat? {
        if let d = value as? Double {
            return CGFloat(d)
        }
        if let i = value as? Int {
            return CGFloat(i)
        }
        return nil
    }
    
    /// 解析 Dimension
    @inline(__always)
    private static func parseDimension(_ value: Any) -> Dimension {
        // 数字 - 固定点数
        if let num = value as? Double {
            return .point(CGFloat(num))
        }
        if let num = value as? Int {
            return .point(CGFloat(num))
        }
        
        // 字符串
        if let str = value as? String {
            switch str.lowercased() {
            case "auto":
                return .auto
            default:
                // 尝试解析数字
                if let d = Double(str) {
                    return .point(CGFloat(d))
                }
                // 百分比
                if str.hasSuffix("%"), let d = Double(str.dropLast()) {
                    return .percent(CGFloat(d))
                }
            }
        }
        
        return .auto
    }
    
    /// 解析 EdgeInsets
    @inline(__always)
    private static func parseEdgeInsets(_ value: Any) -> EdgeInsets {
        // 单一数值 - 四边相同
        if let num = value as? Double {
            return EdgeInsets(all: CGFloat(num))
        }
        if let num = value as? Int {
            return EdgeInsets(all: CGFloat(num))
        }
        
        // 数组 - [top, right, bottom, left] 或 [vertical, horizontal]
        if let arr = value as? [Any] {
            if arr.count == 4 {
                return EdgeInsets(
                    top: CGFloat((arr[0] as? Double) ?? (arr[0] as? Int).map { Double($0) } ?? 0),
                    left: CGFloat((arr[3] as? Double) ?? (arr[3] as? Int).map { Double($0) } ?? 0),
                    bottom: CGFloat((arr[2] as? Double) ?? (arr[2] as? Int).map { Double($0) } ?? 0),
                    right: CGFloat((arr[1] as? Double) ?? (arr[1] as? Int).map { Double($0) } ?? 0)
                )
            } else if arr.count == 2 {
                let v = CGFloat((arr[0] as? Double) ?? (arr[0] as? Int).map { Double($0) } ?? 0)
                let h = CGFloat((arr[1] as? Double) ?? (arr[1] as? Int).map { Double($0) } ?? 0)
                return EdgeInsets(horizontal: h, vertical: v)
            }
        }
        
        // 对象 - { top, left, bottom, right }
        if let obj = value as? [String: Any] {
            return EdgeInsets(
                top: CGFloat((obj["top"] as? Double) ?? (obj["top"] as? Int).map { Double($0) } ?? 0),
                left: CGFloat((obj["left"] as? Double) ?? (obj["left"] as? Int).map { Double($0) } ?? 0),
                bottom: CGFloat((obj["bottom"] as? Double) ?? (obj["bottom"] as? Int).map { Double($0) } ?? 0),
                right: CGFloat((obj["right"] as? Double) ?? (obj["right"] as? Int).map { Double($0) } ?? 0)
            )
        }
        
        return .zero
    }
    
    /// 解析颜色
    @inline(__always)
    private static func parseColor(_ value: Any) -> UIColor? {
        // 字符串颜色
        if let str = value as? String {
            return UIColor.tx_color(from: str)
        }
        // 整数颜色（预编译）
        if let int = value as? Int {
            return UIColor.tx_color(from: int)
        }
        return nil
    }
}
