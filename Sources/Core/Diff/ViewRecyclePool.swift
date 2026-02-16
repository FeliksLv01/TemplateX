import UIKit

// MARK: - 视图复用池

/// 视图复用池
/// 按类型分组管理可复用的视图，避免频繁创建和销毁
/// 注意：此类只在主线程访问，无需加锁
public final class ViewRecyclePool {
    
    // MARK: - 单例
    
    public static let shared = ViewRecyclePool()
    
    // MARK: - 配置
    
    /// 池配置
    public struct Config {
        /// 每种类型的最大缓存数量
        public var maxSizePerType: Int = 20
        
        /// 总最大缓存数量
        public var maxTotalSize: Int = 100
        
        /// 是否启用统计
        public var enableStatistics: Bool = false
        
        public init() {}
    }
    
    public var config = Config()
    
    // MARK: - 存储
    
    /// 视图池：componentType -> [UIView]
    private var viewPool: [String: [UIView]] = [:]
    
    /// 组件池：componentType -> [Component]
    private var componentPool: [String: [Component]] = [:]
    
    /// 当前总数
    private var totalViewCount: Int = 0
    private var totalComponentCount: Int = 0
    
    /// 统计信息
    private var statistics = PoolStatistics()
    
    private init() {}
    
    // MARK: - 视图复用
    
    /// 获取可复用的视图
    /// - Parameter type: 组件类型
    /// - Returns: 可复用的视图，如果没有返回 nil
    public func dequeueView(forType type: String) -> UIView? {
        guard var views = viewPool[type], !views.isEmpty else {
            if config.enableStatistics {
                statistics.misses += 1
            }
            return nil
        }
        
        let view = views.removeLast()
        viewPool[type] = views
        totalViewCount -= 1
        
        if config.enableStatistics {
            statistics.hits += 1
        }
        
        // 重置视图状态
        prepareViewForReuse(view)
        
        return view
    }
    
    /// 回收视图
    /// - Parameters:
    ///   - view: 要回收的视图
    ///   - type: 组件类型
    public func recycleView(_ view: UIView, forType type: String) {
        // 检查容量
        if totalViewCount >= config.maxTotalSize {
            if config.enableStatistics {
                statistics.evictions += 1
            }
            return  // 池已满，直接丢弃
        }
        
        var views = viewPool[type] ?? []
        if views.count >= config.maxSizePerType {
            if config.enableStatistics {
                statistics.evictions += 1
            }
            return  // 该类型已满
        }
        
        // 清理视图
        cleanViewBeforeRecycle(view)
        
        views.append(view)
        viewPool[type] = views
        totalViewCount += 1
        
        if config.enableStatistics {
            statistics.recycled += 1
        }
    }
    
    // MARK: - 组件复用
    
    /// 获取可复用的组件
    /// - Parameter type: 组件类型
    /// - Returns: 可复用的组件
    public func dequeueComponent(forType type: String) -> Component? {
        guard var components = componentPool[type], !components.isEmpty else {
            return nil
        }
        
        let component = components.removeLast()
        componentPool[type] = components
        totalComponentCount -= 1
        
        // 重置组件状态
        prepareComponentForReuse(component)
        
        return component
    }
    
    /// 回收组件
    /// - Parameters:
    ///   - component: 要回收的组件
    public func recycleComponent(_ component: Component) {
        let type = component.type
        
        var components = componentPool[type] ?? []
        if components.count >= config.maxSizePerType {
            return
        }
        
        // 清理组件
        cleanComponentBeforeRecycle(component)
        
        components.append(component)
        componentPool[type] = components
        totalComponentCount += 1
    }
    
    // MARK: - 批量回收
    
    /// 回收整棵视图树
    public func recycleViewTree(_ rootView: UIView, componentType: String) {
        // 先递归回收子视图
        for subview in rootView.subviews {
            // 尝试获取关联的组件类型
            let childType = (subview.layer.value(forKey: "componentType") as? String) ?? "view"
            recycleViewTree(subview, componentType: childType)
        }
        
        // 从父视图移除
        rootView.removeFromSuperview()
        
        // 回收当前视图
        recycleView(rootView, forType: componentType)
    }
    
    /// 回收整棵组件树
    /// 注意：会同时释放组件上缓存的 Yoga 节点
    public func recycleComponentTree(_ component: Component) {
        // 先释放 Yoga 节点（递归）
        component.releaseYogaNode()
        
        // 再递归回收组件和视图
        recycleComponentTreeInternal(component)
    }
    
    /// 内部递归回收组件树
    private func recycleComponentTreeInternal(_ component: Component) {
        // 先递归回收子组件
        for child in component.children {
            recycleComponentTreeInternal(child)
        }
        
        // 回收关联的视图
        if let view = component.view {
            recycleView(view, forType: component.type)
        }
        
        // 回收组件
        recycleComponent(component)
    }
    
    // MARK: - 池管理
    
    /// 清空所有缓存
    public func clear() {
        viewPool.removeAll()
        componentPool.removeAll()
        totalViewCount = 0
        totalComponentCount = 0
        
        if config.enableStatistics {
            statistics.clears += 1
        }
    }
    
    /// 清空特定类型的缓存
    public func clear(forType type: String) {
        if let views = viewPool.removeValue(forKey: type) {
            totalViewCount -= views.count
        }
        if let components = componentPool.removeValue(forKey: type) {
            totalComponentCount -= components.count
        }
    }
    
    /// 缩减池大小（内存警告时调用）
    public func trim(to percentage: Double = 0.5) {
        for type in viewPool.keys {
            if var views = viewPool[type] {
                let targetCount = Int(Double(views.count) * percentage)
                while views.count > targetCount {
                    views.removeLast()
                    totalViewCount -= 1
                }
                viewPool[type] = views
            }
        }
        
        for type in componentPool.keys {
            if var components = componentPool[type] {
                let targetCount = Int(Double(components.count) * percentage)
                while components.count > targetCount {
                    components.removeLast()
                    totalComponentCount -= 1
                }
                componentPool[type] = components
            }
        }
        
        if config.enableStatistics {
            statistics.trims += 1
        }
    }
    
    // MARK: - 统计
    
    /// 获取当前池状态
    public func getPoolInfo() -> PoolInfo {
        var viewTypeCounts: [String: Int] = [:]
        for (type, views) in viewPool {
            viewTypeCounts[type] = views.count
        }
        
        var componentTypeCounts: [String: Int] = [:]
        for (type, components) in componentPool {
            componentTypeCounts[type] = components.count
        }
        
        return PoolInfo(
            totalViewCount: totalViewCount,
            totalComponentCount: totalComponentCount,
            viewTypeCounts: viewTypeCounts,
            componentTypeCounts: componentTypeCounts,
            statistics: config.enableStatistics ? statistics : nil
        )
    }
    
    // MARK: - Private: 视图准备
    
    /// 准备视图以供复用
    private func prepareViewForReuse(_ view: UIView) {
        // 重置常见属性
        view.alpha = 1.0
        view.transform = .identity
        view.isHidden = false
        view.backgroundColor = .clear  // 使用 .clear 而非 nil，确保透明
        
        // 重置 layer
        view.layer.borderWidth = 0
        view.layer.borderColor = nil
        view.layer.cornerRadius = 0
        view.layer.shadowOpacity = 0
        view.layer.mask = nil
        
        // 移除手势
        view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }
        
        // 针对特定视图类型的重置
        if let label = view as? UILabel {
            prepareLabelForReuse(label)
        } else if let textField = view as? UITextField {
            prepareTextFieldForReuse(textField)
        } else if let textView = view as? UITextView {
            prepareTextViewForReuse(textView)
        }
    }
    
    /// 准备 UILabel 复用
    private func prepareLabelForReuse(_ label: UILabel) {
        label.text = nil
        label.attributedText = nil
        label.textColor = .label
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .natural
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingTail
        label.backgroundColor = .clear  // 确保背景透明
    }
    
    /// 准备 UITextField 复用
    private func prepareTextFieldForReuse(_ textField: UITextField) {
        // 清空文本
        textField.text = nil
        textField.attributedText = nil
        textField.placeholder = nil
        textField.attributedPlaceholder = nil
        
        // 重置样式
        textField.textColor = .label
        textField.font = UIFont.systemFont(ofSize: 14)
        textField.textAlignment = .natural
        
        // 重置键盘相关
        textField.keyboardType = .default
        textField.returnKeyType = .default
        textField.isSecureTextEntry = false
        textField.autocapitalizationType = .sentences
        textField.autocorrectionType = .default
        
        // 重置状态
        textField.isEnabled = true
        textField.clearButtonMode = .never
        
        // 移除左右视图
        textField.leftView = nil
        textField.rightView = nil
        textField.leftViewMode = .never
        textField.rightViewMode = .never
        
        // 移除所有 targets
        textField.removeTarget(nil, action: nil, for: .allEvents)
        
        // 清除 delegate（TemplateXTextField 自己是 delegate，但 component 引用需要清除）
        if let templateXTextField = textField as? TemplateXTextField {
            templateXTextField.component = nil
        }
    }
    
    /// 准备 UITextView 复用
    private func prepareTextViewForReuse(_ textView: UITextView) {
        // 清空文本
        textView.text = nil
        textView.attributedText = nil
        
        // 重置样式
        textView.textColor = .label
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.textAlignment = .natural
        
        // 重置键盘相关
        textView.keyboardType = .default
        textView.returnKeyType = .default
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        
        // 重置状态
        textView.isEditable = true
        textView.isSelectable = true
        
        // 重置内边距
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 5
        
        // 清除 delegate 和 component 引用
        if let templateXTextView = textView as? TemplateXTextView {
            templateXTextView.component = nil
            templateXTextView.placeholder = nil
        }
    }
    
    /// 回收前清理视图
    private func cleanViewBeforeRecycle(_ view: UIView) {
        // 从父视图移除
        view.removeFromSuperview()
        
        // 移除所有子视图
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // 移除渐变层等 sublayers
        view.layer.sublayers?.filter { !($0 === view.layer) }.forEach { $0.removeFromSuperlayer() }
    }
    
    /// 准备组件以供复用
    private func prepareComponentForReuse(_ component: Component) {
        // 清除绑定数据
        component.bindings.removeAll()
        
        // 重置布局结果
        component.layoutResult = LayoutResult()
        
        // 清除父子关系
        component.parent = nil
        component.children.removeAll()
        
        // 解除视图关联
        component.view = nil
    }
    
    /// 回收前清理组件
    private func cleanComponentBeforeRecycle(_ component: Component) {
        // 移除所有子组件
        for child in component.children {
            child.parent = nil
        }
        component.children.removeAll()
        
        // 解除父子关系
        component.parent = nil
    }
}

// MARK: - 数据结构

/// 池信息
public struct PoolInfo {
    public let totalViewCount: Int
    public let totalComponentCount: Int
    public let viewTypeCounts: [String: Int]
    public let componentTypeCounts: [String: Int]
    public let statistics: PoolStatistics?
    
    public var description: String {
        var desc = "ViewRecyclePool:\n"
        desc += "  Views: \(totalViewCount)\n"
        desc += "  Components: \(totalComponentCount)\n"
        
        if !viewTypeCounts.isEmpty {
            desc += "  View types:\n"
            for (type, count) in viewTypeCounts.sorted(by: { $0.value > $1.value }) {
                desc += "    \(type): \(count)\n"
            }
        }
        
        if let stats = statistics {
            desc += "  Statistics:\n"
            desc += "    Hits: \(stats.hits)\n"
            desc += "    Misses: \(stats.misses)\n"
            desc += "    Hit rate: \(stats.hitRate)\n"
            desc += "    Recycled: \(stats.recycled)\n"
            desc += "    Evictions: \(stats.evictions)\n"
        }
        
        return desc
    }
}

/// 池统计
public struct PoolStatistics {
    public var hits: Int = 0
    public var misses: Int = 0
    public var recycled: Int = 0
    public var evictions: Int = 0
    public var clears: Int = 0
    public var trims: Int = 0
    
    public var hitRate: String {
        let total = hits + misses
        guard total > 0 else { return "N/A" }
        let rate = Double(hits) / Double(total) * 100
        return String(format: "%.1f%%", rate)
    }
}

// MARK: - 内存警告处理

extension ViewRecyclePool {
    
    /// 注册内存警告监听
    public func registerMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        TXLogger.warning("ViewRecyclePool: Memory warning received, trimming pool...")
        trim(to: 0.25)  // 保留 25%
    }
}

// MARK: - 视图预热

extension ViewRecyclePool {
    
    /// 预热视图配置
    public struct WarmUpConfig {
        /// 视图类型 -> 预创建数量
        public var viewCounts: [String: Int]
        
        /// 默认配置（预热 UITextField 和 UITextView）
        public static var `default`: WarmUpConfig {
            return WarmUpConfig(viewCounts: [
                "input": 4,          // UITextField
                "input_multiline": 2 // UITextView
            ])
        }
        
        /// 空配置
        public static var none: WarmUpConfig {
            return WarmUpConfig(viewCounts: [:])
        }
        
        public init(viewCounts: [String: Int]) {
            self.viewCounts = viewCounts
        }
    }
    
    /// 预热视图池
    /// 
    /// 在 App 启动时调用，预创建重型视图（如 UITextField/UITextView）
    /// 这些视图首次创建较慢（涉及文本系统初始化），预热可以消除首次渲染延迟
    ///
    /// - Parameter config: 预热配置，默认为 `.default`
    /// - Note: 必须在主线程调用
    public func warmUp(config: WarmUpConfig = .default) {
        assert(Thread.isMainThread, "ViewRecyclePool.warmUp must be called on main thread")
        
        let start = CACurrentMediaTime()
        var createdCount = 0
        
        for (type, count) in config.viewCounts {
            let currentCount = viewPool[type]?.count ?? 0
            let toCreate = max(0, count - currentCount)
            
            guard toCreate > 0 else { continue }
            
            var views = viewPool[type] ?? []
            
            for _ in 0..<toCreate {
                if let view = createViewForWarmUp(type: type) {
                    views.append(view)
                    totalViewCount += 1
                    createdCount += 1
                }
            }
            
            viewPool[type] = views
        }
        
        let elapsed = (CACurrentMediaTime() - start) * 1000
        TXLogger.info("ViewRecyclePool.warmUp: created \(createdCount) views in \(String(format: "%.2f", elapsed))ms")
    }
    
    /// 为预热创建视图
    private func createViewForWarmUp(type: String) -> UIView? {
        switch type {
        case "input":
            // 创建 UITextField
            let textField = TemplateXTextField()
            // 触发文本系统初始化
            textField.placeholder = " "
            textField.layoutIfNeeded()
            prepareViewForReuse(textField)
            return textField
            
        case "input_multiline":
            // 创建 UITextView
            let textView = TemplateXTextView()
            // 触发文本系统初始化
            textView.text = " "
            textView.layoutIfNeeded()
            textView.text = ""
            prepareViewForReuse(textView)
            return textView
            
        case "view":
            return UIView()
            
        case "text":
            return UILabel()
            
        case "image":
            return UIImageView()
            
        case "button":
            return UIButton(type: .system)
            
        case "scroll":
            return UIScrollView()
            
        default:
            TXLogger.warning("ViewRecyclePool.warmUp: unknown type '\(type)'")
            return nil
        }
    }
    
    /// 预热特定类型的视图
    /// 
    /// - Parameters:
    ///   - type: 组件类型
    ///   - count: 预创建数量
    public func warmUp(type: String, count: Int) {
        warmUp(config: WarmUpConfig(viewCounts: [type: count]))
    }
}

// MARK: - 视图标记扩展

extension UIView {
    
    private static var componentTypeKey: UInt8 = 0
    
    /// 关联的组件类型（用于回收时识别）
    var componentType: String? {
        get {
            return objc_getAssociatedObject(self, &Self.componentTypeKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &Self.componentTypeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
