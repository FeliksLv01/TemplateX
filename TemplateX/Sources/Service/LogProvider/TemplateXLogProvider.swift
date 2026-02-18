import Foundation

// MARK: - TXLogLevel

/// 日志级别
public enum TXLogLevel: Int, Comparable {
    case error = 0
    case warning = 1
    case info = 2
    case debug = 3
    case trace = 4
    case verbose = 5
    
    public static func < (lhs: TXLogLevel, rhs: TXLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var name: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warn"
        case .info: return "Info"
        case .debug: return "Debug"
        case .trace: return "Trace"
        case .verbose: return "Verbose"
        }
    }
}

// MARK: - TemplateXLogProvider

/// 日志服务协议
///
/// 可通过实现此协议注入自定义日志实现。
///
/// 使用示例：
/// ```swift
/// class MyLogProvider: TemplateXLogProvider {
///     var minLevel: TXLogLevel = .debug
///
///     func log(level: TXLogLevel, message: String, file: String, function: String, line: Int) {
///         // 自定义日志处理
///     }
/// }
///
/// // 注册
/// TemplateX.registerLogProvider(MyLogProvider())
/// ```
public protocol TemplateXLogProvider: AnyObject {
    
    /// 最小日志级别（低于此级别的日志不输出）
    var minLevel: TXLogLevel { get set }
    
    /// 输出日志
    ///
    /// - Parameters:
    ///   - level: 日志级别
    ///   - message: 日志内容
    ///   - file: 调用文件
    ///   - function: 调用函数
    ///   - line: 调用行号
    func log(
        level: TXLogLevel,
        message: String,
        file: String,
        function: String,
        line: Int
    )
}
