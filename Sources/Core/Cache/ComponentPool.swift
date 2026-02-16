import UIKit

// MARK: - 组件复用池

/// 组件复用池 - 避免频繁创建/销毁组件和视图
/// 注意：此类只在主线程访问（涉及 UIView 操作），无需加锁
public final class ComponentPool {
    
    public static let shared = ComponentPool()
    
    // MARK: - 配置
    
    /// 每种类型的最大缓存数量
    public var maxPoolSize: Int = 20
    
    /// 是否启用池化
    public var isEnabled: Bool = true
    
    // MARK: - 存储
    
    /// 组件池 - 按类型分组
    private var componentPools: [String: [Component]] = [:]
    
    /// 视图池 - 按类型分组
    private var viewPools: [String: [UIView]] = [:]
    
    /// 统计信息
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    private init() {}
    
    // MARK: - 组件复用
    
    /// 获取组件（优先从池中获取）
    public func obtainComponent(type: String, from json: JSONWrapper) -> Component? {
        guard isEnabled else {
            return ComponentRegistry.shared.createComponent(type: type, from: json)
        }
        
        // 尝试从池中获取
        if var pool = componentPools[type], !pool.isEmpty {
            let component = pool.removeLast()
            componentPools[type] = pool
            
            hitCount += 1
            
            // 重新配置组件
            reconfigureComponent(component, from: json)
            return component
        }
        
        missCount += 1
        
        // 池中没有，创建新组件
        return ComponentRegistry.shared.createComponent(type: type, from: json)
    }
    
    /// 回收组件到池中
    public func recycleComponent(_ component: Component) {
        guard isEnabled else { return }
        
        let type = component.type
        
        var pool = componentPools[type] ?? []
        
        // 检查池大小
        guard pool.count < maxPoolSize else { return }
        
        // 清理组件状态
        resetComponent(component)
        
        pool.append(component)
        componentPools[type] = pool
    }
    
    /// 批量回收组件
    public func recycleComponents(_ components: [Component]) {
        for component in components {
            recycleComponent(component)
            // 递归回收子组件
            recycleComponents(component.children)
        }
    }
    
    // MARK: - 视图复用
    
    /// 获取视图（优先从池中获取）
    public func obtainView<T: UIView>(type: T.Type) -> T {
        guard isEnabled else {
            return T()
        }
        
        let key = String(describing: type)
        
        if var pool = viewPools[key], !pool.isEmpty {
            if let view = pool.removeLast() as? T {
                viewPools[key] = pool
                
                // 重置视图状态
                resetView(view)
                return view
            }
        }
        
        return T()
    }
    
    /// 回收视图到池中
    public func recycleView(_ view: UIView) {
        guard isEnabled else { return }
        
        let key = String(describing: type(of: view))
        
        var pool = viewPools[key] ?? []
        
        guard pool.count < maxPoolSize else { return }
        
        // 从父视图移除
        view.removeFromSuperview()
        
        // 重置视图
        resetView(view)
        
        pool.append(view)
        viewPools[key] = pool
    }
    
    // MARK: - 清理
    
    /// 清空所有池
    public func clear() {
        componentPools.removeAll()
        viewPools.removeAll()
        hitCount = 0
        missCount = 0
    }
    
    /// 收缩池大小（内存警告时调用）
    public func shrink(to ratio: Double = 0.5) {
        for (key, var pool) in componentPools {
            let targetCount = Int(Double(pool.count) * ratio)
            while pool.count > targetCount {
                pool.removeLast()
            }
            componentPools[key] = pool
        }
        
        for (key, var pool) in viewPools {
            let targetCount = Int(Double(pool.count) * ratio)
            while pool.count > targetCount {
                pool.removeLast()
            }
            viewPools[key] = pool
        }
    }
    
    // MARK: - 统计
    
    /// 命中率
    public var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
    
    /// 池状态
    public var poolStatus: PoolStatus {
        let componentCount = componentPools.values.reduce(0) { $0 + $1.count }
        let componentTypes = componentPools.count
        
        let viewCount = viewPools.values.reduce(0) { $0 + $1.count }
        let viewTypes = viewPools.count
        
        return PoolStatus(
            componentCount: componentCount,
            componentTypes: componentTypes,
            viewCount: viewCount,
            viewTypes: viewTypes,
            hitCount: hitCount,
            missCount: missCount
        )
    }
    
    // MARK: - Private
    
    private func resetComponent(_ component: Component) {
        // 清理视图关联
        component.view?.removeFromSuperview()
        component.view = nil
        
        // 清理子组件
        component.children.removeAll()
        component.parent = nil
        
        // 清理绑定数据
        component.bindings.removeAll()
        component.events.removeAll()
        
        // 重置布局相关状态
        component.layoutResult = LayoutResult()
        if let base = component as? BaseComponent {
            base.lastLayoutStyle = nil
        }
    }
    
    private func reconfigureComponent(_ component: Component, from json: JSONWrapper) {
        if let base = component as? BaseComponent {
            base.jsonWrapper = json
            // 解析新的 bindings
            base.parseBaseParams(from: json)
            // 重要：重置 lastLayoutStyle，否则会保留上一次的状态
            base.lastLayoutStyle = nil
            TXLogger.debug("[ComponentPool] reconfigured \(component.id), reset lastLayoutStyle")
        }
    }
    
    private func resetView(_ view: UIView) {
        // 移除所有子视图
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // 移除所有手势
        view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }
        
        // 重置基础属性
        view.alpha = 1
        view.isHidden = false
        view.transform = .identity
        view.backgroundColor = nil
        view.layer.cornerRadius = 0
        view.layer.borderWidth = 0
        view.layer.shadowOpacity = 0
        view.clipsToBounds = false
        
        // 移除所有 layer 遮罩
        view.layer.mask = nil
        view.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
    }
}

// MARK: - PoolStatus

/// 池状态信息
public struct PoolStatus {
    public let componentCount: Int
    public let componentTypes: Int
    public let viewCount: Int
    public let viewTypes: Int
    public let hitCount: Int
    public let missCount: Int
    
    public var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
    
    public var description: String {
        return """
        ComponentPool Status:
          Components: \(componentCount) items in \(componentTypes) types
          Views: \(viewCount) items in \(viewTypes) types
          Hit Rate: \(String(format: "%.1f%%", hitRate * 100)) (\(hitCount)/\(hitCount + missCount))
        """
    }
}

// MARK: - 内存警告处理

extension ComponentPool {
    
    /// 注册内存警告通知
    public func registerMemoryWarning() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        TXLogger.warning("Memory warning - shrinking component pool")
        shrink(to: 0.25)
    }
}
