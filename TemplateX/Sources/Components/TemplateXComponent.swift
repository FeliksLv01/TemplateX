import UIKit

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

// MARK: - ComponentFactory 协议

/// 组件工厂协议
public protocol ComponentFactory {
    /// 组件类型标识
    static var typeIdentifier: String { get }
    
    /// 从 JSON 创建组件
    static func create(from json: JSONWrapper) -> Component?
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
open class TemplateXComponent<V: UIView, P: ComponentProps>: BaseComponent, ComponentFactory {
    
    // MARK: - Properties
    
    /// 组件特有属性（自动解析、自动克隆）
    var props: P = P()
    
    // MARK: - ComponentFactory
    
    /// 组件类型标识（子类必须重写）
    open class var typeIdentifier: String {
        fatalError("子类必须重写 typeIdentifier")
    }
    
    /// 工厂方法（自动处理解析和初始化）
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = Self.init(id: id, type: typeIdentifier)
        component.jsonWrapper = json
        component.parseBaseParams(from: json)
        
        // 解析 props，捕获错误
        let (props, error) = Self.parsePropsWithError(from: json.props)
        component.props = props
        component.parseError = error
        
        component.didParseProps()
        return component
    }
    
    /// 解析 Props（使用 Codable 自动解析）
    /// 子类可重写以自定义解析逻辑
    class func parseProps(from json: JSONWrapper?) -> P {
        return parsePropsWithError(from: json).props
    }
    
    /// 解析 Props 并返回错误信息
    class func parsePropsWithError(from json: JSONWrapper?) -> (props: P, error: Error?) {
        guard let json = json else { return (P(), nil) }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: json.rawDictionary)
            let props = try JSONDecoder().decode(P.self, from: data)
            return (props, nil)
        } catch {
            TXLogger.warning("parseProps failed: \(error), using default")
            return (P(), error)
        }
    }
    
    // MARK: - Init
    
    public required override init(id: String = UUID().uuidString, type: String) {
        super.init(id: id, type: type)
    }
    
    /// 便捷初始化
    convenience init(id: String = UUID().uuidString) {
        self.init(id: id, type: Self.typeIdentifier)
    }
    
    // MARK: - View Lifecycle
    
    /// 创建视图（子类可重写）
    /// 注意：解析错误由 RenderEngine 统一处理，会显示 errorView
    open override func createView() -> UIView {
        let view = V()
        self.view = view
        return view
    }
    
    /// 更新视图
    open override func updateView() {
        super.updateView()
        guard let view = view as? V else { return }
        configureView(view)
    }
    
    /// 配置视图（子类重写）
    /// 在 createView 之后和每次 updateView 时调用
    open func configureView(_ view: V) {
        // 子类重写
    }
    
    /// 属性解析完成钩子（子类重写）
    /// 在 parseProps 之后调用，用于后处理
    open func didParseProps() {
        // 子类重写
    }
    
    // MARK: - Clone
    
    /// 克隆组件（自动克隆 props）
    open override func clone() -> Component {
        let cloned = Self.init(id: self.id, type: self.type)
        cloned.style = self.style
        cloned.bindings = self.bindings
        cloned.events = self.events
        cloned.jsonWrapper = self.jsonWrapper
        cloned.props = self.props  // 结构体直接赋值即深拷贝
        return cloned
    }
    
    /// 从另一个组件复制 props（用于增量更新）
    open override func copyProps(from other: Component) {
        guard let other = other as? Self else { return }
        self.props = other.props
    }
    
    // MARK: - Diff
    
    open override func needsUpdate(with other: Component) -> Bool {
        guard let otherComponent = other as? Self else { return true }
        if props != otherComponent.props { return true }
        return super.needsUpdate(with: other)
    }
}
