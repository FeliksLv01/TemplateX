import UIKit
import TemplateX

/// 基础渲染演示
class BasicRenderDemoViewController: UIViewController {
    
    private var templateView: TemplateXView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupTemplateView()
        renderTemplate()
    }
    
    private func setupTemplateView() {
        // 使用 Builder 模式创建 TemplateXView
        templateView = TemplateXView { builder in
            builder.config = TemplateXConfig { config in
                config.enablePerformanceMonitor = true
                config.enableSyncFlush = true
            }
            builder.screenSize = UIScreen.main.bounds.size
            builder.fontScale = 1.0
        }
        
        // 设置布局模式
        templateView.preferredLayoutWidth = UIScreen.main.bounds.width - 32
        templateView.preferredLayoutHeight = 200
        templateView.layoutWidthMode = .exact
        templateView.layoutHeightMode = .exact
        
        templateView.translatesAutoresizingMaskIntoConstraints = false
        templateView.backgroundColor = .systemBackground
        templateView.layer.cornerRadius = 12
        templateView.layer.shadowColor = UIColor.black.cgColor
        templateView.layer.shadowOffset = CGSize(width: 0, height: 2)
        templateView.layer.shadowRadius = 8
        templateView.layer.shadowOpacity = 0.1
        
        view.addSubview(templateView)
        
        NSLayoutConstraint.activate([
            templateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            templateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            templateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            templateView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func renderTemplate() {
        // 定义模板 JSON - 统一 style 格式
        let template: [String: Any] = [
            "type": "flex",
            "id": "card",
            "style": [
                "width": "100%",
                "height": "100%",
                "flexDirection": "column",
                "padding": 16,
                "backgroundColor": "#FFFFFF",
                "cornerRadius": 12
            ],
            "children": [
                [
                    "type": "text",
                    "id": "title",
                    "style": [
                        "width": "100%",
                        "height": "auto",
                        "fontSize": 24,
                        "fontWeight": "bold",
                        "textColor": "#333333"
                    ],
                    "props": [
                        "text": "Hello TemplateX!"
                    ]
                ],
                [
                    "type": "text",
                    "id": "subtitle",
                    "style": [
                        "width": "100%",
                        "height": "auto",
                        "marginTop": 8,
                        "fontSize": 14,
                        "textColor": "#666666"
                    ],
                    "props": [
                        "text": "高性能 iOS DSL 动态渲染框架"
                    ]
                ],
                [
                    "type": "view",
                    "id": "spacer",
                    "style": [
                        "flexGrow": 1
                    ]
                ],
                [
                    "type": "button",
                    "id": "action_btn",
                    "style": [
                        "width": "100%",
                        "height": 44,
                        "backgroundColor": "#007AFF",
                        "cornerRadius": 8,
                        "textColor": "#FFFFFF"
                    ],
                    "props": [
                        "title": "了解更多"
                    ]
                ]
            ]
        ]
        
        // 使用 TemplateXView 加载模板
        templateView.loadTemplate(json: template)
    }
}
