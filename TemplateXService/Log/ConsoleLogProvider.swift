import Foundation
import TemplateX

/// Console 日志实现
///
/// 使用 print 输出日志，适用于调试场景或 iOS 14 以下的设备。
///
/// 使用示例：
/// ```swift
/// // AppDelegate.swift
/// import TemplateXService
///
/// func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) {
///     TemplateX.registerLogProvider(ConsoleLogProvider())
/// }
/// ```
///
/// Podfile 配置：
/// ```ruby
/// pod 'TemplateX'
/// pod 'TemplateXService/Log'
/// ```
public final class ConsoleLogProvider: TemplateXLogProvider {
    
    /// 最小日志级别
    ///
    /// - DEBUG 模式：默认 .debug
    /// - Release 模式：默认 .error
    public var minLevel: TXLogLevel
    
    /// 是否启用日志输出
    public var isEnabled: Bool = true
    
    public init(minLevel: TXLogLevel? = nil) {
        if let level = minLevel {
            self.minLevel = level
        } else {
            #if DEBUG
            self.minLevel = .debug
            #else
            self.minLevel = .error
            #endif
        }
    }
    
    public func log(
        level: TXLogLevel,
        message: String,
        file: String,
        function: String,
        line: Int
    ) {
        guard isEnabled else { return }
        guard level <= minLevel else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let output = "[TemplateX][\(level.name)] \(fileName):\(line) - \(message)"
        print(output)
    }
}
