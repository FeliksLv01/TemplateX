import Foundation

// MARK: - Expression Function Protocol

/// 表达式函数协议
public protocol ExpressionFunction {
    /// 函数名
    var name: String { get }
    
    /// 执行函数
    func execute(_ args: [Any]) -> Any?
}

// MARK: - Simple Function Wrapper

/// 简单函数包装器
public struct SimpleFunction: ExpressionFunction {
    public let name: String
    private let handler: ([Any]) -> Any?
    
    public init(name: String, handler: @escaping ([Any]) -> Any?) {
        self.name = name
        self.handler = handler
    }
    
    public func execute(_ args: [Any]) -> Any? {
        handler(args)
    }
}

// MARK: - Builtin Functions

/// 内置函数库
public enum BuiltinFunctions {
    
    /// 所有内置函数
    public static let all: [String: ExpressionFunction] = [
        // 数学函数
        "abs": SimpleFunction(name: "abs") { args in
            guard let num = args.first else { return 0.0 }
            return abs(toDouble(num))
        },
        "max": SimpleFunction(name: "max") { args in
            let nums = args.map { toDouble($0) }
            return nums.max() ?? 0.0
        },
        "min": SimpleFunction(name: "min") { args in
            let nums = args.map { toDouble($0) }
            return nums.min() ?? 0.0
        },
        "round": SimpleFunction(name: "round") { args in
            guard let num = args.first else { return 0.0 }
            return round(toDouble(num))
        },
        "floor": SimpleFunction(name: "floor") { args in
            guard let num = args.first else { return 0.0 }
            return floor(toDouble(num))
        },
        "ceil": SimpleFunction(name: "ceil") { args in
            guard let num = args.first else { return 0.0 }
            return ceil(toDouble(num))
        },
        "sqrt": SimpleFunction(name: "sqrt") { args in
            guard let num = args.first else { return 0.0 }
            return sqrt(toDouble(num))
        },
        "pow": SimpleFunction(name: "pow") { args in
            guard args.count >= 2 else { return 0.0 }
            return pow(toDouble(args[0]), toDouble(args[1]))
        },
        
        // 字符串函数
        "length": SimpleFunction(name: "length") { args in
            if let str = args.first as? String {
                return Double(str.count)
            }
            if let arr = args.first as? [Any] {
                return Double(arr.count)
            }
            return 0.0
        },
        "uppercase": SimpleFunction(name: "uppercase") { args in
            guard let str = args.first as? String else { return "" }
            return str.uppercased()
        },
        "lowercase": SimpleFunction(name: "lowercase") { args in
            guard let str = args.first as? String else { return "" }
            return str.lowercased()
        },
        "trim": SimpleFunction(name: "trim") { args in
            guard let str = args.first as? String else { return "" }
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        },
        "substring": SimpleFunction(name: "substring") { args in
            guard let str = args.first as? String,
                  args.count >= 2 else { return "" }
            
            let start = Int(toDouble(args[1]))
            let length = args.count > 2 ? Int(toDouble(args[2])) : str.count - start
            
            guard start >= 0 && start < str.count else { return "" }
            
            let startIndex = str.index(str.startIndex, offsetBy: start)
            let endIndex = str.index(startIndex, offsetBy: min(length, str.count - start))
            return String(str[startIndex..<endIndex])
        },
        "contains": SimpleFunction(name: "contains") { args in
            guard args.count >= 2,
                  let str = args[0] as? String,
                  let search = args[1] as? String else { return false }
            return str.contains(search)
        },
        "startsWith": SimpleFunction(name: "startsWith") { args in
            guard args.count >= 2,
                  let str = args[0] as? String,
                  let prefix = args[1] as? String else { return false }
            return str.hasPrefix(prefix)
        },
        "endsWith": SimpleFunction(name: "endsWith") { args in
            guard args.count >= 2,
                  let str = args[0] as? String,
                  let suffix = args[1] as? String else { return false }
            return str.hasSuffix(suffix)
        },
        "replace": SimpleFunction(name: "replace") { args in
            guard args.count >= 3,
                  let str = args[0] as? String,
                  let search = args[1] as? String,
                  let replacement = args[2] as? String else { return "" }
            return str.replacingOccurrences(of: search, with: replacement)
        },
        "split": SimpleFunction(name: "split") { args in
            guard args.count >= 2,
                  let str = args[0] as? String,
                  let separator = args[1] as? String else { return [] }
            return str.components(separatedBy: separator)
        },
        "join": SimpleFunction(name: "join") { args in
            guard args.count >= 2,
                  let arr = args[0] as? [Any],
                  let separator = args[1] as? String else { return "" }
            return arr.map { toString($0) }.joined(separator: separator)
        },
        
        // 格式化函数
        "formatNumber": SimpleFunction(name: "formatNumber") { args in
            guard let num = args.first else { return "" }
            let value = toDouble(num)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if args.count > 1, let decimals = args[1] as? Double {
                formatter.minimumFractionDigits = Int(decimals)
                formatter.maximumFractionDigits = Int(decimals)
            }
            return formatter.string(from: NSNumber(value: value)) ?? ""
        },
        "formatDate": SimpleFunction(name: "formatDate") { args in
            guard args.count >= 2,
                  let format = args[1] as? String else { return "" }
            
            let timestamp: TimeInterval
            if let ts = args[0] as? Double {
                timestamp = ts
            } else if let ts = args[0] as? Int {
                timestamp = Double(ts)
            } else {
                return ""
            }
            
            // 判断是秒还是毫秒
            let date: Date
            if timestamp > 1_000_000_000_000 {
                date = Date(timeIntervalSince1970: timestamp / 1000)
            } else {
                date = Date(timeIntervalSince1970: timestamp)
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter.string(from: date)
        },
        
        // 条件函数
        "ifEmpty": SimpleFunction(name: "ifEmpty") { args in
            guard args.count >= 2 else { return nil }
            let value = args[0]
            let fallback = args[1]
            
            if let str = value as? String, str.isEmpty {
                return fallback
            }
            if value is NSNull {
                return fallback
            }
            return value
        },
        "ifNull": SimpleFunction(name: "ifNull") { args in
            guard args.count >= 2 else { return nil }
            let value = args[0]
            let fallback = args[1]
            
            if value is NSNull {
                return fallback
            }
            return value
        },
        
        // 类型转换函数
        "toString": SimpleFunction(name: "toString") { args in
            guard let value = args.first else { return "" }
            return toString(value)
        },
        "toNumber": SimpleFunction(name: "toNumber") { args in
            guard let value = args.first else { return 0.0 }
            return toDouble(value)
        },
        "toBoolean": SimpleFunction(name: "toBoolean") { args in
            guard let value = args.first else { return false }
            return toBool(value)
        },
        
        // 数组函数
        "first": SimpleFunction(name: "first") { args in
            guard let arr = args.first as? [Any] else { return nil }
            return arr.first
        },
        "last": SimpleFunction(name: "last") { args in
            guard let arr = args.first as? [Any] else { return nil }
            return arr.last
        },
        "indexOf": SimpleFunction(name: "indexOf") { args in
            guard args.count >= 2 else { return -1.0 }
            
            if let arr = args[0] as? [Any] {
                for (index, element) in arr.enumerated() {
                    if isEqual(element, args[1]) {
                        return Double(index)
                    }
                }
                return -1.0
            }
            
            if let str = args[0] as? String, let search = args[1] as? String {
                if let range = str.range(of: search) {
                    return Double(str.distance(from: str.startIndex, to: range.lowerBound))
                }
                return -1.0
            }
            
            return -1.0
        },
        "reverse": SimpleFunction(name: "reverse") { args in
            if let arr = args.first as? [Any] {
                return arr.reversed() as [Any]
            }
            if let str = args.first as? String {
                return String(str.reversed())
            }
            return nil
        },
    ]
    
    // MARK: - Helper Functions
    
    private static func toDouble(_ value: Any) -> Double {
        switch value {
        case let num as Double: return num
        case let num as Int: return Double(num)
        case let str as String: return Double(str) ?? 0
        case let bool as Bool: return bool ? 1 : 0
        default: return 0
        }
    }
    
    private static func toString(_ value: Any) -> String {
        switch value {
        case let str as String: return str
        case let num as Double:
            return num.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(num)) : String(num)
        case let num as Int: return String(num)
        case let bool as Bool: return bool ? "true" : "false"
        default: return String(describing: value)
        }
    }
    
    private static func toBool(_ value: Any) -> Bool {
        switch value {
        case let bool as Bool: return bool
        case let num as Double: return num != 0
        case let num as Int: return num != 0
        case let str as String: return !str.isEmpty && str != "false" && str != "0"
        default: return true
        }
    }
    
    private static func isEqual(_ left: Any, _ right: Any) -> Bool {
        switch (left, right) {
        case (let l as Bool, let r as Bool): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Int): return l == Double(r)
        case (let l as Int, let r as Double): return Double(l) == r
        case (let l as String, let r as String): return l == r
        default: return false
        }
    }
}
