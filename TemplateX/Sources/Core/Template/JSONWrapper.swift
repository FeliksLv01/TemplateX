import Foundation

// MARK: - JSON Wrapper

/// JSON 包装器 - 延迟解析，按需读取，避免反序列化开销
@dynamicMemberLookup
public final class JSONWrapper {
    
    // MARK: - Storage
    
    /// 底层 JSON 数据
    private let json: [String: Any]
    
    /// 缓存已解析的子对象
    private var childCache: [String: JSONWrapper] = [:]
    
    /// 缓存已解析的数组
    private var arrayCache: [String: [JSONWrapper]] = [:]
    
    // MARK: - Init
    
    public init(_ json: [String: Any]) {
        self.json = json
    }
    
    public convenience init?(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        self.init(json)
    }
    
    // MARK: - 动态成员查找
    
    public subscript(dynamicMember key: String) -> JSONWrapper? {
        return child(key)
    }
    
    // MARK: - 子对象访问
    
    /// 获取子对象（延迟创建并缓存）
    @inline(__always)
    public func child(_ key: String) -> JSONWrapper? {
        // 先查缓存
        if let cached = childCache[key] {
            return cached
        }
        
        // 解析并缓存
        guard let value = json[key] as? [String: Any] else {
            return nil
        }
        
        let wrapper = JSONWrapper(value)
        childCache[key] = wrapper
        return wrapper
    }
    
    /// 获取子对象数组（延迟创建并缓存）
    public func array(_ key: String) -> [JSONWrapper] {
        // 先查缓存
        if let cached = arrayCache[key] {
            return cached
        }
        
        // 解析并缓存
        guard let arr = json[key] as? [[String: Any]] else {
            return []
        }
        
        let wrappers = arr.map { JSONWrapper($0) }
        arrayCache[key] = wrappers
        return wrappers
    }
    
    /// children 快捷访问
    public var children: [JSONWrapper] {
        return array("children")
    }
    
    // MARK: - 基础类型访问
    
    /// 获取字符串
    @inline(__always)
    public func string(_ key: String) -> String? {
        json[key] as? String
    }
    
    /// 获取字符串（带默认值）
    @inline(__always)
    public func string(_ key: String, default: String) -> String {
        (json[key] as? String) ?? `default`
    }
    
    /// 获取整数
    @inline(__always)
    public func int(_ key: String) -> Int? {
        if let int = json[key] as? Int {
            return int
        }
        if let double = json[key] as? Double {
            return Int(double)
        }
        return nil
    }
    
    /// 获取整数（带默认值）
    @inline(__always)
    public func int(_ key: String, default: Int) -> Int {
        int(key) ?? `default`
    }
    
    /// 获取浮点数
    @inline(__always)
    public func double(_ key: String) -> Double? {
        if let double = json[key] as? Double {
            return double
        }
        if let int = json[key] as? Int {
            return Double(int)
        }
        return nil
    }
    
    /// 获取 CGFloat
    @inline(__always)
    public func cgFloat(_ key: String) -> CGFloat? {
        guard let d = double(key) else { return nil }
        return CGFloat(d)
    }
    
    /// 获取 CGFloat（带默认值）
    @inline(__always)
    public func cgFloat(_ key: String, default: CGFloat) -> CGFloat {
        cgFloat(key) ?? `default`
    }
    
    /// 获取布尔值
    @inline(__always)
    public func bool(_ key: String) -> Bool? {
        json[key] as? Bool
    }
    
    /// 获取布尔值（带默认值）
    @inline(__always)
    public func bool(_ key: String, default: Bool) -> Bool {
        bool(key) ?? `default`
    }
    
    /// 获取任意值
    @inline(__always)
    public func any(_ key: String) -> Any? {
        json[key]
    }
    
    /// 获取原始字典
    public var rawDictionary: [String: Any] {
        json
    }
    
    /// 判断是否包含某个键
    @inline(__always)
    public func contains(_ key: String) -> Bool {
        json[key] != nil
    }
    
    // MARK: - 便捷访问
    
    /// 组件 ID
    public var id: String? {
        string("id")
    }
    
    /// 组件类型
    public var type: String? {
        string("type")
    }
    
    /// 属性对象
    public var props: JSONWrapper? {
        child("props")
    }
    
    /// 绑定对象
    public var bindings: JSONWrapper? {
        child("bindings")
    }
    
    /// 事件对象
    public var events: JSONWrapper? {
        child("events")
    }
}

// MARK: - 颜色解析

import UIKit

extension JSONWrapper {
    
    /// 解析颜色
    public func color(_ key: String) -> UIColor? {
        guard let value = json[key] else { return nil }
        
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

// MARK: - UIColor 扩展

extension UIColor {
    
    /// 从十六进制字符串创建颜色
    static func tx_color(from hex: String) -> UIColor? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        
        switch hexString.count {
        case 6: // RGB
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                blue: CGFloat(rgb & 0xFF) / 255.0,
                alpha: 1.0
            )
        case 8: // ARGB
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                blue: CGFloat(rgb & 0xFF) / 255.0,
                alpha: CGFloat((rgb >> 24) & 0xFF) / 255.0
            )
        default:
            return nil
        }
    }
    
    /// 从整数创建颜色（预编译后的格式）
    static func tx_color(from int: Int) -> UIColor {
        return UIColor(
            red: CGFloat((int >> 16) & 0xFF) / 255.0,
            green: CGFloat((int >> 8) & 0xFF) / 255.0,
            blue: CGFloat(int & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - 尺寸解析

extension JSONWrapper {
    
    /// 解析尺寸值（返回 Dimension 类型）
    /// 支持：数字（固定点数）、百分比字符串（如 "50%"）、"auto"
    public func dimension(_ key: String) -> Dimension {
        guard let value = json[key] else {
            return .auto
        }
        
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
    
    /// 解析边距
    public func edgeInsets(_ key: String) -> EdgeInsets {
        guard let value = json[key] else {
            return .zero
        }
        
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
                    top: CGFloat(arr[0] as? Double ?? 0),
                    left: CGFloat(arr[3] as? Double ?? 0),
                    bottom: CGFloat(arr[2] as? Double ?? 0),
                    right: CGFloat(arr[1] as? Double ?? 0)
                )
            } else if arr.count == 2 {
                let v = CGFloat(arr[0] as? Double ?? 0)
                let h = CGFloat(arr[1] as? Double ?? 0)
                return EdgeInsets(horizontal: h, vertical: v)
            }
        }
        
        // 对象 - { top, left, bottom, right }
        if let obj = value as? [String: Any] {
            return EdgeInsets(
                top: CGFloat(obj["top"] as? Double ?? 0),
                left: CGFloat(obj["left"] as? Double ?? 0),
                bottom: CGFloat(obj["bottom"] as? Double ?? 0),
                right: CGFloat(obj["right"] as? Double ?? 0)
            )
        }
        
        return .zero
    }
}
