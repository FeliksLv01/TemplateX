import UIKit
import yoga

// MARK: - Default Property Wrapper

/// 默认值提供者协议
public protocol DefaultValueProvider {
    associatedtype Value: Codable & Equatable
    static var defaultValue: Value { get }
}

/// 默认值 Property Wrapper
/// 在 Codable 解码时，如果字段缺失或为 null 则使用默认值
///
/// 用法：
/// ```swift
/// struct Props: ComponentProps {
///     @Default<False> var disabled: Bool      // 默认 false
///     @Default<True> var enabled: Bool        // 默认 true
///     @Default<Empty> var text: String        // 默认 ""
///     @Default<TextInput> var inputType: String // 默认 "text"
/// }
/// ```
@propertyWrapper
public struct Default<Provider: DefaultValueProvider>: Codable, Equatable {
    public var wrappedValue: Provider.Value
    
    public init() {
        self.wrappedValue = Provider.defaultValue
    }
    
    public init(wrappedValue: Provider.Value) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = (try? container.decode(Provider.Value.self)) ?? Provider.defaultValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

/// 让 @Default 在字段缺失时也能正常解码（而不是抛出 keyNotFound）
extension KeyedDecodingContainer {
    public func decode<P: DefaultValueProvider>(
        _ type: Default<P>.Type,
        forKey key: Key
    ) throws -> Default<P> {
        if let value = try? decodeIfPresent(P.Value.self, forKey: key) {
            return Default<P>(wrappedValue: value)
        }
        return Default<P>()
    }
}

// MARK: - 常用默认值提供者

/// Bool 默认 false
public enum False: DefaultValueProvider {
    public static var defaultValue: Bool { false }
}

/// Bool 默认 true
public enum True: DefaultValueProvider {
    public static var defaultValue: Bool { true }
}

/// String 默认 ""
public enum Empty: DefaultValueProvider {
    public static var defaultValue: String { "" }
}

/// String 默认 "text"（用于 inputType）
public enum TextInput: DefaultValueProvider {
    public static var defaultValue: String { "text" }
}

/// Int 默认 0
public enum Zero: DefaultValueProvider {
    public static var defaultValue: Int { 0 }
}

/// CGFloat 默认 0
public enum ZeroFloat: DefaultValueProvider {
    public static var defaultValue: CGFloat { 0 }
}

// MARK: - ComponentProps 协议

/// 组件属性协议
/// 使用 Codable 自动支持 JSON 解析，使用 Equatable 支持 Diff 比较
public protocol ComponentProps: Codable, Equatable {
    /// 创建默认属性
    init()
}

/// 空属性（用于无特有属性的组件）
public struct EmptyProps: ComponentProps {
    public init() {}
}

// MARK: - TemplateXComponent

/// DSL 组件泛型基类
/// - V: 关联的 UIView 子类
/// - P: 组件属性结构体（遵循 ComponentProps）
///
/// 使用 @dynamicMemberLookup 自动转发 props 属性访问，无需手写访问器：
/// ```swift
/// let textComponent = TextComponent()
/// textComponent.text = "Hello"  // 自动转发到 props.text
/// ```
///
/// 使用示例：
/// ```swift
/// // 简单组件（无特有属性）
/// final class ContainerComponent: TemplateXComponent<UIView, EmptyProps> {
///     override class var typeIdentifier: String { "container" }
/// }
///
/// // 复杂组件（有属性）
/// final class TextComponent: TemplateXComponent<UILabel, TextComponent.Props> {
///     struct Props: ComponentProps {
///         var text: String = ""
///     }
///     override class var typeIdentifier: String { "text" }
///     override func configureView(_ view: UILabel) {
///         view.text = props.text
///     }
/// }
/// ```
@dynamicMemberLookup
open class TemplateXComponent<V: UIView, P: ComponentProps>: Component {
    
    // MARK: - Component 协议属性
    
    public let id: String
    public let type: String
    public var style: ComponentStyle
    public var children: [Component] = []
    public weak var parent: Component?
    public var view: UIView?
    public var layoutResult: LayoutResult = LayoutResult()
    public var bindings: [String: Any] = [:]
    public var events: [String: Any] = [:]
    
    // MARK: - Yoga 剪枝优化
    
    public var yogaNode: YGNodeRef?
    public var lastLayoutStyle: ComponentStyle?
    
    public func releaseYogaNode() {
        YogaLayoutEngine.shared.releaseYogaNodes(for: self)
    }
    
    // MARK: - 引擎内部使用
    
    /// 解析错误信息（props 解析失败时设置）
    public var parseError: Error?
    
    /// 原始模板 JSON（数据绑定时使用）
    public var templateJSON: TXJSONNode?
    
    /// 组件状态标记（GapWorker 预加载状态）
    public var componentFlags: ComponentFlags = []
    
    /// 是否需要强制应用样式（视图复用时设置为 true）
    public var forceApplyStyle: Bool = false
    
    // MARK: - Props
    
    /// 组件特有属性（自动解析、自动克隆）
    var props: P = P()
    
    // MARK: - 私有属性
    
    /// 手势处理器
    private var gestureHandler: GestureHandler?
    
    /// 上次应用到视图的样式（性能优化：跳过未变化的样式）
    private var _previousStyle: ComponentStyle?
    
    /// 上次应用的 frame（性能优化：跳过未变化的 frame）
    private var _previousFrame: CGRect = .zero
    
    // MARK: - Dynamic Member Lookup
    
    /// 动态成员查找：自动转发到 props（读写）
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<P, T>) -> T {
        get { props[keyPath: keyPath] }
        set { props[keyPath: keyPath] = newValue }
    }
    
    /// 动态成员查找：自动转发到 props（只读）
    public subscript<T>(dynamicMember keyPath: KeyPath<P, T>) -> T {
        props[keyPath: keyPath]
    }
    
    // MARK: - 组件类型标识 & 工厂方法
    
    /// 组件类型标识（子类必须重写）
    open class var typeIdentifier: String {
        fatalError("子类必须重写 typeIdentifier")
    }
    
    /// 工厂方法（自动处理解析和初始化）
    /// 解析失败时仍返回组件实例（设置 parseError），保证总是返回有效对象
    public static func create(from json: TXJSONNode) -> Component {
        let id = json.id ?? UUID().uuidString
        let component = Self.init(id: id, type: typeIdentifier)
        component.templateJSON = json
        component.parseBaseParams(from: json)
        
        // 解析 props，捕获错误
        let (props, error) = Self.parsePropsWithError(from: json.props)
        component.props = props
        component.parseError = error
        
        component.didParseProps()
        return component
    }
    
    // MARK: - Init
    
    public required init(id: String = UUID().uuidString, type: String) {
        self.id = id
        self.type = type
        self.style = ComponentStyle()
    }
    
    /// 便捷初始化
    convenience init(id: String = UUID().uuidString) {
        self.init(id: id, type: Self.typeIdentifier)
    }
    
    // MARK: - JSON 解析
    
    /// 从 JSON 解析基础参数（样式、事件、绑定）
    public func parseBaseParams(from json: TXJSONNode) {
        if let styleSource = json.child("style") {
            style = Self.parseStyle(from: styleSource)
        }
        if let eventsJson = json.events {
            events = eventsJson.rawDictionary
        }
        if let bindingsJson = json.bindings {
            bindings = bindingsJson.rawDictionary
        }
    }
    
    /// 解析样式（布局 + 视觉 + 文本）（仅引擎内部使用）
    static func parseStyle(from source: TXJSONNode) -> ComponentStyle {
        return StyleParser.parse(from: source.rawDictionary)
    }
    
    /// 解析 Props（使用 Codable 自动解析）
    /// 子类可重写以自定义解析逻辑
    class func parseProps(from json: TXJSONNode?) -> P {
        guard let json = json else { return P() }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: json.rawDictionary)
            let props = try JSONDecoder().decode(P.self, from: data)
            return props
        } catch {
            TXLogger.warning("parseProps failed: \(error), using default")
            return P()
        }
    }
    
    /// 解析 Props 并返回错误信息
    class func parsePropsWithError(from json: TXJSONNode?) -> (props: P, error: Error?) {
        return (parseProps(from: json), nil)
    }
    
    /// 属性解析完成钩子（子类重写）
    open func didParseProps() {
        // 子类重写
    }
    
    // MARK: - View 生命周期
    
    /// 创建视图（子类可重写）
    /// 注意：无需手动设置 self.view，由 RenderEngine 统一处理
    open func createView() -> UIView {
        return V()
    }
    
    /// 更新视图（应用布局、样式、事件，然后配置视图）
    open func updateView() {
        applyLayout()
        applyStyle()
        setupEvents()
        guard let view = view as? V else { return }
        configureView(view)
    }
    
    /// 配置视图（子类重写）
    /// 在 createView 之后和每次 updateView 时调用
    open func configureView(_ view: V) {
        // 子类重写
    }
    
    /// 应用布局结果到视图
    /// 优化：如果 frame 没有变化则跳过设置
    open func applyLayout() {
        guard let view = view else { return }
        
        let newFrame = layoutResult.frame
        
        if !forceApplyStyle && _previousFrame == newFrame {
            return
        }
        
        view.frame = newFrame
        _previousFrame = newFrame
    }
    
    /// 应用样式到视图
    /// 优化：如果样式未变化且非强制应用，则跳过
    open func applyStyle() {
        guard let view = view else { return }
        
        let oldStyle = _previousStyle
        let styleUnchanged = !forceApplyStyle && oldStyle == style
        let needsGradientUpdate = style.backgroundGradient != nil && view.bounds != .zero
        
        if styleUnchanged && !needsGradientUpdate {
            return
        }
        
        _previousStyle = style
        forceApplyStyle = false
        
        // === 显示控制 ===
        applyDisplayAndVisibility(to: view)
        
        // === 视觉属性（无条件应用，确保不残留旧样式） ===
        
        view.backgroundColor = style.backgroundColor ?? .clear
        
        if let gradient = style.backgroundGradient {
            applyGradient(gradient, to: view)
        } else {
            if oldStyle?.backgroundGradient != nil {
                view.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
            }
        }
        
        view.layer.cornerRadius = style.cornerRadius
        
        if let radii = style.cornerRadii {
            applyCornerRadii(radii, to: view)
        } else {
            if oldStyle?.cornerRadii != nil {
                view.layer.mask = nil
            }
        }
        
        view.layer.borderWidth = style.borderWidth
        view.layer.borderColor = style.borderColor?.cgColor
        
        view.layer.shadowColor = style.shadowColor?.cgColor
        view.layer.shadowOffset = style.shadowOffset
        view.layer.shadowRadius = style.shadowRadius
        view.layer.shadowOpacity = style.shadowOpacity
        
        view.clipsToBounds = style.clipsToBounds
    }
    
    /// 配置事件处理
    open func setupEvents() {
        guard let view = view, !events.isEmpty else { return }
        GestureHandlerManager.shared.configureEvents(
            for: self,
            view: view,
            events: events
        )
    }
    
    // MARK: - Diff
    
    /// 判断是否需要更新
    open func needsUpdate(with other: Component) -> Bool {
        guard let otherComponent = other as? Self else { return true }
        if props != otherComponent.props { return true }
        if type != other.type { return true }
        if style != other.style { return true }
        return false
    }
    
    // MARK: - 克隆
    
    /// 将基础属性复制到目标组件（供子类 clone() 调用）
    /// 不复制 view、children、parent（由 cloneTree 处理）
    /// 不复制 yogaNode、lastLayoutStyle（增量布局缓存，由布局引擎重建）
    public func copyBaseProperties(to target: Component) {
        target.style = style
        target.bindings = bindings
        target.events = events
        target.layoutResult = layoutResult
        target.templateJSON = templateJSON
    }
    
    /// 克隆组件（自动克隆 props + 基础属性）
    open func clone() -> Component {
        let cloned = Self.init(id: self.id, type: self.type)
        copyBaseProperties(to: cloned)
        cloned.props = self.props  // 结构体直接赋值即深拷贝
        return cloned
    }
    
    /// 从另一个组件复制 props（用于增量更新）
    open func copyProps(from other: Component) {
        guard let other = other as? Self else { return }
        self.props = other.props
    }
    
    /// 使用解析后的字典重新 decode props
    /// 数据绑定阶段调用：表达式求值后合并到原始 props 字典，重新 JSONDecoder
    open func reloadProps(from resolved: [String: Any]) {
        guard !resolved.isEmpty else { return }
        
        // 以原始 templateJSON.props 为基础，覆盖表达式解析后的值
        var propsDict = templateJSON?.props?.rawDictionary ?? [:]
        for (key, value) in resolved {
            propsDict[key] = value
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: propsDict)
            self.props = try JSONDecoder().decode(P.self, from: data)
        } catch {
            TXLogger.verbose("reloadProps failed: \(error)")
        }
    }
    
    // MARK: - 子组件管理
    
    public func addChild(_ child: Component) {
        children.append(child)
        child.parent = self
    }
    
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
    
    private func applyDisplayAndVisibility(to view: UIView) {
        switch style.display {
        case .none:
            view.isHidden = true
            
        case .flex:
            view.isHidden = false
            
            switch style.visibility {
            case .hidden:
                view.alpha = 0
                view.isUserInteractionEnabled = false
                
            case .visible:
                view.alpha = style.opacity
                view.isUserInteractionEnabled = true
            }
        }
    }
    
    private func applyGradient(_ gradient: GradientStyle, to view: UIView) {
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
            cornerRadii: CGSize(width: radii.topLeft, height: radii.topLeft)
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask
    }
}
