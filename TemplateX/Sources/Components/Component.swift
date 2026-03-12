import UIKit
import yoga

// MARK: - ComponentFlags

/// 组件状态标记
/// 对应 Lynx: list_item_view_holder.h:57
public struct ComponentFlags: OptionSet {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    /// 已绑定数据
    public static let bound = ComponentFlags(rawValue: 1 << 0)
    
    /// 需要更新
    public static let update = ComponentFlags(rawValue: 1 << 1)
    
    /// 已失效（需要重新创建）
    public static let invalid = ComponentFlags(rawValue: 1 << 2)
    
    /// 预加载创建（来自 GapWorker）
    public static let prefetch = ComponentFlags(rawValue: 1 << 3)
}

// MARK: - 组件协议

/// 组件协议 - 所有 DSL 组件的基础
public protocol Component: AnyObject {
    /// 组件唯一标识
    var id: String { get }
    
    /// 组件类型
    var type: String { get }
    
    /// 组件样式（布局 + 视觉 + 文本样式）
    var style: ComponentStyle { get set }
    
    /// 子组件
    var children: [Component] { get set }
    
    /// 父组件
    var parent: Component? { get set }
    
    /// 关联的 UIView
    var view: UIView? { get set }
    
    /// 布局结果
    var layoutResult: LayoutResult { get set }
    
    /// 绑定数据
    var bindings: [String: Any] { get set }
    
    /// 事件配置
    var events: [String: Any] { get set }
    
    // MARK: - Yoga 剪枝优化
    
    /// 关联的 Yoga 节点（用于增量布局优化）
    var yogaNode: YGNodeRef? { get set }
    
    /// 上次布局时的样式（用于检测样式是否变化）
    var lastLayoutStyle: ComponentStyle? { get set }
    
    /// 释放 Yoga 节点（递归释放整棵组件树的 YGNode）
    func releaseYogaNode()
    
    // MARK: - 引擎内部使用
    
    /// 解析错误信息（props 解析失败时设置）
    var parseError: Error? { get set }
    
    /// 原始模板 JSON（数据绑定时使用）
    var templateJSON: TXJSONNode? { get set }
    
    /// 组件状态标记（GapWorker 预加载状态）
    var componentFlags: ComponentFlags { get set }
    
    /// 是否需要强制应用样式（视图复用时设置为 true）
    var forceApplyStyle: Bool { get set }
    
    /// 是否被视图拍平剪枝（纯布局容器不创建 UIView）
    var isPruned: Bool { get set }
    
    /// 是否需要更新视图（脏标记，由数据绑定/Diff 设置，updateView 后重置）
    var needsViewUpdate: Bool { get set }
    
    // MARK: - 生命周期
    
    /// 创建视图
    func createView() -> UIView
    
    /// 更新视图（应用布局、样式、事件）
    func updateView()
    
    /// 判断是否需要更新
    func needsUpdate(with other: Component) -> Bool
    
    /// 添加子组件
    func addChild(_ child: Component)
    
    /// 移除子组件
    func removeChild(_ child: Component)
    
    /// 克隆组件（深拷贝属性，不包括 view 和 children）
    func clone() -> Component
    
    /// 从另一个组件复制属性（用于增量更新）
    func copyProps(from other: Component)
    
    /// 使用解析后的字典重新 decode props（数据绑定阶段调用）
    func reloadProps(from resolved: [String: Any])
}

// MARK: - Component 默认实现

extension Component {
    /// 是否解析失败
    public var hasParseError: Bool { parseError != nil }
    
    /// 递归克隆整棵组件树（clone 自身 + 递归克隆 children + 设置 parent）
    public func cloneTree() -> Component {
        let cloned = clone()
        for child in children {
            let clonedChild = child.cloneTree()
            clonedChild.parent = cloned
            cloned.children.append(clonedChild)
        }
        return cloned
    }
}

// MARK: - 组件注册表

/// 组件注册表
public final class ComponentRegistry {
    
    public static let shared = ComponentRegistry()
    
    /// 注册的组件工厂（typeIdentifier → 工厂闭包）
    /// 使用闭包擦除 TemplateXComponent<V,P> 的泛型参数
    private var factories: [String: (TXJSONNode) -> Component] = [:]
    
    private init() {
        registerBuiltinComponents()
    }
    
    /// 注册组件
    public func register<V: UIView, P: ComponentProps>(_ componentType: TemplateXComponent<V, P>.Type) {
        factories[componentType.typeIdentifier] = { json in
            componentType.create(from: json)
        }
    }
    
    /// 创建组件（仅引擎内部使用）
    /// - 返回 nil 表示类型未注册
    /// - 解析失败时仍返回组件实例（设置 parseError）
    func createComponent(type: String, from json: TXJSONNode) -> Component? {
        let start = CACurrentMediaTime()
        guard let factory = factories[type] else {
            TXLogger.error("Unknown component type: \(type)")
            return nil
        }
        let result = factory(json)
        let elapsed = (CACurrentMediaTime() - start) * 1000
        TXLogger.verbose("createComponent(\(type)): \(String(format: "%.2f", elapsed))ms")
        return result
    }
    
    /// 注册内置组件
    private func registerBuiltinComponents() {
        register(ContainerComponent.self)
        register(TextComponent.self)
        register(ImageComponent.self)
        register(ScrollComponent.self)
        register(ListComponent.self)
        register(GridComponent.self)
        register(ButtonComponent.self)
        register(InputComponent.self)
    }
}
