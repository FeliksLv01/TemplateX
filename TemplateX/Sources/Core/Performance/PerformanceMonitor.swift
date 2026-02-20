import Foundation
import os.lock

// MARK: - 性能监控系统

/// 性能监控器 - 追踪渲染各阶段耗时
public final class PerformanceMonitor {
    
    public static let shared = PerformanceMonitor()
    
    // MARK: - 配置
    
    /// 是否启用监控
    public var isEnabled: Bool = false
    
    /// 是否打印到控制台
    public var printToConsole: Bool = false
    
    /// 慢渲染阈值（毫秒），超过则警告
    public var slowRenderThreshold: Double = 16.67  // 60fps = 16.67ms
    
    /// 自定义上报回调
    public var reportCallback: ((TraceSession) -> Void)?
    
    /// 聚合统计（用于计算平均值）
    private var aggregatedStats: [String: AggregatedMetric] = [:]
    
    /// 高性能自旋锁
    private var statsLock = os_unfair_lock()
    
    // MARK: - 平均绑定时间（GapWorker 使用）
    
    /// 按模板 ID 存储的平均绑定时间（纳秒）
    /// 对应 Lynx: list_adapter.cc:109 GetAverageBindTime
    private var averageBindTimes: [String: Int64] = [:]
    
    /// 默认绑定时间（纳秒）- 用于首次预加载估算
    /// 默认 2ms = 2,000,000 纳秒
    public var defaultBindTimeNanos: Int64 = 2_000_000
    
    private init() {}
    
    // MARK: - API
    
    /// 开始一个追踪会话
    @inline(__always)
    public func beginTrace(_ name: String, templateId: String? = nil) -> TraceSession {
        guard isEnabled else {
            return TraceSession(name: name, templateId: templateId, isEnabled: false)
        }
        return TraceSession(name: name, templateId: templateId, isEnabled: true)
    }
    
    /// 上报会话结果
    func report(_ session: TraceSession) {
        guard session.isEnabled else { return }
        
        // 打印到控制台
        if printToConsole {
            printSession(session)
        }
        
        // 聚合统计
        aggregateSession(session)
        
        // 自定义回调
        reportCallback?(session)
    }
    
    /// 获取聚合统计
    public func getAggregatedStats() -> [String: AggregatedMetric] {
        os_unfair_lock_lock(&statsLock)
        defer { os_unfair_lock_unlock(&statsLock) }
        return aggregatedStats
    }
    
    /// 重置统计
    public func resetStats() {
        os_unfair_lock_lock(&statsLock)
        defer { os_unfair_lock_unlock(&statsLock) }
        aggregatedStats.removeAll()
    }
    
    // MARK: - 平均绑定时间 API（GapWorker 使用）
    
    /// 获取指定模板的平均绑定时间（纳秒）
    /// 对应 Lynx: list_adapter.cc:109 GetAverageBindTime
    /// - Parameter templateId: 模板 ID
    /// - Returns: 平均绑定时间（纳秒），如果没有记录则返回默认值
    public func getAverageBindTime(templateId: String) -> Int64 {
        os_unfair_lock_lock(&statsLock)
        defer { os_unfair_lock_unlock(&statsLock) }
        return averageBindTimes[templateId] ?? defaultBindTimeNanos
    }
    
    /// 更新平均绑定时间
    /// 使用加权平均：newAverage = oldAverage * 0.75 + newValue * 0.25
    /// 对应 Lynx: list_adapter.cc:17 CalculateAverage
    /// - Parameters:
    ///   - templateId: 模板 ID
    ///   - newValue: 新的绑定时间（纳秒）
    public func updateAverageBindTime(templateId: String, newValue: Int64) {
        os_unfair_lock_lock(&statsLock)
        defer { os_unfair_lock_unlock(&statsLock) }
        
        if let oldAverage = averageBindTimes[templateId] {
            // 加权平均：oldAverage * 3/4 + newValue * 1/4
            averageBindTimes[templateId] = (oldAverage * 3 / 4) + (newValue / 4)
        } else {
            averageBindTimes[templateId] = newValue
        }
    }
    
    /// 重置平均绑定时间
    public func resetAverageBindTimes() {
        os_unfair_lock_lock(&statsLock)
        defer { os_unfair_lock_unlock(&statsLock) }
        averageBindTimes.removeAll()
    }
    
    // MARK: - Private
    
    private func printSession(_ session: TraceSession) {
        let total = session.totalDuration
        let isSlow = total > slowRenderThreshold
        
        var output = "[TemplateX] \(session.name)"
        if let templateId = session.templateId {
            output += " (\(templateId))"
        }
        output += ": total=\(String(format: "%.2f", total))ms"
        
        if isSlow {
            output += " ⚠️ SLOW"
        }
        
        // 打印各阶段
        if !session.spans.isEmpty {
            let spanDetails = session.spans.map { span in
                "\(span.name)=\(String(format: "%.2f", span.duration))ms"
            }.joined(separator: ", ")
            output += " (\(spanDetails))"
        }
        
        // 内存变化
        if let memoryDelta = session.memoryDelta {
            let memoryStr = memoryDelta >= 0 ? "+\(memoryDelta)" : "\(memoryDelta)"
            output += " [mem: \(memoryStr) KB]"
        }
        
        TXLogger.trace(output)
    }
    
    private func aggregateSession(_ session: TraceSession) {
        os_unfair_lock_lock(&statsLock)
        defer { os_unfair_lock_unlock(&statsLock) }
        
        // 聚合总耗时
        let key = session.name
        if var metric = aggregatedStats[key] {
            metric.addSample(session.totalDuration)
            aggregatedStats[key] = metric
        } else {
            var metric = AggregatedMetric(name: key)
            metric.addSample(session.totalDuration)
            aggregatedStats[key] = metric
        }
        
        // 聚合各阶段
        for span in session.spans {
            let spanKey = "\(key).\(span.name)"
            if var metric = aggregatedStats[spanKey] {
                metric.addSample(span.duration)
                aggregatedStats[spanKey] = metric
            } else {
                var metric = AggregatedMetric(name: spanKey)
                metric.addSample(span.duration)
                aggregatedStats[spanKey] = metric
            }
        }
    }
}

// MARK: - TraceSession

/// 追踪会话 - 单次渲染的性能数据
public final class TraceSession {
    
    public let name: String
    public let templateId: String?
    public let isEnabled: Bool
    
    /// 各阶段耗时
    public private(set) var spans: [Span] = []
    
    /// 会话开始时间
    private let startTime: CFAbsoluteTime
    
    /// 会话结束时间
    private var endTime: CFAbsoluteTime?
    
    /// 开始时内存
    private let startMemory: Int64?
    
    /// 结束时内存
    private var endMemory: Int64?
    
    /// 当前正在测量的 span
    private var currentSpanStart: CFAbsoluteTime?
    private var currentSpanName: String?
    
    /// 标记时间点（用于 mark 方法）
    private var marks: [String: CFAbsoluteTime] = [:]
    
    init(name: String, templateId: String?, isEnabled: Bool) {
        self.name = name
        self.templateId = templateId
        self.isEnabled = isEnabled
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.startMemory = isEnabled ? Self.currentMemoryUsage() : nil
    }
    
    // MARK: - API
    
    /// 测量一个代码块
    @inline(__always)
    public func measure<T>(_ spanName: String, _ block: () throws -> T) rethrows -> T {
        guard isEnabled else { return try block() }
        
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let end = CFAbsoluteTimeGetCurrent()
        
        let duration = (end - start) * 1000  // 转为毫秒
        spans.append(Span(name: spanName, duration: duration))
        
        return result
    }
    
    /// 异步测量 - 开始
    @inline(__always)
    public func beginSpan(_ spanName: String) {
        guard isEnabled else { return }
        currentSpanName = spanName
        currentSpanStart = CFAbsoluteTimeGetCurrent()
    }
    
    /// 异步测量 - 结束
    @inline(__always)
    public func endSpan() {
        guard isEnabled,
              let start = currentSpanStart,
              let name = currentSpanName else { return }
        
        let end = CFAbsoluteTimeGetCurrent()
        let duration = (end - start) * 1000
        spans.append(Span(name: name, duration: duration))
        
        currentSpanStart = nil
        currentSpanName = nil
    }
    
    /// 添加自定义 span
    public func addSpan(_ name: String, duration: Double) {
        guard isEnabled else { return }
        spans.append(Span(name: name, duration: duration))
    }
    
    /// 打标记 - 用于记录时间点，自动计算相邻标记之间的时长
    /// 
    /// 用法: mark("xxx_start"), mark("xxx_end") 会自动创建一个 "xxx" span
    @inline(__always)
    public func mark(_ name: String) {
        guard isEnabled else { return }
        
        let now = CFAbsoluteTimeGetCurrent()
        
        // 检查是否是 _end 结尾的标记
        if name.hasSuffix("_end") {
            let baseName = String(name.dropLast(4))  // 去掉 "_end"
            let startKey = baseName + "_start"
            
            if let startTime = marks[startKey] {
                let duration = (now - startTime) * 1000  // 转为毫秒
                spans.append(Span(name: baseName, duration: duration))
                marks.removeValue(forKey: startKey)
            }
        } else {
            // 记录开始时间
            marks[name] = now
        }
    }
    
    /// 结束会话并上报
    public func end() {
        guard isEnabled, endTime == nil else { return }
        
        endTime = CFAbsoluteTimeGetCurrent()
        endMemory = Self.currentMemoryUsage()
        
        PerformanceMonitor.shared.report(self)
    }
    
    // MARK: - 计算属性
    
    /// 总耗时（毫秒）
    public var totalDuration: Double {
        let end = endTime ?? CFAbsoluteTimeGetCurrent()
        return (end - startTime) * 1000
    }
    
    /// 内存变化（KB）
    public var memoryDelta: Int64? {
        guard let start = startMemory, let end = endMemory else { return nil }
        return (end - start) / 1024
    }
    
    // MARK: - 内存测量
    
    private static func currentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        return 0
    }
}

// MARK: - Span

/// 单个阶段的耗时
public struct Span {
    public let name: String
    public let duration: Double  // 毫秒
}

// MARK: - AggregatedMetric

/// 聚合统计指标
public struct AggregatedMetric {
    public let name: String
    public private(set) var count: Int = 0
    public private(set) var total: Double = 0
    public private(set) var min: Double = .greatestFiniteMagnitude
    public private(set) var max: Double = 0
    
    /// 平均值
    public var average: Double {
        count > 0 ? total / Double(count) : 0
    }
    
    init(name: String) {
        self.name = name
    }
    
    mutating func addSample(_ value: Double) {
        count += 1
        total += value
        min = Swift.min(min, value)
        max = Swift.max(max, value)
    }
}

// MARK: - 便捷扩展

extension PerformanceMonitor {
    
    /// 打印聚合统计报告
    public func printReport() {
        let stats = getAggregatedStats()
        guard !stats.isEmpty else {
            TXLogger.info("Performance: No data collected")
            return
        }
        
        var report = "\n========== TemplateX Performance Report ==========\n"
        
        // 按名称排序
        let sortedKeys = stats.keys.sorted()
        
        for key in sortedKeys {
            guard let metric = stats[key] else { continue }
            report += String(format: "%-40s count=%-5d avg=%.2fms min=%.2fms max=%.2fms\n",
                         key, metric.count, metric.average, metric.min, metric.max)
        }
        
        report += "===================================================\n"
        TXLogger.info(report)
    }
}

// MARK: - Debug 辅助

#if DEBUG
extension TraceSession {
    /// Debug 模式下打印实时耗时
    public func debugPrint(_ message: String) {
        guard isEnabled else { return }
        TXLogger.debug("\(name): \(message) at \(String(format: "%.2f", totalDuration))ms")
    }
}
#endif
