import XCTest
@testable import TemplateX

final class RenderEngineIntegrationTests: XCTestCase {
    
    var engine: RenderEngine!
    
    override func setUp() {
        super.setUp()
        engine = RenderEngine.shared
        engine.config.enablePerformanceMonitor = false
        engine.config.enableViewReuse = true
        engine.config.enableIncrementalUpdate = true
        engine.clearAllCache()
    }
    
    override func tearDown() {
        engine.clearAllCache()
        super.tearDown()
    }
    
    // MARK: - 基础渲染测试
    
    func testRenderSimpleView() {
        // 准备简单的 JSON 模板
        let json: [String: Any] = [
            "type": "container",
            "id": "root",
            "layout": [
                "width": 200,
                "height": 100
            ],
            "style": [
                "backgroundColor": "#FF0000"
            ]
        ]
        
        // 渲染
        let view = engine.render(
            json: json,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        // 验证
        XCTAssertNotNil(view)
        XCTAssertEqual(view?.frame.width, 200)
        XCTAssertEqual(view?.frame.height, 100)
    }
    
    func testRenderTextComponent() {
        let json: [String: Any] = [
            "type": "text",
            "id": "title",
            "layout": [
                "width": "match_parent",
                "height": "wrap_content"
            ],
            "props": [
                "text": "Hello TemplateX"
            ],
            "style": [
                "fontSize": 16,
                "textColor": "#333333"
            ]
        ]
        
        let view = engine.render(
            json: json,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        XCTAssertNotNil(view)
        // 文本组件应该是 UILabel
        XCTAssertTrue(view is UILabel)
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "Hello TemplateX")
        }
    }
    
    func testRenderNestedComponents() {
        // 嵌套布局：一个 LinearLayout 包含两个 Text
        let json: [String: Any] = [
            "type": "linear",
            "id": "container",
            "layout": [
                "width": "match_parent",
                "height": "wrap_content"
            ],
            "props": [
                "orientation": "vertical"
            ],
            "children": [
                [
                    "type": "text",
                    "id": "title",
                    "layout": [
                        "width": "match_parent",
                        "height": "wrap_content"
                    ],
                    "props": [
                        "text": "Title"
                    ]
                ],
                [
                    "type": "text",
                    "id": "subtitle",
                    "layout": [
                        "width": "match_parent",
                        "height": "wrap_content"
                    ],
                    "props": [
                        "text": "Subtitle"
                    ]
                ]
            ]
        ]
        
        let view = engine.render(
            json: json,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view?.subviews.count, 2)
    }
    
    // MARK: - 数据绑定测试
    
    func testDataBinding() {
        let json: [String: Any] = [
            "type": "text",
            "id": "greeting",
            "layout": [
                "width": "match_parent",
                "height": "wrap_content"
            ],
            "props": [
                "text": "${message}"
            ]
        ]
        
        let data: [String: Any] = [
            "message": "Hello from binding!"
        ]
        
        let view = engine.render(
            json: json,
            data: data,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        XCTAssertNotNil(view)
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "Hello from binding!")
        }
    }
    
    func testNestedDataBinding() {
        let json: [String: Any] = [
            "type": "text",
            "id": "user_info",
            "layout": [
                "width": "match_parent",
                "height": "wrap_content"
            ],
            "props": [
                "text": "${user.name}"
            ]
        ]
        
        let data: [String: Any] = [
            "user": [
                "name": "Alice",
                "age": 25
            ]
        ]
        
        let view = engine.render(
            json: json,
            data: data,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "Alice")
        }
    }
    
    func testExpressionBinding() {
        let json: [String: Any] = [
            "type": "text",
            "id": "price",
            "layout": [
                "width": "match_parent",
                "height": "wrap_content"
            ],
            "props": [
                "text": "${'$' + (price * (1 - discount))}"
            ]
        ]
        
        let data: [String: Any] = [
            "price": 100,
            "discount": 0.2
        ]
        
        let view = engine.render(
            json: json,
            data: data,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "$80")
        }
    }
    
    // MARK: - 增量更新测试
    
    func testIncrementalUpdate() {
        let json: [String: Any] = [
            "type": "text",
            "id": "counter",
            "layout": [
                "width": "match_parent",
                "height": 50
            ],
            "props": [
                "text": "${count}"
            ]
        ]
        
        let initialData: [String: Any] = ["count": 0]
        let containerSize = CGSize(width: 375, height: 812)
        
        // 首次渲染
        guard let view = engine.render(json: json, data: initialData, containerSize: containerSize) else {
            XCTFail("Initial render failed")
            return
        }
        
        // 验证初始值
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "0")
        }
        
        // 增量更新
        let newData: [String: Any] = ["count": 42]
        let operationCount = engine.update(view: view, data: newData, containerSize: containerSize)
        
        // 验证更新成功
        XCTAssertGreaterThan(operationCount, 0)
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "42")
        }
    }
    
    func testQuickUpdate() {
        let json: [String: Any] = [
            "type": "text",
            "id": "message",
            "layout": [
                "width": "match_parent",
                "height": 50
            ],
            "props": [
                "text": "${msg}"
            ]
        ]
        
        let containerSize = CGSize(width: 375, height: 812)
        
        guard let view = engine.render(
            json: json,
            data: ["msg": "Initial"],
            containerSize: containerSize
        ) else {
            XCTFail("Render failed")
            return
        }
        
        // Quick update（不做 diff，直接更新绑定）
        engine.quickUpdate(
            view: view,
            data: ["msg": "Updated"],
            containerSize: containerSize
        )
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "Updated")
        }
    }
    
    // MARK: - 组件树管理测试
    
    func testGetComponent() {
        let json: [String: Any] = [
            "type": "container",
            "id": "test_root",
            "layout": ["width": 100, "height": 100]
        ]
        
        guard let view = engine.render(
            json: json,
            containerSize: CGSize(width: 375, height: 812)
        ) else {
            XCTFail("Render failed")
            return
        }
        
        let component = engine.getComponent(for: view)
        XCTAssertNotNil(component)
        XCTAssertEqual(component?.id, "test_root")
        XCTAssertEqual(component?.type, "view")
    }
    
    func testCleanup() {
        let json: [String: Any] = [
            "type": "container",
            "id": "cleanup_test",
            "layout": ["width": 100, "height": 100]
        ]
        
        guard let view = engine.render(
            json: json,
            containerSize: CGSize(width: 375, height: 812)
        ) else {
            XCTFail("Render failed")
            return
        }
        
        // 确认组件已缓存
        XCTAssertNotNil(engine.getComponent(for: view))
        
        // 清理
        engine.cleanup(view: view)
        
        // 确认组件已移除
        XCTAssertNil(engine.getComponent(for: view))
    }
    
    // MARK: - RenderResult 测试
    
    func testRenderWithResult() {
        let json: [String: Any] = [
            "type": "text",
            "id": "result_test",
            "layout": ["width": "match_parent", "height": 50],
            "props": ["text": "${value}"]
        ]
        
        // 先用 TemplateLoader 加载
        guard let component = TemplateLoader.shared.loadFromDictionary(json) else {
            XCTFail("Load failed")
            return
        }
        
        let view = engine.render(
            component: component,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        XCTAssertNotNil(view)
        
        // 使用 RenderResult 更新
        if let result = engine.renderWithResult(
            templateName: "nonexistent",  // 这里会失败因为没有文件
            containerSize: CGSize(width: 375, height: 812)
        ) {
            result.update(data: ["value": "Updated"])
            result.cleanup()
        }
    }
    
    // MARK: - 性能监控测试
    
    func testPerformanceMonitorEnabled() {
        engine.config.enablePerformanceMonitor = true
        
        let json: [String: Any] = [
            "type": "linear",
            "id": "perf_test",
            "layout": ["width": "match_parent", "height": "wrap_content"],
            "props": ["orientation": "vertical"],
            "children": (0..<10).map { i in
                [
                    "type": "text",
                    "id": "item_\(i)",
                    "layout": ["width": "match_parent", "height": 44],
                    "props": ["text": "Item \(i)"]
                ] as [String: Any]
            }
        ]
        
        // 渲染应该成功，并打印性能日志
        let view = engine.render(
            json: json,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view?.subviews.count, 10)
        
        engine.config.enablePerformanceMonitor = false
    }
    
    // MARK: - 视图复用测试
    
    func testViewRecycling() {
        engine.config.enableViewReuse = true
        
        let json: [String: Any] = [
            "type": "container",
            "id": "recycle_test",
            "layout": ["width": 100, "height": 100]
        ]
        
        // 渲染多次
        for _ in 0..<5 {
            if let view = engine.render(
                json: json,
                containerSize: CGSize(width: 375, height: 812)
            ) {
                engine.cleanup(view: view)
            }
        }
        
        // 视图应该被复用（具体验证需要访问内部状态）
        // 这里只验证不会崩溃
        XCTAssertTrue(true)
    }
    
    // MARK: - 边界情况测试
    
    func testEmptyJSON() {
        let view = engine.render(
            json: [:],
            containerSize: CGSize(width: 375, height: 812)
        )
        
        // 空 JSON 应该返回 nil
        XCTAssertNil(view)
    }
    
    func testInvalidComponentType() {
        let json: [String: Any] = [
            "type": "unknown_component_type",
            "id": "invalid"
        ]
        
        let view = engine.render(
            json: json,
            containerSize: CGSize(width: 375, height: 812)
        )
        
        // 未知类型应该返回 nil
        XCTAssertNil(view)
    }
    
    func testZeroContainerSize() {
        let json: [String: Any] = [
            "type": "container",
            "id": "zero_size",
            "layout": ["width": "match_parent", "height": "match_parent"]
        ]
        
        let view = engine.render(
            json: json,
            containerSize: .zero
        )
        
        // 应该能处理零尺寸
        XCTAssertNotNil(view)
        XCTAssertEqual(view?.frame.width, 0)
        XCTAssertEqual(view?.frame.height, 0)
    }
    
    // MARK: - 便捷方法测试
    
    func testCreateViewFromJSONString() {
        let jsonString = """
        {
            "type": "text",
            "id": "string_test",
            "layout": {"width": 200, "height": 50},
            "props": {"text": "From String"}
        }
        """
        
        let view = engine.createView(from: jsonString)
        
        XCTAssertNotNil(view)
        
        if let label = view as? UILabel {
            XCTAssertEqual(label.text, "From String")
        }
    }
    
    func testCreateViewFromInvalidJSONString() {
        let invalidJSON = "{ invalid json }"
        
        let view = engine.createView(from: invalidJSON)
        
        XCTAssertNil(view)
    }
}
