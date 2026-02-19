import Foundation
import UIKit

// MARK: - Data Binding Manager

/// 数据绑定管理器
/// 负责将模板中的表达式与数据绑定
public final class DataBindingManager {
    
    // MARK: - Singleton
    
    public static let shared = DataBindingManager()
    
    // MARK: - Properties
    
    /// 表达式引擎
    private let expressionEngine: ExpressionEngine
    
    // MARK: - Init
    
    private init() {
        self.expressionEngine = ExpressionEngine.shared
    }
    
    /// 使用自定义表达式引擎
    public init(expressionEngine: ExpressionEngine) {
        self.expressionEngine = expressionEngine
    }
    
    // MARK: - Binding API
    
    /// 绑定数据到组件树
    /// - Parameters:
    ///   - data: 要绑定的数据
    ///   - component: 根组件
    ///   - templateData: 模板级数据（可选）
    public func bind(
        data: [String: Any],
        to component: Component,
        templateData: [String: Any]? = nil
    ) {
        // 构建完整的数据上下文
        var context = data
        
        // 添加模板级数据
        if let templateData = templateData {
            context["templateData"] = templateData
        }
        
        // 添加内置变量
        context["$data"] = data  // 原始数据引用
        
        // 递归绑定
        bindRecursive(data: context, to: component)
    }
    
    /// 递归绑定数据到组件及其子组件
    private func bindRecursive(data: [String: Any], to component: Component) {
        // 保存绑定数据
        if let baseComponent = component as? BaseComponent {
            baseComponent.bindings = data
            
            // 如果有原始 JSON，解析表达式
            if let json = baseComponent.jsonWrapper {
                resolveExpressions(json: json, data: data, component: baseComponent)
            }
            
            // 特殊处理 ListComponent：将 data["items"] 绑定到 dataSource
            if let listComponent = baseComponent as? ListComponent {
                if let items = data["items"] as? [Any] {
                    listComponent.dataSource = items
                }
            }
        }
        
        // 递归处理子组件
        for (index, child) in component.children.enumerated() {
            // 构建子组件的上下文
            var childContext = data
            childContext["$index"] = index
            childContext["$parent"] = data
            
            bindRecursive(data: childContext, to: child)
        }
    }
    
    // MARK: - Expression Resolution
    
    /// 解析组件中的表达式
    private func resolveExpressions(
        json: JSONWrapper,
        data: [String: Any],
        component: BaseComponent
    ) {
        // 处理 props 中的表达式
        if let props = json.props {
            for (key, value) in props.rawDictionary {
                if let strValue = value as? String, expressionEngine.containsBinding(strValue) {
                    let resolvedValue = expressionEngine.resolveBinding(strValue, context: data)
                    applyResolvedValue(key: key, value: resolvedValue, to: component)
                }
            }
        }
        
        // 处理 bindings 中的表达式
        if let bindings = json.bindings {
            for (key, value) in bindings.rawDictionary {
                if let strValue = value as? String, expressionEngine.containsBinding(strValue) {
                    let resolvedValue = expressionEngine.resolveBinding(strValue, context: data)
                    applyResolvedValue(key: key, value: resolvedValue, to: component)
                }
            }
        }
    }
    
    /// 将解析后的值应用到组件
    private func applyResolvedValue(key: String, value: Any?, to component: BaseComponent) {
        guard let value = value else { return }
        
        // 根据组件类型和属性名应用值
        switch key {
        case "text":
            if let textComponent = component as? TextComponent {
                textComponent.text = stringValue(value)
            }
            
        case "src", "source", "imageUrl", "url":
            if let imageComponent = component as? ImageComponent {
                imageComponent.src = stringValue(value)
            }
            
        case "visible", "visibility":
            // 控制 visibility 属性（占空间但不可见）
            let isVisible = boolValue(value)
            component.style.visibility = isVisible ? .visible : .hidden
            
        case "display":
            // 控制 display 属性（不占空间）
            // 支持布尔值 true/false 或字符串 "flex"/"none"
            let newDisplay: Display
            if let boolVal = value as? Bool {
                newDisplay = boolVal ? .flex : .none
            } else {
                let displayValue = stringValue(value).lowercased()
                newDisplay = displayValue == "none" ? .none : .flex
            }
            component.style.display = newDisplay
            
        case "opacity", "alpha":
            component.style.opacity = cgFloatValue(value)
            
        case "backgroundColor", "bgColor":
            if let colorValue = colorValue(value) {
                component.style.backgroundColor = colorValue
            }
            
        case "color", "textColor":
            if let textComponent = component as? TextComponent,
               let colorValue = colorValue(value) {
                textComponent.textColor = colorValue
            }
            
        case "fontSize":
            if let textComponent = component as? TextComponent {
                textComponent.fontSize = cgFloatValue(value)
            }
            
        case "numberOfLines", "lines", "maxLines":
            if let textComponent = component as? TextComponent {
                textComponent.numberOfLines = intValue(value)
            }
            
        // 布局属性 - 现在统一在 style 中
        case "width":
            let dim = dimensionValue(value)
            component.style.width = dim
            
        case "height":
            let dim = dimensionValue(value)
            component.style.height = dim
            
        case "flexGrow":
            component.style.flexGrow = cgFloatValue(value)
            
        case "flexShrink":
            component.style.flexShrink = cgFloatValue(value)
            
        default:
            // 存储到 bindings 供组件自行处理
            component.bindings[key] = value
        }
    }
    
    // MARK: - List Binding
    
    /// 绑定列表数据
    /// 用于 for-each 循环渲染
    public func bindList<T>(
        items: [T],
        itemKey: String = "item",
        to component: Component,
        templateFactory: (T, Int) -> Component
    ) -> [Component] {
        return items.enumerated().map { index, item in
            let childComponent = templateFactory(item, index)
            
            // 构建 item 上下文
            var itemContext: [String: Any] = [
                itemKey: item,
                "$index": index,
                "$first": index == 0,
                "$last": index == items.count - 1,
                "$odd": index % 2 == 1,
                "$even": index % 2 == 0
            ]
            
            // 如果 item 是字典，展开到上下文
            if let dict = item as? [String: Any] {
                for (key, value) in dict {
                    itemContext[key] = value
                }
            }
            
            // 绑定数据
            if let baseComponent = childComponent as? BaseComponent {
                baseComponent.bindings = itemContext
            }
            
            return childComponent
        }
    }
    
    // MARK: - Value Conversion Helpers
    
    private func stringValue(_ value: Any) -> String {
        switch value {
        case let str as String: return str
        case let num as Double:
            return num.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(num)) : String(num)
        case let num as Int: return String(num)
        case let bool as Bool: return bool ? "true" : "false"
        default: return String(describing: value)
        }
    }
    
    private func intValue(_ value: Any) -> Int {
        switch value {
        case let num as Int: return num
        case let num as Double: return Int(num)
        case let str as String: return Int(str) ?? 0
        default: return 0
        }
    }
    
    private func cgFloatValue(_ value: Any) -> CGFloat {
        switch value {
        case let num as Double: return CGFloat(num)
        case let num as Int: return CGFloat(num)
        case let num as CGFloat: return num
        case let str as String: return CGFloat(Double(str) ?? 0)
        default: return 0
        }
    }
    
    private func boolValue(_ value: Any) -> Bool {
        switch value {
        case let bool as Bool: return bool
        case let num as Int: return num != 0
        case let num as Double: return num != 0
        case let str as String:
            let lower = str.lowercased()
            return lower == "true" || lower == "yes" || lower == "1"
        default: return true
        }
    }
    
    private func colorValue(_ value: Any) -> UIColor? {
        if let color = value as? UIColor {
            return color
        }
        
        if let str = value as? String {
            return UIColor(hexString: str)
        }
        
        return nil
    }
    
    private func dimensionValue(_ value: Any) -> Dimension {
        switch value {
        case let dim as Dimension:
            return dim
        case let num as Double:
            return .point(CGFloat(num))
        case let num as Int:
            return .point(CGFloat(num))
        case let str as String:
            return parseDimension(str)
        default:
            return .auto
        }
    }
    
    private func parseDimension(_ str: String) -> Dimension {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        
        if trimmed == "auto" {
            return .auto
        }
        
        if trimmed.hasSuffix("%") {
            let numStr = String(trimmed.dropLast())
            if let num = Double(numStr) {
                return .percent(CGFloat(num))
            }
        }
        
        if let num = Double(trimmed.replacingOccurrences(of: "px", with: "")) {
            return .point(CGFloat(num))
        }
        
        return .auto
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
        
        switch hex.count {
        case 3: // RGB (12-bit)
            let r = CGFloat((rgb >> 8) & 0xF) / 15.0
            let g = CGFloat((rgb >> 4) & 0xF) / 15.0
            let b = CGFloat(rgb & 0xF) / 15.0
            self.init(red: r, green: g, blue: b, alpha: 1)
            
        case 6: // RGB (24-bit)
            let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
            let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
            let b = CGFloat(rgb & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1)
            
        case 8: // ARGB (32-bit)
            let a = CGFloat((rgb >> 24) & 0xFF) / 255.0
            let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
            let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
            let b = CGFloat(rgb & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
            
        default:
            return nil
        }
    }
    
    /// 颜色转十六进制字符串
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let ir = Int(r * 255)
        let ig = Int(g * 255)
        let ib = Int(b * 255)
        let ia = Int(a * 255)
        
        if ia == 255 {
            return String(format: "#%02X%02X%02X", ir, ig, ib)
        } else {
            return String(format: "#%02X%02X%02X%02X", ia, ir, ig, ib)
        }
    }
}
