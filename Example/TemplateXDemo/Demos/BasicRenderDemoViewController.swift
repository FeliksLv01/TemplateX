import UIKit
import TemplateX

/// 基础渲染演示
class BasicRenderDemoViewController: UIViewController {
    
    private var containerView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupContainerView()
        renderTemplate()
    }
    
    private func setupContainerView() {
        containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.1
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            containerView.heightAnchor.constraint(equalToConstant: 200)
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
        
        // 渲染
        let containerSize = CGSize(
            width: UIScreen.main.bounds.width - 32,
            height: 200
        )
        
        if let renderedView = RenderEngine.shared.render(
            json: template,
            containerSize: containerSize
        ) {
            containerView.addSubview(renderedView)
        }
    }
}
