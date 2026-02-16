import UIKit

// MARK: - View 组件

/// 基础容器组件
public final class ViewComponent: BaseComponent, ComponentFactory {
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "view" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = ViewComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: ViewComponent.typeIdentifier)
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
        let cloned = ViewComponent(id: self.id)
        cloned.style = self.style
        cloned.bindings = self.bindings
        cloned.events = self.events
        cloned.jsonWrapper = self.jsonWrapper
        return cloned
    }
}
