import Foundation
import os.lock
import yoga

// MARK: - Yoga 节点池

/// YGNode 节点池，用于复用节点减少内存分配
/// 线程安全：使用 os_unfair_lock（iOS 上最快的锁）
public final class YogaNodePool {
    
    // MARK: - Singleton
    
    public static let shared = YogaNodePool()
    
    // MARK: - Properties
    
    /// 节点池
    private var pool: [YGNodeRef] = []
    
    /// 最大池大小
    private let maxPoolSize: Int
    
    /// 高性能锁（比 NSLock 快约 10x）
    private var unfairLock = os_unfair_lock()
    
    /// 统计：获取次数
    private(set) var acquireCount: Int = 0
    
    /// 统计：复用次数
    private(set) var reuseCount: Int = 0
    
    /// 统计：创建次数
    private(set) var createCount: Int = 0
    
    // MARK: - Init
    
    public init(maxPoolSize: Int = 256) {
        self.maxPoolSize = maxPoolSize
    }
    
    deinit {
        // 释放所有节点
        os_unfair_lock_lock(&unfairLock)
        for node in pool {
            YGNodeFree(node)
        }
        pool.removeAll()
        os_unfair_lock_unlock(&unfairLock)
    }
    
    // MARK: - Public API
    
    /// 获取一个节点（优先从池中获取，否则创建新的）
    public func acquire() -> YGNodeRef {
        os_unfair_lock_lock(&unfairLock)
        
        acquireCount += 1
        
        if let node = pool.popLast() {
            reuseCount += 1
            os_unfair_lock_unlock(&unfairLock)
            // 重置节点状态（在锁外执行，减少持锁时间）
            YGNodeReset(node)
            return node
        }
        
        createCount += 1
        os_unfair_lock_unlock(&unfairLock)
        
        // 创建新节点（在锁外执行）
        return YGNodeNew()
    }
    
    /// 批量获取节点
    /// 
    /// 用于已知需要多个节点的场景（如解析整棵模板树），减少锁竞争次数
    /// 
    /// - Parameter count: 需要的节点数量
    /// - Returns: 节点数组
    public func acquireBatch(count: Int) -> [YGNodeRef] {
        guard count > 0 else { return [] }
        
        var result: [YGNodeRef] = []
        result.reserveCapacity(count)
        
        os_unfair_lock_lock(&unfairLock)
        
        acquireCount += count
        
        // 从池中批量获取
        let availableCount = min(count, pool.count)
        if availableCount > 0 {
            let nodes = pool.suffix(availableCount)
            result.append(contentsOf: nodes)
            pool.removeLast(availableCount)
            reuseCount += availableCount
        }
        
        let toCreate = count - availableCount
        createCount += toCreate
        
        os_unfair_lock_unlock(&unfairLock)
        
        // 在锁外创建剩余节点
        for _ in 0..<toCreate {
            result.append(YGNodeNew())
        }
        
        // 在锁外批量重置复用的节点
        for i in 0..<availableCount {
            YGNodeReset(result[i])
        }
        
        return result
    }
    
    /// 归还节点到池中
    public func release(_ node: YGNodeRef) {
        // 1. 先从父节点移除（必须在 reset 之前）
        if let owner = YGNodeGetOwner(node) {
            YGNodeRemoveChild(owner, node)
        }
        
        // 2. 移除所有子节点
        YGNodeRemoveAllChildren(node)
        
        os_unfair_lock_lock(&unfairLock)
        
        // 池满则直接释放
        if pool.count >= maxPoolSize {
            os_unfair_lock_unlock(&unfairLock)
            YGNodeFree(node)
            return
        }
        
        pool.append(node)
        os_unfair_lock_unlock(&unfairLock)
    }
    
    /// 递归归还整棵树（非递归实现，避免栈溢出）
    public func releaseTree(_ root: YGNodeRef) {
        // 使用栈模拟递归，后序遍历释放
        var stack: [YGNodeRef] = [root]
        var toRelease: [YGNodeRef] = []
        
        while let node = stack.popLast() {
            toRelease.append(node)
            let childCount = Int(YGNodeGetChildCount(node))
            for i in 0..<childCount {
                if let child = YGNodeGetChild(node, size_t(i)) {
                    stack.append(child)
                }
            }
        }
        
        // 从叶子节点开始释放
        for node in toRelease.reversed() {
            release(node)
        }
    }
    
    /// 预热池（预先创建指定数量的节点）
    public func warmUp(count: Int) {
        // 先在锁外创建节点
        var nodesToAdd: [YGNodeRef] = []
        
        os_unfair_lock_lock(&unfairLock)
        let currentCount = pool.count
        let toCreate = min(count, maxPoolSize) - currentCount
        os_unfair_lock_unlock(&unfairLock)
        
        guard toCreate > 0 else { return }
        
        // 在锁外批量创建
        nodesToAdd.reserveCapacity(toCreate)
        for _ in 0..<toCreate {
            nodesToAdd.append(YGNodeNew())
        }
        
        // 批量加入池
        os_unfair_lock_lock(&unfairLock)
        let spaceLeft = maxPoolSize - pool.count
        let actualAdd = min(nodesToAdd.count, spaceLeft)
        pool.append(contentsOf: nodesToAdd.prefix(actualAdd))
        createCount += actualAdd
        os_unfair_lock_unlock(&unfairLock)
        
        // 释放多余的节点
        for i in actualAdd..<nodesToAdd.count {
            YGNodeFree(nodesToAdd[i])
        }
    }
    
    /// 清空池
    public func drain() {
        os_unfair_lock_lock(&unfairLock)
        let nodesToFree = pool
        pool.removeAll()
        os_unfair_lock_unlock(&unfairLock)
        
        // 在锁外释放
        for node in nodesToFree {
            YGNodeFree(node)
        }
    }
    
    /// 当前池大小
    public var count: Int {
        os_unfair_lock_lock(&unfairLock)
        let c = pool.count
        os_unfair_lock_unlock(&unfairLock)
        return c
    }
    
    /// 复用率
    public var reuseRate: Double {
        os_unfair_lock_lock(&unfairLock)
        let acquire = acquireCount
        let reuse = reuseCount
        os_unfair_lock_unlock(&unfairLock)
        
        guard acquire > 0 else { return 0 }
        return Double(reuse) / Double(acquire)
    }
    
    /// 重置统计
    public func resetStats() {
        os_unfair_lock_lock(&unfairLock)
        acquireCount = 0
        reuseCount = 0
        createCount = 0
        os_unfair_lock_unlock(&unfairLock)
    }
}
