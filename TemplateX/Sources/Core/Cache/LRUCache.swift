import Foundation
import os.lock

// MARK: - LRU 缓存

/// 线程安全的 LRU 缓存
public final class LRUCache<Key: Hashable, Value> {
    
    /// 缓存节点
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    // MARK: - Properties
    
    /// 缓存容量
    public let capacity: Int
    
    /// 缓存字典
    private var cache: [Key: Node] = [:]
    
    /// 双向链表头尾
    private var head: Node?
    private var tail: Node?
    
    /// 高性能自旋锁
    private var unfairLock = os_unfair_lock()
    
    /// 缓存命中/未命中统计
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    // MARK: - Init
    
    public init(capacity: Int) {
        self.capacity = capacity
        cache.reserveCapacity(capacity)
    }
    
    // MARK: - Public API
    
    /// 获取缓存值
    @inline(__always)
    public func get(_ key: Key) -> Value? {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        guard let node = cache[key] else {
            missCount += 1
            return nil
        }
        
        hitCount += 1
        moveToHead(node)
        return node.value
    }
    
    /// 设置缓存值
    @inline(__always)
    public func set(_ key: Key, _ value: Value) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        if let node = cache[key] {
            // 更新已存在的节点
            node.value = value
            moveToHead(node)
        } else {
            // 创建新节点
            let node = Node(key: key, value: value)
            cache[key] = node
            addToHead(node)
            
            // 超出容量，移除最久未使用
            if cache.count > capacity {
                if let oldest = removeTail() {
                    cache.removeValue(forKey: oldest.key)
                }
            }
        }
    }
    
    /// 移除缓存值
    public func remove(_ key: Key) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        guard let node = cache[key] else { return }
        removeNode(node)
        cache.removeValue(forKey: key)
    }
    
    /// 清空缓存
    public func clear() {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        
        cache.removeAll()
        head = nil
        tail = nil
        hitCount = 0
        missCount = 0
    }
    
    /// 当前缓存数量
    public var count: Int {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return cache.count
    }
    
    /// 缓存命中率
    public var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
    
    // MARK: - Private
    
    @inline(__always)
    private func addToHead(_ node: Node) {
        node.prev = nil
        node.next = head
        
        if let h = head {
            h.prev = node
        }
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    @inline(__always)
    private func removeNode(_ node: Node) {
        if let prev = node.prev {
            prev.next = node.next
        } else {
            head = node.next
        }
        
        if let next = node.next {
            next.prev = node.prev
        } else {
            tail = node.prev
        }
        
        node.prev = nil
        node.next = nil
    }
    
    @inline(__always)
    private func moveToHead(_ node: Node) {
        guard node !== head else { return }
        removeNode(node)
        addToHead(node)
    }
    
    @inline(__always)
    private func removeTail() -> Node? {
        guard let t = tail else { return nil }
        removeNode(t)
        return t
    }
}

// MARK: - 对象池

/// 通用对象池
public final class ObjectPool<T> {
    
    /// 对象工厂
    private let factory: () -> T
    
    /// 重置方法
    private let reset: ((T) -> Void)?
    
    /// 池中对象
    private var pool: [T] = []
    
    /// 池容量
    private let capacity: Int
    
    /// 线程锁（必须是 var，os_unfair_lock 需要 inout）
    private var lock = os_unfair_lock()
    
    // MARK: - Init
    
    public init(capacity: Int, factory: @escaping () -> T, reset: ((T) -> Void)? = nil) {
        self.capacity = capacity
        self.factory = factory
        self.reset = reset
        
        // 预分配
        pool.reserveCapacity(capacity)
    }
    
    // MARK: - API
    
    /// 获取对象
    @inline(__always)
    public func acquire() -> T {
        os_unfair_lock_lock(&lock)
        
        if let obj = pool.popLast() {
            os_unfair_lock_unlock(&lock)
            return obj
        }
        
        os_unfair_lock_unlock(&lock)
        return factory()
    }
    
    /// 归还对象
    @inline(__always)
    public func release(_ obj: T) {
        os_unfair_lock_lock(&lock)
        
        if pool.count < capacity {
            reset?(obj)
            pool.append(obj)
        }
        
        os_unfair_lock_unlock(&lock)
    }
    
    /// 预热
    public func warmUp(count: Int) {
        os_unfair_lock_lock(&lock)
        
        let toCreate = min(count, capacity - pool.count)
        for _ in 0..<toCreate {
            pool.append(factory())
        }
        
        os_unfair_lock_unlock(&lock)
    }
    
    /// 清空
    public func clear() {
        os_unfair_lock_lock(&lock)
        pool.removeAll()
        os_unfair_lock_unlock(&lock)
    }
    
    /// 当前池中数量
    public var count: Int {
        os_unfair_lock_lock(&lock)
        let c = pool.count
        os_unfair_lock_unlock(&lock)
        return c
    }
}
