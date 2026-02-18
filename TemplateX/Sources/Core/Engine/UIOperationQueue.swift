import Foundation
import QuartzCore

// MARK: - UI 操作队列

/// UI 操作队列
/// 
/// 设计思想（借鉴 Lynx）：
/// - 所有 UI 操作（createView、addSubview、setFrame 等）封装成闭包入队
/// - 在合适的时机（SyncFlush）批量执行
/// - 支持同步等待后台线程完成（条件变量）
/// 
/// 使用场景：
/// 1. 后台线程执行 parse/bind/layout
/// 2. 生成 UI 操作闭包入队
/// 3. 主线程 layoutSubviews 时调用 syncFlush()
/// 4. 等待后台完成 → 批量执行 UI 操作
final class UIOperationQueue {
    
    // MARK: - 类型定义
    
    /// UI 操作闭包
    typealias UIOperation = () -> Void
    
    /// 队列状态
    enum Status {
        case idle           // 空闲
        case preparing      // 后台准备中（parse/bind/layout）
        case ready          // 准备完成，等待 flush
        case flushing       // 正在执行 UI 操作
    }
    
    // MARK: - 属性
    
    /// 当前状态
    private(set) var status: Status = .idle
    
    /// 待执行的 UI 操作
    private var pendingOperations: [UIOperation] = []
    
    /// 高优先级操作（如错误处理）
    private var highPriorityOperations: [UIOperation] = []
    
    /// 同步锁
    private var lock = os_unfair_lock()
    
    /// 条件变量 - 等待后台完成
    private let condition = NSCondition()
    
    /// 后台是否完成
    private var isBackgroundFinished = false
    
    /// 是否启用 flush
    private var enableFlush = true
    
    /// 超时时间（毫秒）
     var timeoutMs: Int = 100
    
    /// 实例 ID（调试用）
     let instanceId: String
    
    // MARK: - 统计
    
    /// 上次 flush 的操作数量
     private(set) var lastFlushCount: Int = 0
    
    /// 上次 flush 的等待时间（毫秒）
     private(set) var lastWaitTimeMs: Double = 0
    
    /// 上次 flush 的执行时间（毫秒）
     private(set) var lastExecuteTimeMs: Double = 0
    
    // MARK: - Init
    
     init(instanceId: String = UUID().uuidString) {
        self.instanceId = instanceId
    }
    
    // MARK: - 入队操作
    
    /// 入队普通 UI 操作
    /// - Parameter operation: UI 操作闭包
     func enqueue(_ operation: @escaping UIOperation) {
        os_unfair_lock_lock(&lock)
        pendingOperations.append(operation)
        os_unfair_lock_unlock(&lock)
    }
    
    /// 批量入队 UI 操作
    /// - Parameter operations: UI 操作闭包数组
     func enqueueBatch(_ operations: [UIOperation]) {
        os_unfair_lock_lock(&lock)
        pendingOperations.append(contentsOf: operations)
        os_unfair_lock_unlock(&lock)
    }
    
    /// 入队高优先级操作
    /// - Parameter operation: UI 操作闭包
     func enqueueHighPriority(_ operation: @escaping UIOperation) {
        os_unfair_lock_lock(&lock)
        highPriorityOperations.append(operation)
        os_unfair_lock_unlock(&lock)
    }
    
    // MARK: - 状态管理
    
    /// 标记开始准备（后台线程调用）
     func markPreparing() {
        condition.lock()
        status = .preparing
        isBackgroundFinished = false
        condition.unlock()
    }
    
    /// 标记准备完成（后台线程调用）
     func markReady() {
        condition.lock()
        status = .ready
        isBackgroundFinished = true
        condition.signal()  // 通知等待的主线程
        condition.unlock()
    }
    
    /// 标记错误（后台线程调用）
     func markError(_ error: Error) {
        condition.lock()
        status = .ready  // 标记为 ready，让主线程可以继续
        isBackgroundFinished = true
        // 清空待执行的操作
        os_unfair_lock_lock(&lock)
        pendingOperations.removeAll()
        os_unfair_lock_unlock(&lock)
        condition.signal()
        condition.unlock()
        
        TXLogger.error("UIOperationQueue error: \(error)")
    }
    
    /// 重置队列
     func reset() {
        condition.lock()
        os_unfair_lock_lock(&lock)
        
        status = .idle
        isBackgroundFinished = false
        pendingOperations.removeAll()
        highPriorityOperations.removeAll()
        
        os_unfair_lock_unlock(&lock)
        condition.unlock()
    }
    
    // MARK: - Flush
    
    /// 同步刷新（主线程调用）
    /// 
    /// 流程：
    /// 1. 等待后台线程完成（带超时）
    /// 2. 批量执行所有 UI 操作
    /// 
    /// - Returns: 是否成功执行
    @discardableResult
     func syncFlush() -> Bool {
        guard Thread.isMainThread else {
            TXLogger.error("syncFlush must be called on main thread")
            return false
        }
        
        guard enableFlush else {
            return false
        }
        
        // 如果状态是 idle，说明没有准备中的操作
        if status == .idle {
            return flushPendingOperations()
        }
        
        let waitStart = CACurrentMediaTime()
        
        // 等待后台完成
        condition.lock()
        if !isBackgroundFinished {
            // 带超时等待
            let timeout = Date(timeIntervalSinceNow: Double(timeoutMs) / 1000.0)
            let waitResult = condition.wait(until: timeout)
            if !waitResult {
                TXLogger.warning("syncFlush timeout after \(timeoutMs)ms")
            }
        }
        condition.unlock()
        
        lastWaitTimeMs = (CACurrentMediaTime() - waitStart) * 1000
        
        // 执行 UI 操作
        return flushPendingOperations()
    }
    
    /// 强制刷新（不等待，直接执行当前队列中的操作）
    @discardableResult
     func forceFlush() -> Bool {
        guard Thread.isMainThread else {
            TXLogger.error("forceFlush must be called on main thread")
            return false
        }
        
        return flushPendingOperations()
    }
    
    /// 执行队列中的所有操作
    private func flushPendingOperations() -> Bool {
        status = .flushing
                
        // 取出所有操作
        os_unfair_lock_lock(&lock)
        let highPriority = highPriorityOperations
        let normal = pendingOperations
        highPriorityOperations.removeAll()
        pendingOperations.removeAll()
        os_unfair_lock_unlock(&lock)
        
        let totalCount = highPriority.count + normal.count
        lastFlushCount = totalCount
        
        if totalCount == 0 {
            status = .idle
            lastExecuteTimeMs = 0
            return true
        }
        
        // 先执行高优先级操作
        for operation in highPriority {
            operation()
        }
        
        // 再执行普通操作
        for operation in normal {
            operation()
        }
        
        status = .idle
        return true
    }
    
    // MARK: - 配置
    
    /// 设置是否启用 flush
     func setEnableFlush(_ enable: Bool) {
        enableFlush = enable
    }
    
    // MARK: - 调试
    
    /// 当前队列中的操作数量
     var pendingCount: Int {
        os_unfair_lock_lock(&lock)
        let count = pendingOperations.count + highPriorityOperations.count
        os_unfair_lock_unlock(&lock)
        return count
    }
}

// MARK: - 便捷方法

extension UIOperationQueue {
    
    /// 在主线程执行操作（入队或直接执行）
    /// 
    /// - 如果当前在主线程且队列为空，直接执行
    /// - 否则入队等待 flush
     func executeOnMain(_ operation: @escaping UIOperation) {
        if Thread.isMainThread && status == .idle && pendingCount == 0 {
            operation()
        } else {
            enqueue(operation)
        }
    }
}
