import XCTest
@testable import TemplateX

final class ComponentTests: XCTestCase {
    
    // MARK: - ViewComponent Tests
    
    func testViewComponentCreation() {
        let json = JSONWrapper([
            "type": "container",
            "id": "test_view",
            "style": [
                "width": 100,
                "height": 50,
                "backgroundColor": "#FF0000",
                "cornerRadius": 8
            ]
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create ViewComponent")
            return
        }
        
        XCTAssertEqual(component.id, "test_view")
        XCTAssertEqual(component.type, "view")
        XCTAssertEqual(component.style.width, .fixed(100))
        XCTAssertEqual(component.style.height, .fixed(50))
        XCTAssertEqual(component.style.cornerRadius, 8)
    }
    
    func testViewComponentViewCreation() {
        let json = JSONWrapper([
            "type": "container",
            "id": "view_test"
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        let view = component.createView()
        
        XCTAssertNotNil(view)
        XCTAssertTrue(view is UIView)
    }
    
    // MARK: - TextComponent Tests
    
    func testTextComponentCreation() {
        let json = JSONWrapper([
            "type": "text",
            "id": "test_text",
            "style": [
                "fontSize": 16,
                "textColor": "#333333",
                "textAlign": "center"
            ],
            "props": [
                "text": "Hello World"
            ]
        ])
        
        guard let component = TextComponent.create(from: json) else {
            XCTFail("Failed to create TextComponent")
            return
        }
        
        XCTAssertEqual(component.type, "text")
    }
    
    func testTextComponentLabel() {
        let json = JSONWrapper([
            "type": "text",
            "id": "label_test",
            "style": [
                "fontSize": 14
            ],
            "props": [
                "text": "Test Label"
            ]
        ])
        
        guard let component = TextComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        let view = component.createView()
        
        XCTAssertTrue(view is UILabel)
        
        // 需要调用 updateView 来应用属性
        component.bindings["text"] = "Test Label"
        component.updateView()
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "Test Label")
        }
    }
    
    func testTextComponentAlignment() {
        let alignments: [(String, NSTextAlignment)] = [
            ("left", .left),
            ("center", .center),
            ("right", .right)
        ]
        
        for (alignStr, expected) in alignments {
            let json = JSONWrapper([
                "type": "text",
                "id": "align_test",
                "style": [
                    "textAlign": alignStr
                ],
                "props": [
                    "text": "Aligned"
                ]
            ])
            
            guard let component = TextComponent.create(from: json) else {
                XCTFail("Failed to create component for alignment: \(alignStr)")
                continue
            }
            
            let view = component.createView()
            component.updateView()
            
            if let label = view as? UILabel {
                XCTAssertEqual(label.textAlignment, expected, "Alignment mismatch for: \(alignStr)")
            }
        }
    }
    
    // MARK: - ImageComponent Tests
    
    func testImageComponentCreation() {
        let json = JSONWrapper([
            "type": "image",
            "id": "test_image",
            "style": [
                "width": 100,
                "height": 100
            ],
            "props": [
                "src": "https://example.com/image.png",
                "contentMode": "scaleAspectFit"
            ]
        ])
        
        guard let component = ImageComponent.create(from: json) else {
            XCTFail("Failed to create ImageComponent")
            return
        }
        
        XCTAssertEqual(component.type, "image")
        
        let view = component.createView()
        XCTAssertTrue(view is UIImageView)
    }
    
    func testImageComponentContentMode() {
        let modes: [(String, UIView.ContentMode)] = [
            ("scaleToFill", .scaleToFill),
            ("scaleAspectFit", .scaleAspectFit),
            ("scaleAspectFill", .scaleAspectFill),
            ("center", .center)
        ]
        
        for (modeStr, expected) in modes {
            let json = JSONWrapper([
                "type": "image",
                "id": "mode_test",
                "props": [
                    "contentMode": modeStr
                ]
            ])
            
            guard let component = ImageComponent.create(from: json) else {
                XCTFail("Failed to create component for mode: \(modeStr)")
                continue
            }
            
            let view = component.createView()
            component.updateView()
            
            if let imageView = view as? UIImageView {
                XCTAssertEqual(imageView.contentMode, expected, "ContentMode mismatch for: \(modeStr)")
            }
        }
    }
    
    // MARK: - ButtonComponent Tests
    
    func testButtonComponentCreation() {
        let json = JSONWrapper([
            "type": "button",
            "id": "test_button",
            "style": [
                "backgroundColor": "#007AFF",
                "titleColor": "#FFFFFF"
            ],
            "props": [
                "title": "Click Me"
            ]
        ])
        
        guard let component = ButtonComponent.create(from: json) else {
            XCTFail("Failed to create ButtonComponent")
            return
        }
        
        XCTAssertEqual(component.type, "button")
        
        let view = component.createView()
        XCTAssertTrue(view is UIButton)
    }
    
    func testButtonComponentTitle() {
        let json = JSONWrapper([
            "type": "button",
            "id": "btn_title_test",
            "props": [
                "title": "Submit"
            ]
        ])
        
        guard let component = ButtonComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        let view = component.createView()
        component.bindings["title"] = "Submit"
        component.updateView()
        
        if let button = view as? UIButton {
            XCTAssertEqual(button.title(for: .normal), "Submit")
        }
    }
    
    // MARK: - InputComponent Tests
    
    func testInputComponentCreation() {
        let json = JSONWrapper([
            "type": "input",
            "id": "test_input",
            "props": [
                "placeholder": "Enter text",
                "keyboardType": "email"
            ]
        ])
        
        guard let component = InputComponent.create(from: json) else {
            XCTFail("Failed to create InputComponent")
            return
        }
        
        XCTAssertEqual(component.type, "input")
        
        let view = component.createView()
        XCTAssertTrue(view is UITextField)
    }
    
    func testInputComponentPlaceholder() {
        let json = JSONWrapper([
            "type": "input",
            "id": "input_placeholder_test",
            "props": [
                "placeholder": "Enter your email"
            ]
        ])
        
        guard let component = InputComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        let view = component.createView()
        component.bindings["placeholder"] = "Enter your email"
        component.updateView()
        
        if let textField = view as? UITextField {
            XCTAssertEqual(textField.placeholder, "Enter your email")
        }
    }
    
    // MARK: - FlexLayoutComponent Tests
    
    func testFlexLayoutVertical() {
        let json = JSONWrapper([
            "type": "container",
            "id": "vertical_layout",
            "style": [
                "width": "100%",
                "height": "auto",
                "flexDirection": "column"
            ]
        ])
        
        guard let component = FlexLayoutComponent.create(from: json) else {
            XCTFail("Failed to create FlexLayoutComponent")
            return
        }
        
        XCTAssertEqual(component.type, "flex")
    }
    
    func testFlexLayoutHorizontal() {
        let json = JSONWrapper([
            "type": "container",
            "id": "horizontal_layout",
            "style": [
                "flexDirection": "row"
            ]
        ])
        
        guard let component = FlexLayoutComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        let view = component.createView()
        XCTAssertNotNil(view)
    }
    
    // MARK: - ScrollComponent Tests
    
    func testScrollComponentCreation() {
        let json = JSONWrapper([
            "type": "scroll",
            "id": "scroll_view",
            "props": [
                "direction": "vertical",
                "showsIndicator": true
            ]
        ])
        
        guard let component = ScrollComponent.create(from: json) else {
            XCTFail("Failed to create ScrollComponent")
            return
        }
        
        XCTAssertEqual(component.type, "scroll")
        
        let view = component.createView()
        XCTAssertTrue(view is UIScrollView)
    }
    
    // MARK: - ListComponent Tests
    
    func testListComponentCreation() {
        let json = JSONWrapper([
            "type": "list",
            "id": "list_view",
            "props": [
                "data": "${items}",
                "itemType": "item_template"
            ]
        ])
        
        guard let component = ListComponent.create(from: json) else {
            XCTFail("Failed to create ListComponent")
            return
        }
        
        XCTAssertEqual(component.type, "list")
        
        let view = component.createView()
        XCTAssertTrue(view is UITableView)
    }
    
    // MARK: - GridComponent Tests
    
    func testGridComponentCreation() {
        let json = JSONWrapper([
            "type": "grid",
            "id": "grid_view",
            "props": [
                "columns": 3,
                "spacing": 8
            ]
        ])
        
        guard let component = GridComponent.create(from: json) else {
            XCTFail("Failed to create GridComponent")
            return
        }
        
        XCTAssertEqual(component.type, "grid")
        
        let view = component.createView()
        XCTAssertTrue(view is UICollectionView)
    }
    
    // MARK: - Component Registry Tests
    
    func testComponentRegistryBuiltinTypes() {
        let registry = ComponentRegistry.shared
        
        let builtinTypes = [
            "view", "text", "image", "button", "input",
            "flex", "scroll", "list", "grid"
        ]
        
        for type in builtinTypes {
            let component = registry.createComponent(
                type: type,
                from: JSONWrapper(["type": type, "id": "test_\(type)"])
            )
            XCTAssertNotNil(component, "Failed to create component of type: \(type)")
        }
    }
    
    func testComponentRegistryUnknownType() {
        let registry = ComponentRegistry.shared
        
        let component = registry.createComponent(
            type: "nonexistent_type",
            from: JSONWrapper(["type": "nonexistent_type"])
        )
        
        XCTAssertNil(component)
    }
    
    // MARK: - Style Tests
    
    func testStyleFromJSON() {
        let json = JSONWrapper([
            "type": "container",
            "id": "style_test",
            "style": [
                "width": "100%",
                "height": "auto",
                "margin": [8, 16, 8, 16],
                "padding": 12,
                "backgroundColor": "#FF5500",
                "cornerRadius": 16,
                "borderWidth": 2,
                "borderColor": "#000000",
                "opacity": 0.9
            ]
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        XCTAssertEqual(component.style.width, .matchParent)
        XCTAssertEqual(component.style.height, .wrapContent)
        XCTAssertNotNil(component.style.backgroundColor)
        XCTAssertEqual(component.style.cornerRadius, 16)
        XCTAssertEqual(component.style.borderWidth, 2)
        XCTAssertEqual(component.style.opacity, 0.9, accuracy: 0.01)
    }
    
    func testFixedDimension() {
        let json = JSONWrapper([
            "type": "container",
            "id": "fixed_test",
            "style": [
                "width": 150,
                "height": 75
            ]
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        XCTAssertEqual(component.style.width, .fixed(150))
        XCTAssertEqual(component.style.height, .fixed(75))
    }
    
    func testPercentDimension() {
        let json = JSONWrapper([
            "type": "container",
            "id": "percent_test",
            "style": [
                "width": "50%",
                "height": "25%"
            ]
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        XCTAssertEqual(component.style.width, .percent(0.5))
        XCTAssertEqual(component.style.height, .percent(0.25))
    }
    
    func testStyleShadow() {
        let json = JSONWrapper([
            "type": "container",
            "id": "shadow_test",
            "style": [
                "shadowColor": "#000000",
                "shadowOffset": [0, 2],
                "shadowRadius": 4,
                "shadowOpacity": 0.3
            ]
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        XCTAssertEqual(component.style.shadowRadius, 4)
        XCTAssertEqual(component.style.shadowOpacity, 0.3, accuracy: 0.01)
    }
    
    // MARK: - Display & Visibility Tests
    
    func testDisplayNone() {
        let json = JSONWrapper([
            "type": "container",
            "id": "display_test",
            "style": [
                "display": "none"
            ]
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        XCTAssertEqual(component.style.display, .none)
    }
    
    func testVisibilityHidden() {
        let json = JSONWrapper([
            "type": "container",
            "id": "visibility_test",
            "style": [
                "visibility": "hidden"
            ]
        ])
        
        guard let component = ViewComponent.create(from: json) else {
            XCTFail("Failed to create component")
            return
        }
        
        XCTAssertEqual(component.style.visibility, .hidden)
    }
    
    // MARK: - Component Tree Tests
    
    func testAddChild() {
        let parent = BaseComponent(id: "parent", type: "view")
        let child = BaseComponent(id: "child", type: "view")
        
        parent.addChild(child)
        
        XCTAssertEqual(parent.children.count, 1)
        XCTAssertTrue(child.parent === parent)
    }
    
    func testRemoveChild() {
        let parent = BaseComponent(id: "parent", type: "view")
        let child = BaseComponent(id: "child", type: "view")
        
        parent.addChild(child)
        parent.removeChild(child)
        
        XCTAssertEqual(parent.children.count, 0)
        XCTAssertNil(child.parent)
    }
    
    func testRemoveAllChildren() {
        let parent = BaseComponent(id: "parent", type: "view")
        
        for i in 0..<5 {
            parent.addChild(BaseComponent(id: "child_\(i)", type: "view"))
        }
        
        XCTAssertEqual(parent.children.count, 5)
        
        parent.removeAllChildren()
        
        XCTAssertEqual(parent.children.count, 0)
    }
    
    // MARK: - Needs Update Tests
    
    func testNeedsUpdateSameComponent() {
        let component1 = BaseComponent(id: "test", type: "view")
        let component2 = BaseComponent(id: "test", type: "view")
        
        // 相同属性不需要更新
        XCTAssertFalse(component1.needsUpdate(with: component2))
    }
    
    func testNeedsUpdateDifferentType() {
        let component1 = BaseComponent(id: "test", type: "view")
        let component2 = BaseComponent(id: "test", type: "text")
        
        // 不同类型需要更新
        XCTAssertTrue(component1.needsUpdate(with: component2))
    }
    
    func testNeedsUpdateDifferentStyle() {
        let component1 = BaseComponent(id: "test", type: "view")
        let component2 = BaseComponent(id: "test", type: "view")
        
        component1.style.width = .fixed(100)
        component2.style.width = .fixed(200)
        
        // 不同样式需要更新
        XCTAssertTrue(component1.needsUpdate(with: component2))
    }
    
    func testNeedsUpdateDifferentCornerRadius() {
        let component1 = BaseComponent(id: "test", type: "view")
        let component2 = BaseComponent(id: "test", type: "view")
        
        component1.style.cornerRadius = 8
        component2.style.cornerRadius = 16
        
        // 不同样式需要更新
        XCTAssertTrue(component1.needsUpdate(with: component2))
    }
    
    // MARK: - Clone Tests
    
    func testComponentClone() {
        let original = BaseComponent(id: "test", type: "view")
        original.style.width = .fixed(100)
        original.style.height = .fixed(50)
        original.style.backgroundColor = .red
        original.style.cornerRadius = 8
        original.bindings["key"] = "value"
        
        let cloned = original.clone()
        
        XCTAssertEqual(cloned.id, original.id)
        XCTAssertEqual(cloned.type, original.type)
        XCTAssertEqual(cloned.style.width, original.style.width)
        XCTAssertEqual(cloned.style.height, original.style.height)
        XCTAssertEqual(cloned.style.cornerRadius, original.style.cornerRadius)
        
        // 确保是深拷贝
        cloned.style.cornerRadius = 16
        XCTAssertNotEqual(cloned.style.cornerRadius, original.style.cornerRadius)
    }
    
    func testTextComponentClone() {
        let json = JSONWrapper([
            "type": "text",
            "id": "text_clone_test",
            "style": [
                "fontSize": 16,
                "textColor": "#333333"
            ],
            "props": [
                "text": "Hello"
            ]
        ])
        
        guard let original = TextComponent.create(from: json) else {
            XCTFail("Failed to create TextComponent")
            return
        }
        
        let cloned = original.clone()
        
        XCTAssertTrue(cloned is TextComponent)
        XCTAssertEqual(cloned.id, original.id)
        
        if let clonedText = cloned as? TextComponent {
            XCTAssertEqual(clonedText.text, original.text)
        }
    }
}
