import Foundation

/// 日志门面类
///
/// 提供静态方法简化日志调用，内部转发到 ServiceRegistry.logProvider
///
/// 使用示例：
/// ```swift
/// TXLogger.debug("Loading template: \(templateName)")
/// TXLogger.error("Failed to parse JSON")
/// ```
public enum TXLogger {
    
    /// 是否启用 verbose 日志（默认 false）
    ///
    /// verbose 日志是高频日志，会影响性能，仅用于调试
    public static var verboseEnabled: Bool = false
    
    /// 获取当前 LogProvider
    private static var provider: TemplateXLogProvider {
        ServiceRegistry.shared.logProvider
    }
    
    // MARK: - Log Methods
    
    public static func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        provider.log(level: .error, message: message(), file: file, function: function, line: line)
    }
    
    public static func warning(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        provider.log(level: .warning, message: message(), file: file, function: function, line: line)
    }
    
    public static func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        provider.log(level: .info, message: message(), file: file, function: function, line: line)
    }
    
    public static func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        provider.log(level: .debug, message: message(), file: file, function: function, line: line)
    }
    
    public static func trace(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        provider.log(level: .trace, message: message(), file: file, function: function, line: line)
    }
    
    public static func verbose(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // verbose 日志需要显式开启
        guard verboseEnabled else { return }
        provider.log(level: .verbose, message: message(), file: file, function: function, line: line)
    }
}
