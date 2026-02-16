import Foundation
import CoreGraphics

// MARK: - 单位解析器

/// 单位解析器 - 解析 dp/sp/px/% 等单位
public struct UnitParser {
    
    /// 屏幕密度（用于 dp 转换）
    public static var screenScale: CGFloat = 1.0
    
    /// 基础字体大小（用于 sp 转换）
    public static var baseFontSize: CGFloat = 16.0
    
    /// 字体缩放因子（用于 sp 转换）
    public static var fontScaleFactor: CGFloat = 1.0
    
    // MARK: - 解析尺寸
    
    /// 解析尺寸值
    /// - Parameters:
    ///   - value: 尺寸字符串，如 "100dp", "16sp", "50%", "auto"
    ///   - containerSize: 容器尺寸（用于百分比计算）
    /// - Returns: 解析后的值（JSON 格式）
    public static func parseDimension(_ value: String, containerSize: CGFloat? = nil) -> Any {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        
        // auto - 自动尺寸
        if trimmed == "auto" {
            return "auto"
        }
        
        // 百分比
        if trimmed.hasSuffix("%") {
            let numStr = String(trimmed.dropLast())
            if let num = Double(numStr) {
                // 百分比编译为字符串 "50%"
                return "\(num)%"
            }
        }
        
        // dp (density-independent pixels)
        if trimmed.hasSuffix("dp") || trimmed.hasSuffix("dip") {
            let numStr = trimmed.replacingOccurrences(of: "dp", with: "")
                                .replacingOccurrences(of: "dip", with: "")
            if let num = Double(numStr) {
                // dp 直接编译为数值（运行时由设备处理）
                return num
            }
        }
        
        // sp (scalable pixels, 字体单位)
        if trimmed.hasSuffix("sp") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Double(numStr) {
                // sp 编译为对象 { "type": "sp", "value": 16 }
                return ["type": "sp", "value": num]
            }
        }
        
        // px (physical pixels)
        if trimmed.hasSuffix("px") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Double(numStr) {
                // px 转换为 dp
                return num / Double(screenScale)
            }
        }
        
        // 纯数字
        if let num = Double(trimmed) {
            return num
        }
        
        // 无法解析，返回原始值
        return value
    }
    
    // MARK: - 解析字体大小
    
    /// 解析字体大小
    public static func parseFontSize(_ value: String) -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        
        // sp
        if trimmed.hasSuffix("sp") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Double(numStr) {
                return num * fontScaleFactor
            }
        }
        
        // dp
        if trimmed.hasSuffix("dp") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Double(numStr) {
                return num
            }
        }
        
        // px
        if trimmed.hasSuffix("px") {
            let numStr = String(trimmed.dropLast(2))
            if let num = Double(numStr) {
                return num / Double(screenScale)
            }
        }
        
        // 纯数字
        if let num = Double(trimmed) {
            return num
        }
        
        // 默认
        return baseFontSize
    }
    
    // MARK: - 解析边距
    
    /// 解析边距值
    /// 支持格式：
    /// - "16dp" -> [16, 16, 16, 16]
    /// - "16dp 8dp" -> [16, 8, 16, 8] (vertical, horizontal)
    /// - "16dp 8dp 12dp 4dp" -> [16, 8, 12, 4] (top, right, bottom, left)
    public static func parseEdgeInsets(_ value: String) -> [Double] {
        let parts = value.split(separator: " ").map { String($0) }
        
        switch parts.count {
        case 1:
            let v = parseNumericValue(parts[0])
            return [v, v, v, v]
            
        case 2:
            let vertical = parseNumericValue(parts[0])
            let horizontal = parseNumericValue(parts[1])
            return [vertical, horizontal, vertical, horizontal]
            
        case 4:
            return parts.map { parseNumericValue($0) }
            
        default:
            return [0, 0, 0, 0]
        }
    }
    
    /// 解析纯数值（去除单位）
    public static func parseNumericValue(_ value: String) -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        
        // 去除各种单位后缀
        var numStr = trimmed
        for suffix in ["dp", "dip", "sp", "px", "%"] {
            if numStr.hasSuffix(suffix) {
                numStr = String(numStr.dropLast(suffix.count))
                break
            }
        }
        
        return Double(numStr) ?? 0
    }
}

// MARK: - 颜色解析

extension UnitParser {
    
    /// 解析颜色值
    /// 支持格式：
    /// - "#RGB"
    /// - "#RRGGBB"
    /// - "#AARRGGBB"
    /// - "rgb(255, 0, 0)"
    /// - "rgba(255, 0, 0, 0.5)"
    public static func parseColor(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // 已经是标准格式
        if trimmed.hasPrefix("#") {
            return normalizeHexColor(trimmed)
        }
        
        // rgb()
        if trimmed.lowercased().hasPrefix("rgb(") {
            return parseRGBFunction(trimmed)
        }
        
        // rgba()
        if trimmed.lowercased().hasPrefix("rgba(") {
            return parseRGBAFunction(trimmed)
        }
        
        // 颜色名称
        if let hex = colorNameToHex(trimmed) {
            return hex
        }
        
        return value
    }
    
    /// 标准化十六进制颜色
    private static func normalizeHexColor(_ hex: String) -> String {
        var color = hex.trimmingCharacters(in: .whitespaces)
        
        if color.hasPrefix("#") {
            color.removeFirst()
        }
        
        switch color.count {
        case 3: // RGB -> RRGGBB
            let r = String(color[color.startIndex])
            let g = String(color[color.index(color.startIndex, offsetBy: 1)])
            let b = String(color[color.index(color.startIndex, offsetBy: 2)])
            return "#\(r)\(r)\(g)\(g)\(b)\(b)"
            
        case 4: // ARGB -> AARRGGBB
            let a = String(color[color.startIndex])
            let r = String(color[color.index(color.startIndex, offsetBy: 1)])
            let g = String(color[color.index(color.startIndex, offsetBy: 2)])
            let b = String(color[color.index(color.startIndex, offsetBy: 3)])
            return "#\(a)\(a)\(r)\(r)\(g)\(g)\(b)\(b)"
            
        case 6, 8:
            return "#\(color.uppercased())"
            
        default:
            return "#\(color)"
        }
    }
    
    /// 解析 rgb() 函数
    private static func parseRGBFunction(_ value: String) -> String {
        let content = value.dropFirst(4).dropLast() // 去除 "rgb(" 和 ")"
        let components = content.split(separator: ",").map { 
            Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 
        }
        
        guard components.count >= 3 else { return value }
        
        let r = min(255, max(0, components[0]))
        let g = min(255, max(0, components[1]))
        let b = min(255, max(0, components[2]))
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    /// 解析 rgba() 函数
    private static func parseRGBAFunction(_ value: String) -> String {
        let content = value.dropFirst(5).dropLast() // 去除 "rgba(" 和 ")"
        let parts = content.split(separator: ",").map { 
            $0.trimmingCharacters(in: .whitespaces) 
        }
        
        guard parts.count >= 4 else { return value }
        
        let r = min(255, max(0, Int(parts[0]) ?? 0))
        let g = min(255, max(0, Int(parts[1]) ?? 0))
        let b = min(255, max(0, Int(parts[2]) ?? 0))
        let a = min(255, max(0, Int((Double(parts[3]) ?? 1.0) * 255)))
        
        return String(format: "#%02X%02X%02X%02X", a, r, g, b)
    }
    
    /// 颜色名称映射
    private static func colorNameToHex(_ name: String) -> String? {
        let colorMap: [String: String] = [
            "white": "#FFFFFF",
            "black": "#000000",
            "red": "#FF0000",
            "green": "#00FF00",
            "blue": "#0000FF",
            "yellow": "#FFFF00",
            "cyan": "#00FFFF",
            "magenta": "#FF00FF",
            "orange": "#FFA500",
            "purple": "#800080",
            "pink": "#FFC0CB",
            "gray": "#808080",
            "grey": "#808080",
            "transparent": "#00000000"
        ]
        
        return colorMap[name.lowercased()]
    }
}
