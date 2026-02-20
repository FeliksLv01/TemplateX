import Foundation
import QuartzCore
import UIKit

// MARK: - TemplateXGapWorker

/// 闲时任务调度器
/// 在每帧渲染完成后的空闲时间内执行 Cell 预渲染任务
/// 对应 Lynx: clay/ui/common/gap_worker.h
final class TemplateXGapWorker {
    
    // MARK: - Singleton
    
    static let shared = TemplateXGapWorker()
    
    // MARK: - 时间预算
    
    /// 每帧时间预算（纳秒）
    /// 公式：1,000,000,000 / refreshRate / 2
    /// 对应 Lynx: max_estimate_duration_
    private(set) var maxEstimateDuration: Int64 = 8_333_333  // 60fps 默认值
    
    /// 当前屏幕刷新率
    private(set) var refreshRate: Int = 60
    
    // MARK: - 任务管理
    
    /// 任务收集器 [host ObjectIdentifier -> collector]
    /// 对应 Lynx: collectors_
    private var collectors: [ObjectIdentifier: GapTaskCollector] = [:]
    
    /// 任务队列 [host ObjectIdentifier -> taskBundle]
    /// 对应 Lynx: task_map_
    private var taskMap: [ObjectIdentifier: GapTaskBundle] = [:]
    
    /// 上一帧的任务列表（已排序，扁平化）
    /// 对应 Lynx: last_task_list_
    private var lastTaskList: [GapTask] = []
    
    /// 数据是否变化（需要重新排序）
    /// 对应 Lynx: data_changed_
    private var dataChanged: Bool = false
    
    // MARK: - CADisplayLink
    
    /// DisplayLink 用于 VSYNC 回调
    private var displayLink: CADisplayLink?
    
    /// 是否已启动
    private(set) var isRunning: Bool = false
    
    // MARK: - Init
    
    private init() {
        // 检测屏幕刷新率（ProMotion 支持）
        detectRefreshRate()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - 启动/停止
    
    /// 启动 GapWorker
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        displayLink = CADisplayLink(target: self, selector: #selector(vsyncCallback(_:)))
        // iOS 15.0+ 使用 preferredFrameRateRange 支持 ProMotion
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: Float(refreshRate),
                preferred: Float(refreshRate)
            )
        }
        displayLink?.add(to: .main, forMode: .common)
        
        TXLogger.debug("GapWorker started, refreshRate=\(refreshRate), timeBudget=\(maxEstimateDuration / 1_000_000)ms")
    }
    
    /// 停止 GapWorker
    func stop() {
        guard isRunning else { return }
        isRunning = false
        
        displayLink?.invalidate()
        displayLink = nil
        
        // 清理所有任务
        collectors.removeAll()
        taskMap.removeAll()
        lastTaskList.removeAll()
        
        TXLogger.debug("GapWorker stopped")
    }
    
    // MARK: - 注册/取消注册
    
    /// 注册预加载收集器
    /// 对应 Lynx: RegisterPrefetch() in base_list_view.cc:719
    func registerPrefetch(host: AnyObject, collector: @escaping GapTaskCollector) {
        let key = ObjectIdentifier(host)
        collectors[key] = collector
        dataChanged = true
        
        TXLogger.trace("GapWorker.registerPrefetch: host=\(type(of: host))")
        
        // 如果还没启动，自动启动
        if !isRunning {
            start()
        }
    }
    
    /// 取消注册预加载收集器
    /// 对应 Lynx: UnregisterPrefetch() in base_list_view.cc:728
    func unregisterPrefetch(host: AnyObject) {
        let key = ObjectIdentifier(host)
        collectors.removeValue(forKey: key)
        cancel(host: host)
        
        TXLogger.trace("GapWorker.unregisterPrefetch: host=\(type(of: host))")
        
        // 如果没有任何收集器了，停止 DisplayLink
        if collectors.isEmpty {
            stop()
        }
    }
    
    /// 提交任务组
    /// 对应 Lynx: SubmitTask()
    func submit(taskBundle: GapTaskBundle, host: AnyObject) {
        let key = ObjectIdentifier(host)
        taskMap[key] = taskBundle
        dataChanged = true
        
        TXLogger.trace("GapWorker.submit: host=\(type(of: host)), taskCount=\(taskBundle.count)")
    }
    
    /// 取消指定宿主的任务
    func cancel(host: AnyObject) {
        let key = ObjectIdentifier(host)
        taskMap.removeValue(forKey: key)
        dataChanged = true
    }
    
    /// 是否有待执行的任务
    var hasGapTask: Bool {
        !collectors.isEmpty || !taskMap.isEmpty
    }
    
    // MARK: - VSYNC 回调
    
    /// DisplayLink 回调
    /// 对应 Lynx: PageView::FlushGapTaskIfNecessary() in page_view.cc:1868
    @objc private func vsyncCallback(_ displayLink: CADisplayLink) {
        // 计算本帧结束时间
        // targetTimestamp 是下一帧的目标时间，减去当前时间就是本帧剩余时间
        let now = CACurrentMediaTime()
        let targetTime = displayLink.targetTimestamp
        let remainingTime = targetTime - now
        
        // 将剩余时间转换为纳秒，取一半作为闲时预算
        let endTimeNanos = Int64(remainingTime * 1_000_000_000 / 2)
        
        // 如果剩余时间太少（小于 1ms），跳过本帧
        guard endTimeNanos > 1_000_000 else { return }
        
        flushTasks(timeBudgetNanos: endTimeNanos)
    }
    
    // MARK: - 任务执行
    
    /// 执行任务
    /// 对应 Lynx: GapWorker::FlushTask() in gap_worker.cc:52
    func flushTasks(timeBudgetNanos: Int64) {
        let startTime = CACurrentMediaTime()
        
        // 1. 收集任务
        collectTasksIfNeeded()
        
        // 2. 如果没有任务，直接返回
        guard !taskMap.isEmpty else { return }
        
        // 3. 如果数据变化，重新排序
        if dataChanged {
            rebuildTaskList()
            dataChanged = false
        }
        
        // 4. 执行任务
        var executedCount = 0
        var remainingBudget = timeBudgetNanos
        
        for task in lastTaskList {
            // 检查时间预算
            let estimatedTime = task.estimateDuration
            
            // 时间不够且不强制执行 → 跳过
            if remainingBudget < estimatedTime && !task.enableForceRun {
                continue
            }
            
            // 执行任务
            let taskStart = CACurrentMediaTime()
            task.run()
            let taskDuration = Int64((CACurrentMediaTime() - taskStart) * 1_000_000_000)
            
            executedCount += 1
            remainingBudget -= taskDuration
            
            // 预算用完，停止执行
            if remainingBudget <= 0 {
                break
            }
        }
        
        let totalDuration = (CACurrentMediaTime() - startTime) * 1000
        if executedCount > 0 {
            TXLogger.trace("GapWorker.flushTasks: executed=\(executedCount)/\(lastTaskList.count), duration=\(String(format: "%.2f", totalDuration))ms")
        }
    }
    
    // MARK: - Private
    
    /// 收集任务
    private func collectTasksIfNeeded() {
        // 调用所有注册的收集器
        for (_, collector) in collectors {
            collector()
        }
    }
    
    /// 重建任务列表（扁平化 + 排序）
    private func rebuildTaskList() {
        lastTaskList.removeAll()
        
        // 扁平化所有 taskBundle 的任务
        for (_, bundle) in taskMap {
            bundle.sort()
            lastTaskList.append(contentsOf: bundle.tasks)
        }
        
        // 全局排序（按优先级）
        lastTaskList.sort { $0.priority < $1.priority }
    }
    
    /// 检测屏幕刷新率
    private func detectRefreshRate() {
        // iOS 10.3+ 可以获取屏幕最大刷新率
        if #available(iOS 10.3, *) {
            let maxFrameRate = UIScreen.main.maximumFramesPerSecond
            refreshRate = maxFrameRate
        }
        
        // 计算时间预算
        // 公式：1,000,000,000 / refreshRate / 2
        maxEstimateDuration = 1_000_000_000 / Int64(refreshRate) / 2
    }
}
