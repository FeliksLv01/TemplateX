import UIKit

// MARK: - FlexLayout 组件

/// Flexbox 布局组件 - 标准 CSS Flexbox 容器
/// 支持 flexDirection, justifyContent, alignItems 等属性
public final class FlexLayoutComponent: BaseComponent, ComponentFactory {
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "flex" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = FlexLayoutComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: FlexLayoutComponent.typeIdentifier)
    }
    
    // MARK: - Parse
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
    }
    
    // MARK: - View
    
    public override func createView() -> UIView {
        let view = UIView()
        self.view = view
        return view
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        // 使用原 id，确保 Diff 算法能正确匹配组件
        let cloned = FlexLayoutComponent(id: self.id)
        cloned.style = self.style
        cloned.bindings = self.bindings
        cloned.events = self.events
        cloned.jsonWrapper = self.jsonWrapper
        return cloned
    }
}

// MARK: - 兼容别名

/// view 类型也作为 flex 容器（所有 view 都是 flex 容器）
/// ViewComponent 已经是 flex 容器，这里提供 "container" 别名
public final class ContainerComponent: BaseComponent, ComponentFactory {
    
    public static var typeIdentifier: String { "container" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = ContainerComponent(id: id)
        component.jsonWrapper = json
        component.parseBaseParams(from: json)
        return component
    }
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: ContainerComponent.typeIdentifier)
    }
    
    public override func createView() -> UIView {
        let view = UIView()
        self.view = view
        return view
    }
    
    public override func clone() -> Component {
        // 使用原 id，确保 Diff 算法能正确匹配组件
        let cloned = ContainerComponent(id: self.id)
        cloned.style = self.style
        cloned.bindings = self.bindings
        cloned.events = self.events
        cloned.jsonWrapper = self.jsonWrapper
        return cloned
    }
}
