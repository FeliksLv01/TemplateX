import UIKit
import yoga

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
    /// 在布局计算时关联 YGNode，下次布局时可以复用
    var yogaNode: YGNodeRef? { get set }
    
    /// 上次布局时的样式（用于检测样式是否变化）
    /// 只有样式变化时才需要重新设置 Yoga 属性并标记 dirty
    var lastLayoutStyle: ComponentStyle? { get set }
    
    /// 释放 Yoga 节点（递归释放整棵组件树的 YGNode）
    func releaseYogaNode()
    
    /// 创建视图
    func createView() -> UIView
    
    /// 更新视图
    func updateView()
    
    /// 应用布局
    func applyLayout()
    
    /// 应用样式
    func applyStyle()
    
    /// 配置事件
    func setupEvents()
    
    /// 判断是否需要更新
    func needsUpdate(with other: Component) -> Bool
    
    /// 添加子组件
    func addChild(_ child: Component)
    
    /// 移除子组件
    func removeChild(_ child: Component)
    
    /// 克隆组件（深拷贝属性，不包括 view 和 children）
    func clone() -> Component
}

// MARK: - 组件基类

/// 组件基类，提供默认实现
open class BaseComponent: Component {
    
    // MARK: - Properties
    
    public let id: String
    public let type: String
    public var style: ComponentStyle
    public var children: [Component] = []
    public weak var parent: Component?
    public var view: UIView?
    public var layoutResult: LayoutResult = LayoutResult()
    
    // MARK: - 绑定数据
    
    /// 原始 JSON 数据
    public var jsonWrapper: JSONWrapper?
    
    /// 绑定的数据
    public var bindings: [String: Any] = [:]
    
    /// 事件配置
    public var events: [String: Any] = [:]
    
    /// 手势处理器
    private var gestureHandler: GestureHandler?
    
    // MARK: - Yoga 剪枝优化
    
    /// 关联的 Yoga 节点（用于增量布局优化）
    /// 在布局计算时关联 YGNode，下次布局时可以复用
    public var yogaNode: YGNodeRef?
    
    /// 上次布局时的样式（用于检测样式是否变化）
    /// 只有样式变化时才需要重新设置 Yoga 属性并标记 dirty
    public var lastLayoutStyle: ComponentStyle?
    
    /// 释放 Yoga 节点（递归释放整棵组件树的 YGNode）
    /// 使用迭代方式避免深层递归栈溢出
    /// 
    /// 注意：会同时释放文本测量上下文，需要通过 YogaLayoutEngine 调用
    public func releaseYogaNode() {
        // 使用 YogaLayoutEngine 的辅助方法释放，以便正确处理 TextMeasureContext
        YogaLayoutEngine.shared.releaseYogaNodes(for: self)
    }
    
    // MARK: - 样式缓存（性能优化）
    
    /// 上次应用到视图的样式
    /// 用于增量更新时跳过未变化的属性设置
    private var _lastAppliedStyle: ComponentStyle?
    
    /// 上次应用的 frame
    private var _lastAppliedFrame: CGRect = .zero
    
    /// 是否需要强制应用样式（视图复用时设置为 true）
    public var forceApplyStyle: Bool = false
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString, type: String) {
        self.id = id
        self.type = type
        self.style = ComponentStyle()
    }
    
    // MARK: - 通用 JSON 解析方法
    
    /// 从 JSON 解析样式
    /// JSON 结构：{ style: {...}, props: {...} }
    public func parseBaseParams(from json: JSONWrapper) {
        // 从 style 对象解析样式
        if let styleSource = json.child("style") {
            style = Self.parseStyle(from: styleSource)
        }
        
        // 解析事件
        if let eventsJson = json.events {
            events = eventsJson.rawDictionary
        }
        
        // 解析绑定
        if let bindingsJson = json.bindings {
            bindings = bindingsJson.rawDictionary
        }
    }
    
    /// 解析样式（布局 + 视觉 + 文本）
    /// 使用 StyleParser 批量解析，一次遍历 JSON 字典
    public static func parseStyle(from source: JSONWrapper) -> ComponentStyle {
        // 使用批量解析器，减少字典查找次数
        return StyleParser.parse(from: source.rawDictionary)
    }
    
    // MARK: - View 生命周期
    
    /// 创建视图 - 子类重写
    open func createView() -> UIView {
        let view = UIView()
        self.view = view
        return view
    }
    
    /// 更新视图 - 应用布局和样式
    open func updateView() {
        applyLayout()
        applyStyle()
        setupEvents()
    }
    
    /// 应用布局结果到视图
    /// 优化：如果 frame 没有变化则跳过设置
    open func applyLayout() {
        guard let view = view else { return }
        
        let newFrame = layoutResult.frame
        
        // 优化：frame 未变化时跳过
        if !forceApplyStyle && _lastAppliedFrame == newFrame {
            return
        }
        
        view.frame = newFrame
        _lastAppliedFrame = newFrame
    }
    
    /// 应用样式到视图
    /// 优化：如果样式未变化且非强制应用，则跳过
    /// 对于视图复用场景，需要设置 forceApplyStyle = true
    open func applyStyle() {
        guard let view = view else { return }
        
        // 保存旧样式用于比较
        let oldStyle = _lastAppliedStyle
        
        // 优化：样式未变化时跳过（但需要检查 frame 变化导致的渐变层更新）
        let styleUnchanged = !forceApplyStyle && oldStyle == style
        let needsGradientUpdate = style.backgroundGradient != nil && view.bounds != .zero
        
        if styleUnchanged && !needsGradientUpdate {
            return
        }
        
        // 记录当前样式
        _lastAppliedStyle = style
        forceApplyStyle = false
        
        // === 显示控制 ===
        applyDisplayAndVisibility(to: view)
        
        // === 视觉属性（无条件应用，确保不残留旧样式） ===
        
        // 背景色：无条件设置，nil 时使用 .clear 确保透明
        view.backgroundColor = style.backgroundColor ?? .clear
        
        // 渐变背景
        if let gradient = style.backgroundGradient {
            applyGradient(gradient, to: view)
        } else {
            // 优化：只有当之前有渐变时才查找和清除
            if oldStyle?.backgroundGradient != nil {
                view.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
            }
        }
        
        // 圆角：无条件设置
        view.layer.cornerRadius = style.cornerRadius
        
        // 独立圆角
        if let radii = style.cornerRadii {
            applyCornerRadii(radii, to: view)
        } else {
            // 优化：只有当之前有独立圆角时才清除 mask
            if oldStyle?.cornerRadii != nil {
                view.layer.mask = nil
            }
        }
        
        // 边框：无条件设置
        view.layer.borderWidth = style.borderWidth
        view.layer.borderColor = style.borderColor?.cgColor
        
        // 阴影：无条件设置
        view.layer.shadowColor = style.shadowColor?.cgColor
        view.layer.shadowOffset = style.shadowOffset
        view.layer.shadowRadius = style.shadowRadius
        view.layer.shadowOpacity = style.shadowOpacity
        
        // 裁剪
        view.clipsToBounds = style.clipsToBounds
    }
    
    /// 应用 display 和 visibility 到视图
    private func applyDisplayAndVisibility(to view: UIView) {
        switch style.display {
        case .none:
            // 不可见 + 不占空间
            view.isHidden = true
            
        case .flex:
            view.isHidden = false
            
            switch style.visibility {
            case .hidden:
                // 不可见 + 占空间（alpha=0 + 禁用交互）
                view.alpha = 0
                view.isUserInteractionEnabled = false
                
            case .visible:
                // 正常可见
                view.alpha = style.opacity
                view.isUserInteractionEnabled = true
            }
        }
    }
    
    // MARK: - 事件配置
    
    /// 配置事件处理
    open func setupEvents() {
        guard let view = view, !events.isEmpty else { return }
        
        // 使用 GestureHandlerManager 配置事件
        GestureHandlerManager.shared.configureEvents(
            for: self,
            view: view,
            events: events
        )
    }
    
    // MARK: - Diff
    
    /// 判断是否需要更新
    open func needsUpdate(with other: Component) -> Bool {
        // 类型不同
        if type != other.type { return true }
        
        // 样式不同
        if style != other.style { return true }
        
        return false
    }
    
    // MARK: - 克隆
    
    /// 克隆组件（深拷贝属性，不包括 view 和 children）
    open func clone() -> Component {
        let cloned = BaseComponent(id: id, type: type)
        cloned.style = style
        cloned.bindings = bindings
        cloned.events = events
        cloned.layoutResult = layoutResult
        cloned.jsonWrapper = jsonWrapper
        return cloned
    }
    
    // MARK: - 子组件管理
    
    /// 添加子组件
    public func addChild(_ child: Component) {
        children.append(child)
        child.parent = self
    }
    
    /// 移除子组件
    public func removeChild(_ child: Component) {
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children.remove(at: index)
            child.parent = nil
        }
    }
    
    /// 移除所有子组件
    public func removeAllChildren() {
        for child in children {
            child.parent = nil
        }
        children.removeAll()
    }
    
    // MARK: - Private
    
    private func applyGradient(_ gradient: GradientStyle, to view: UIView) {
        // 移除已有的渐变层
        view.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = gradient.colors.map { $0.cgColor }
        gradientLayer.locations = gradient.locations?.map { NSNumber(value: Float($0)) }
        
        switch gradient.direction {
        case .topToBottom:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        case .bottomToTop:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        case .leftToRight:
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        case .rightToLeft:
            gradientLayer.startPoint = CGPoint(x: 1, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 0, y: 0.5)
        case .topLeftToBottomRight:
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        case .topRightToBottomLeft:
            gradientLayer.startPoint = CGPoint(x: 1, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        case .bottomLeftToTopRight:
            gradientLayer.startPoint = CGPoint(x: 0, y: 1)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        case .bottomRightToTopLeft:
            gradientLayer.startPoint = CGPoint(x: 1, y: 1)
            gradientLayer.endPoint = CGPoint(x: 0, y: 0)
        }
        
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func applyCornerRadii(_ radii: CornerRadii, to view: UIView) {
        let path = UIBezierPath(
            roundedRect: view.bounds,
            byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: radii.topLeft, height: radii.topLeft) // 简化版
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask
    }
}

// MARK: - 组件注册表

/// 组件工厂协议
public protocol ComponentFactory {
    /// 组件类型标识
    static var typeIdentifier: String { get }
    
    /// 从 JSON 创建组件
    static func create(from json: JSONWrapper) -> Component?
}

/// 组件注册表
public final class ComponentRegistry {
    
    public static let shared = ComponentRegistry()
    
    /// 注册的组件工厂
    private var factories: [String: ComponentFactory.Type] = [:]
    
    private init() {
        // 注册内置组件
        registerBuiltinComponents()
    }
    
    /// 注册组件
    public func register(_ factory: ComponentFactory.Type) {
        factories[factory.typeIdentifier] = factory
    }
    
    /// 创建组件
    public func createComponent(type: String, from json: JSONWrapper) -> Component? {
        let start = CACurrentMediaTime()
        guard let factory = factories[type] else {
            TXLogger.error("Unknown component type: \(type)")
            return nil
        }
        let result = factory.create(from: json)
        let elapsed = (CACurrentMediaTime() - start) * 1000
        // 使用 verbose 级别，避免大量日志输出影响性能
        TXLogger.verbose("createComponent(\(type)): \(String(format: "%.2f", elapsed))ms")
        return result
    }
    
    /// 注册内置组件
    private func registerBuiltinComponents() {
        // 基础视图
        register(ViewComponent.self)
        register(TextComponent.self)
        register(ImageComponent.self)
        
        // Flexbox 布局组件
        register(FlexLayoutComponent.self)
        register(ContainerComponent.self)
        
        // 容器组件
        register(ScrollComponent.self)
        register(ListComponent.self)
        register(GridComponent.self)
        
        // 交互组件
        register(ButtonComponent.self)
        register(InputComponent.self)
    }
}
