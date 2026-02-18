import Foundation
import os.log

/// 默认日志实现
///
/// - iOS 14+: 使用 os.Logger（高性能，支持 Instruments）
/// - iOS 14-: 静默不输出（避免 print 性能问题）
///
/// 如需在 iOS 14- 输出日志，可使用 TemplateXService/Log 中的 ConsoleLogProvider
public final class DefaultLogProvider: TemplateXLogProvider {
    
    public static let shared = DefaultLogProvider()
    
    /// 最小日志级别
    ///
    /// - DEBUG 模式：默认 .debug
    /// - Release 模式：默认 .error
    public var minLevel: TXLogLevel
    
    private let logger: Any?
    
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
        
        if #available(iOS 14.0, *) {
            self.logger = Logger(subsystem: "com.templatex", category: "TemplateX")
        } else {
            self.logger = nil
        }
    }
    
    public func log(
        level: TXLogLevel,
        message: String,
        file: String,
        function: String,
        line: Int
    ) {
        guard level <= minLevel else { return }
        
        if #available(iOS 14.0, *), let logger = logger as? Logger {
            let fileName = (file as NSString).lastPathComponent
            let output = "[\(fileName):\(line)] \(message)"
            
            switch level {
            case .error:
                logger.error("\(output)")
            case .warning:
                logger.warning("\(output)")
            case .info:
                logger.info("\(output)")
            case .debug:
                logger.debug("\(output)")
            case .trace, .verbose:
                logger.trace("\(output)")
            }
        }
        // iOS 14- 静默不输出
    }
}
