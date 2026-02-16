import UIKit
import TemplateX

/// 布局系统演示
class LayoutDemoViewController: UIViewController {
    
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    
    // 所有 Demo 模板
    private var demoTemplates: [(title: String, template: [String: Any], height: CGFloat)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "布局系统"
        view.backgroundColor = .systemGroupedBackground
        
        setupScrollView()
        prepareDemoTemplates()
        
        // 使用批量并发渲染
        let renderStart = CACurrentMediaTime()
        addLayoutDemosBatch()
        let renderTime = (CACurrentMediaTime() - renderStart) * 1000
        TXLogger.trace("LayoutDemoViewController.viewDidLoad: render=\(String(format: "%.2f", renderTime))ms")
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    /// 准备所有 Demo 模板数据
    private func prepareDemoTemplates() {
        // 1. Flexbox Row
        demoTemplates.append((
            title: "Flexbox Row (水平布局)",
            template: [
                "type": "flex",
                "id": "row_demo",
                "style": ["width": "100%", "height": 60, "flexDirection": "row", "backgroundColor": "#E3F2FD"],
                "children": [
                    makeBox(id: "box1", color: "#2196F3", flex: 1),
                    makeBox(id: "box2", color: "#1976D2", flex: 2),
                    makeBox(id: "box3", color: "#0D47A1", flex: 1)
                ]
            ],
            height: 60
        ))
        
        // 2. Flexbox Column
        demoTemplates.append((
            title: "Flexbox Column (垂直布局)",
            template: [
                "type": "flex",
                "id": "column_demo",
                "style": ["width": "100%", "height": 150, "flexDirection": "column", "backgroundColor": "#E8F5E9"],
                "children": [
                    makeBox(id: "vbox1", color: "#4CAF50", flex: 1),
                    makeBox(id: "vbox2", color: "#388E3C", flex: 1),
                    makeBox(id: "vbox3", color: "#1B5E20", flex: 1)
                ]
            ],
            height: 150
        ))
        
        // 3. Margin & Padding
        demoTemplates.append((
            title: "Margin & Padding",
            template: [
                "type": "view",
                "id": "margin_demo",
                "style": [
                    "width": "100%",
                    "height": 100,
                    "padding": 16,
                    "backgroundColor": "#FFF3E0"
                ],
                "children": [
                    [
                        "type": "view",
                        "id": "inner_box",
                        "style": [
                            "flexGrow": 1,
                            "backgroundColor": "#FF9800",
                            "cornerRadius": 8
                        ]
                    ]
                ]
            ],
            height: 100
        ))
        
        // 4. Align Items
        demoTemplates.append((
            title: "Align Items (对齐)",
            template: [
                "type": "flex",
                "id": "align_demo",
                "style": [
                    "width": "100%",
                    "height": 80,
                    "flexDirection": "row",
                    "justifyContent": "space-around",
                    "alignItems": "center",
                    "backgroundColor": "#F3E5F5"
                ],
                "children": [
                    makeSmallBox(id: "a1", color: "#9C27B0"),
                    makeSmallBox(id: "a2", color: "#7B1FA2"),
                    makeSmallBox(id: "a3", color: "#6A1B9A"),
                    makeSmallBox(id: "a4", color: "#4A148C"),
                    makeSmallBox(id: "a5", color: "#9C27B0"),
                    makeSmallBox(id: "a6", color: "#7B1FA2"),
                    makeSmallBox(id: "a7", color: "#6A1B9A"),
                    makeSmallBox(id: "a8", color: "#4A148C"),
                    makeSmallBox(id: "a9", color: "#9C27B0")
                ]
            ],
            height: 80
        ))
        
        // 5. Flex Wrap
        demoTemplates.append((
            title: "Flex Wrap (换行)",
            template: [
                "type": "flex",
                "id": "wrap_demo",
                "style": [
                    "width": "100%",
                    "height": 100,
                    "flexDirection": "row",
                    "flexWrap": "wrap",
                    "justifyContent": "flex-start",
                    "alignContent": "flex-start",
                    "backgroundColor": "#FFEBEE"
                ],
                "children": [
                    makeSmallBox(id: "w1", color: "#F44336"),
                    makeSmallBox(id: "w2", color: "#E53935"),
                    makeSmallBox(id: "w3", color: "#D32F2F"),
                    makeSmallBox(id: "w4", color: "#C62828"),
                    makeSmallBox(id: "w5", color: "#B71C1C"),
                    makeSmallBox(id: "w6", color: "#F44336"),
                    makeSmallBox(id: "w7", color: "#E53935"),
                    makeSmallBox(id: "w8", color: "#D32F2F")
                ]
            ],
            height: 100
        ))
        
        // 6. Aspect Ratio
        demoTemplates.append((
            title: "Aspect Ratio (宽高比)",
            template: [
                "type": "flex",
                "id": "aspect_demo",
                "style": [
                    "width": "100%",
                    "height": 100,
                    "flexDirection": "row",
                    "justifyContent": "space-around",
                    "alignItems": "center",
                    "backgroundColor": "#E0F7FA"
                ],
                "children": [
                    [
                        "type": "view",
                        "id": "ar1",
                        "style": ["width": 80, "aspectRatio": 1.0, "backgroundColor": "#00BCD4", "cornerRadius": 8]
                    ],
                    [
                        "type": "view",
                        "id": "ar2",
                        "style": ["width": 80, "aspectRatio": 1.5, "backgroundColor": "#00ACC1", "cornerRadius": 8]
                    ],
                    [
                        "type": "view",
                        "id": "ar3",
                        "style": ["width": 80, "aspectRatio": 0.75, "backgroundColor": "#0097A7", "cornerRadius": 8]
                    ]
                ]
            ],
            height: 100
        ))
    }
    
    /// 使用批量并发渲染所有 Demo
    private func addLayoutDemosBatch() {
        let containerWidth = UIScreen.main.bounds.width - 32
        
        // 1. 构建批量渲染任务
        let tasks = demoTemplates.map { demo in
            BatchRenderTask(
                id: demo.template["id"] as? String ?? UUID().uuidString,
                json: demo.template,
                data: nil,
                containerSize: CGSize(width: containerWidth, height: demo.height)
            )
        }
        
        // 2. 批量并发渲染（同步版本，适合 viewDidLoad）
        let results = RenderEngine.shared.renderBatchSync(tasks)
        
        // 3. 添加到 UI（串行）
        let uiStart = CACurrentMediaTime()
        for (index, result) in results.enumerated() {
            let demo = demoTemplates[index]
            
            // 标题
            let titleLabel = UILabel()
            titleLabel.text = demo.title
            titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = .secondaryLabel
            stackView.addArrangedSubview(titleLabel)
            
            // 容器
            let container = UIView()
            container.backgroundColor = .systemBackground
            container.layer.cornerRadius = 8
            container.translatesAutoresizingMaskIntoConstraints = false
            container.heightAnchor.constraint(equalToConstant: demo.height).isActive = true
            stackView.addArrangedSubview(container)
            
            // 添加渲染好的视图
            if let view = result.view {
                container.addSubview(view)
            }
        }
        let uiTime = (CACurrentMediaTime() - uiStart) * 1000
        TXLogger.trace("addLayoutDemosBatch: UI setup=\(String(format: "%.2f", uiTime))ms")
    }
    
    private func makeBox(id: String, color: String, flex: Int) -> [String: Any] {
        return [
            "type": "view",
            "id": id,
            "style": [
                "flexGrow": flex,
                "alignSelf": "stretch",
                "margin": 4,
                "backgroundColor": color,
                "cornerRadius": 4
            ]
        ]
    }
    
    private func makeSmallBox(id: String, color: String) -> [String: Any] {
        return [
            "type": "view",
            "id": id,
            "style": [
                "width": 30,
                "height": 30,
                "margin": 4,
                "backgroundColor": color,
                "cornerRadius": 4
            ]
        ]
    }
}
