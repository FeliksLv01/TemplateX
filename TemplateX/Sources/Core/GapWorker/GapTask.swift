import Foundation

// MARK: - GapTask 协议

/// 闲时任务协议
/// 对应 Lynx: clay/ui/common/gap_task.h
protocol GapTask: AnyObject {
    /// 任务 ID（通常是 Cell position）
    var taskId: Int { get }
    
    /// 估算执行耗时（纳秒）
    var estimateDuration: Int64 { get }
    
    /// 优先级（距离视口越近，值越小，优先级越高）
    var priority: Int { get }
    
    /// 是否强制执行（即使时间预算不足）
    var enableForceRun: Bool { get }
    
    /// 执行任务
    func run()
}

// MARK: - GapTaskBundle

/// 任务组，管理一组相关的任务
/// 对应 Lynx: clay/ui/common/gap_task.h:56
final class GapTaskBundle {
    
    /// 任务列表
    private(set) var tasks: [GapTask] = []
    
    /// 最小优先级（用于任务组排序）
    private(set) var priority: Int = Int.max
    
    /// 宿主对象（弱引用，避免循环引用）
    weak var host: AnyObject?
    
    /// 是否已排序
    private var isSorted: Bool = false
    
    init(host: AnyObject? = nil) {
        self.host = host
    }
    
    /// 添加任务
    /// 对应 Lynx: gap_task.h AddTask()
    func addTask(_ task: GapTask) {
        tasks.append(task)
        // 更新最小优先级
        if task.priority < priority {
            priority = task.priority
        }
        isSorted = false
    }
    
    /// 按优先级排序（距离越小越优先）
    /// 对应 Lynx: gap_task_bundle->sort()
    func sort() {
        guard !isSorted else { return }
        tasks.sort { $0.priority < $1.priority }
        isSorted = true
    }
    
    /// 清空任务
    func clear() {
        tasks.removeAll()
        priority = Int.max
        isSorted = false
    }
    
    /// 是否为空
    var isEmpty: Bool {
        tasks.isEmpty
    }
    
    /// 任务数量
    var count: Int {
        tasks.count
    }
}

// MARK: - GapTaskCollector

/// 任务收集器闭包类型
/// 对应 Lynx: GapWorker 中的 collector 回调
typealias GapTaskCollector = () -> Void
