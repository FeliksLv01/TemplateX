import Foundation

// MARK: - 属性映射器

/// 属性映射器 - XML 属性名 → JSON 属性名
public struct AttributeMapper {
    
    // MARK: - 组件类型映射
    
    /// XML 标签名 → JSON 组件类型
    public static let componentTypeMap: [String: String] = [
        // Flexbox 布局容器
        "Flex": "flex",
        "FlexLayout": "flex",
        "Container": "container",
        "Box": "flex",
        "Row": "flex",        // 水平 flex
        "Column": "flex",     // 垂直 flex
        "Stack": "flex",      // 层叠（使用 position: absolute）
        
        // 滚动容器
        "ScrollView": "scroll",
        "ListView": "list",
        "GridView": "grid",
        "RecyclerView": "list",
        
        // 基础视图
        "View": "view",
        "Text": "text",
        "TextView": "text",
        "Image": "image",
        "ImageView": "image",
        "Button": "button",
        "Input": "input",
        "EditText": "input",
        
        // 特殊组件
        "Lottie": "lottie",
        "Progress": "progress",
        "Slider": "slider",
        "Switch": "switch",
        "VideoPlayer": "video",
        
        // 模板结构
        "Template": "template",
        "Component": "component",
        "Slot": "slot",
        "Include": "include"
    ]
    
    /// 获取组件类型
    public static func componentType(for tagName: String) -> String {
        return componentTypeMap[tagName] ?? tagName.lowercased()
    }
    
    // MARK: - 布局属性映射
    
    /// 布局属性映射表
    public static let layoutAttributeMap: [String: String] = [
        // 尺寸
        "width": "width",
        "height": "height",
        "minWidth": "minWidth",
        "minHeight": "minHeight",
        "maxWidth": "maxWidth",
        "maxHeight": "maxHeight",
        
        // 边距
        "margin": "margin",
        "marginTop": "marginTop",
        "marginBottom": "marginBottom",
        "marginLeft": "marginLeft",
        "marginRight": "marginRight",
        "marginStart": "marginStart",
        "marginEnd": "marginEnd",
        "marginHorizontal": "marginHorizontal",
        "marginVertical": "marginVertical",
        
        // 内边距
        "padding": "padding",
        "paddingTop": "paddingTop",
        "paddingBottom": "paddingBottom",
        "paddingLeft": "paddingLeft",
        "paddingRight": "paddingRight",
        "paddingStart": "paddingStart",
        "paddingEnd": "paddingEnd",
        "paddingHorizontal": "paddingHorizontal",
        "paddingVertical": "paddingVertical",
        
        // Flexbox
        "flexDirection": "flexDirection",
        "flexWrap": "flexWrap",
        "justifyContent": "justifyContent",
        "alignItems": "alignItems",
        "alignContent": "alignContent",
        "alignSelf": "alignSelf",
        "flex": "flex",
        "flexGrow": "flexGrow",
        "flexShrink": "flexShrink",
        "flexBasis": "flexBasis",
        
        // 定位
        "position": "position",
        "top": "top",
        "bottom": "bottom",
        "left": "left",
        "right": "right",
        "start": "start",
        "end": "end",
        
        // 其他布局属性
        "aspectRatio": "aspectRatio",
        "weight": "weight",
        "gravity": "gravity",
        "layout_gravity": "layoutGravity",
        "orientation": "orientation"
    ]
    
    // MARK: - 样式属性映射
    
    /// 样式属性映射表
    public static let styleAttributeMap: [String: String] = [
        // 背景
        "background": "backgroundColor",
        "backgroundColor": "backgroundColor",
        "backgroundImage": "backgroundImage",
        "backgroundGradient": "backgroundGradient",
        
        // 边框
        "borderWidth": "borderWidth",
        "borderColor": "borderColor",
        "borderStyle": "borderStyle",
        "borderRadius": "borderRadius",
        "cornerRadius": "borderRadius",
        "borderTopLeftRadius": "borderTopLeftRadius",
        "borderTopRightRadius": "borderTopRightRadius",
        "borderBottomLeftRadius": "borderBottomLeftRadius",
        "borderBottomRightRadius": "borderBottomRightRadius",
        
        // 阴影
        "shadow": "shadow",
        "shadowColor": "shadowColor",
        "shadowOffset": "shadowOffset",
        "shadowRadius": "shadowRadius",
        "shadowOpacity": "shadowOpacity",
        "elevation": "elevation",
        
        // 其他
        "opacity": "opacity",
        "alpha": "opacity",
        "visibility": "visibility",
        "visible": "visible",
        "hidden": "hidden",
        "overflow": "overflow",
        "clipToBounds": "clipToBounds",
        "transform": "transform"
    ]
    
    // MARK: - 文本属性映射
    
    /// 文本属性映射表
    public static let textAttributeMap: [String: String] = [
        "text": "text",
        "fontSize": "fontSize",
        "textSize": "fontSize",
        "fontWeight": "fontWeight",
        "fontStyle": "fontStyle",
        "fontFamily": "fontFamily",
        "color": "textColor",
        "textColor": "textColor",
        "textAlign": "textAlign",
        "textAlignment": "textAlign",
        "lineHeight": "lineHeight",
        "letterSpacing": "letterSpacing",
        "lines": "maxLines",
        "maxLines": "maxLines",
        "ellipsize": "ellipsize",
        "textOverflow": "ellipsize",
        "textDecoration": "textDecoration",
        "textTransform": "textTransform"
    ]
    
    // MARK: - 图片属性映射
    
    /// 图片属性映射表
    public static let imageAttributeMap: [String: String] = [
        "src": "src",
        "source": "src",
        "placeholder": "placeholder",
        "fallback": "fallback",
        "scaleType": "scaleType",
        "contentMode": "scaleType",
        "tintColor": "tintColor",
        "resizeMode": "resizeMode"
    ]
    
    // MARK: - 事件属性映射
    
    /// 事件属性映射表
    public static let eventAttributeMap: [String: String] = [
        "onClick": "tap",
        "onTap": "tap",
        "onLongClick": "longPress",
        "onLongPress": "longPress",
        "onDoubleClick": "doubleTap",
        "onDoubleTap": "doubleTap",
        "onSwipe": "swipe",
        "onPan": "pan",
        "onTouch": "touch",
        "onVisible": "visible",
        "onDisappear": "disappear",
        "onScroll": "scroll",
        "onChange": "change",
        "onFocus": "focus",
        "onBlur": "blur"
    ]
    
    // MARK: - 枚举值映射
    
    /// 方向枚举
    public static let orientationMap: [String: Int] = [
        "horizontal": 0,
        "vertical": 1
    ]
    
    /// Flex 方向枚举
    public static let flexDirectionMap: [String: Int] = [
        "row": 0,
        "row-reverse": 1,
        "column": 2,
        "column-reverse": 3
    ]
    
    /// 对齐方式枚举
    public static let alignMap: [String: Int] = [
        "flex-start": 0,
        "start": 0,
        "flex-end": 1,
        "end": 1,
        "center": 2,
        "stretch": 3,
        "baseline": 4,
        "space-between": 5,
        "space-around": 6,
        "space-evenly": 7
    ]
    
    /// 字重枚举
    public static let fontWeightMap: [String: Int] = [
        "normal": 400,
        "bold": 700,
        "thin": 100,
        "light": 300,
        "medium": 500,
        "semibold": 600,
        "heavy": 800,
        "black": 900
    ]
    
    /// 文本对齐枚举
    public static let textAlignMap: [String: Int] = [
        "left": 0,
        "start": 0,
        "center": 1,
        "right": 2,
        "end": 2,
        "justify": 3
    ]
    
    /// 省略模式枚举
    public static let ellipsizeMap: [String: Int] = [
        "none": 0,
        "start": 1,
        "end": 2,
        "middle": 3,
        "clip": 4
    ]
    
    /// 缩放模式枚举
    public static let scaleTypeMap: [String: Int] = [
        "fill": 0,
        "scaleToFill": 0,
        "aspectFit": 1,
        "contain": 1,
        "aspectFill": 2,
        "cover": 2,
        "center": 3,
        "top": 4,
        "bottom": 5
    ]
    
    // MARK: - 属性分类
    
    /// 判断属性类型
    public static func attributeCategory(for name: String) -> AttributeCategory {
        if layoutAttributeMap[name] != nil {
            return .layout
        }
        if styleAttributeMap[name] != nil {
            return .style
        }
        if textAttributeMap[name] != nil {
            return .text
        }
        if imageAttributeMap[name] != nil {
            return .image
        }
        if eventAttributeMap[name] != nil {
            return .event
        }
        // x- 指令已废弃，但仍需识别以便跳过
        if name.hasPrefix("x-") {
            return .directive
        }
        if name == "id" || name == "key" || name == "ref" {
            return .identity
        }
        return .custom
    }
    
    /// 转换枚举值
    public static func mapEnumValue(attribute: String, value: String) -> Any {
        let lowercased = value.lowercased()
        
        switch attribute {
        case "orientation":
            return orientationMap[lowercased] ?? 1
        case "flexDirection":
            return flexDirectionMap[lowercased] ?? 2
        case "justifyContent", "alignItems", "alignContent", "alignSelf":
            return alignMap[lowercased] ?? 0
        case "fontWeight":
            // 支持数字字重
            if let weight = Int(value) {
                return weight
            }
            return fontWeightMap[lowercased] ?? 400
        case "textAlign", "textAlignment":
            return textAlignMap[lowercased] ?? 0
        case "ellipsize", "textOverflow":
            return ellipsizeMap[lowercased] ?? 2
        case "scaleType", "contentMode", "resizeMode":
            return scaleTypeMap[lowercased] ?? 2
        default:
            return value
        }
    }
}

// MARK: - 属性分类

public enum AttributeCategory {
    case layout
    case style
    case text
    case image
    case event
    case directive
    case identity
    case custom
}
