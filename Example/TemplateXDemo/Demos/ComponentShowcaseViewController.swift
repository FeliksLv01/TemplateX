import UIKit
import TemplateX

/// 组件展示
class ComponentShowcaseViewController: UIViewController {
    
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    private var hasRendered = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "组件展示"
        view.backgroundColor = .systemGroupedBackground
        
        setupScrollView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 只渲染一次，且在 title 显示后异步执行
        guard !hasRendered else { return }
        hasRendered = true
        
        DispatchQueue.main.async { [weak self] in
            self?.addComponentDemos()
        }
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
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
    
    private func addComponentDemos() {
        // 1. Text 组件
        addSection(title: "Text 文本组件")
        addDemo(
            template: [
                "type": "flex",
                "id": "text_demo",
                "style": ["width": "100%", "height": "auto", "flexDirection": "column", "padding": 16, "backgroundColor": "#FFFFFF", "cornerRadius": 8],
                "children": [
                    [
                        "type": "text",
                        "id": "text1",
                        "style": [
                            "width": "100%",
                            "height": "auto",
                            "fontSize": 14,
                            "textColor": "#333333"
                        ],
                        "props": [
                            "text": "普通文本"
                        ]
                    ],
                    [
                        "type": "text",
                        "id": "text2",
                        "style": [
                            "width": "100%",
                            "height": "auto",
                            "marginTop": 8,
                            "fontSize": 16,
                            "fontWeight": "bold",
                            "textColor": "#333333"
                        ],
                        "props": [
                            "text": "粗体文本"
                        ]
                    ],
                    [
                        "type": "text",
                        "id": "text3",
                        "style": [
                            "width": "100%",
                            "height": "auto",
                            "marginTop": 8,
                            "fontSize": 18,
                            "fontWeight": "bold",
                            "textColor": "#007AFF"
                        ],
                        "props": [
                            "text": "彩色文本"
                        ]
                    ],
                    [
                        "type": "text",
                        "id": "text4",
                        "style": [
                            "width": "100%",
                            "height": "auto",
                            "marginTop": 8,
                            "fontSize": 14,
                            "textColor": "#666666",
                            "textAlign": "center"
                        ],
                        "props": [
                            "text": "居中对齐的多行文本，这是一段较长的文字用于展示多行效果。",
                            "maxLines": 2
                        ]
                    ]
                ]
            ],
            height: 160
        )
        
        // 2. Button 组件
        addSection(title: "Button 按钮组件")
        addDemo(
            template: [
                "type": "flex",
                "id": "button_demo",
                "style": ["width": "100%", "height": "auto", "flexDirection": "column", "padding": 16, "backgroundColor": "#FFFFFF", "cornerRadius": 8],
                "children": [
                    [
                        "type": "button",
                        "id": "btn1",
                        "style": [
                            "width": "100%",
                            "height": 44,
                            "backgroundColor": "#007AFF",
                            "cornerRadius": 8,
                            "textColor": "#FFFFFF"
                        ],
                        "props": [
                            "title": "主要按钮"
                        ]
                    ],
                    [
                        "type": "button",
                        "id": "btn2",
                        "style": [
                            "width": "100%",
                            "height": 44,
                            "marginTop": 8,
                            "backgroundColor": "#E3F2FD",
                            "cornerRadius": 8,
                            "textColor": "#007AFF"
                        ],
                        "props": [
                            "title": "次要按钮"
                        ]
                    ],
                    [
                        "type": "button",
                        "id": "btn3",
                        "style": [
                            "width": "100%",
                            "height": 44,
                            "marginTop": 8,
                            "backgroundColor": "#F44336",
                            "cornerRadius": 8,
                            "textColor": "#FFFFFF"
                        ],
                        "props": [
                            "title": "危险操作"
                        ]
                    ]
                ]
            ],
            height: 180
        )
        
        // 3. Input 组件
        addSection(title: "Input 输入框组件")
        addDemo(
            template: [
                "type": "flex",
                "id": "input_demo",
                "style": ["width": "100%", "height": "auto", "flexDirection": "column", "padding": 16, "backgroundColor": "#FFFFFF", "cornerRadius": 8],
                "children": [
                    [
                        "type": "input",
                        "id": "input1",
                        "style": [
                            "width": "100%",
                            "height": 44,
                            "backgroundColor": "#F5F5F5",
                            "cornerRadius": 8,
                            "paddingHorizontal": 12
                        ],
                        "props": [
                            "placeholder": "请输入用户名"
                        ]
                    ],
                    [
                        "type": "input",
                        "id": "input2",
                        "style": [
                            "width": "100%",
                            "height": 44,
                            "marginTop": 8,
                            "backgroundColor": "#F5F5F5",
                            "cornerRadius": 8,
                            "paddingHorizontal": 12
                        ],
                        "props": [
                            "placeholder": "请输入邮箱",
                            "keyboardType": "email"
                        ]
                    ],
                    [
                        "type": "input",
                        "id": "input3",
                        "style": [
                            "width": "100%",
                            "height": 44,
                            "marginTop": 8,
                            "backgroundColor": "#F5F5F5",
                            "cornerRadius": 8,
                            "paddingHorizontal": 12
                        ],
                        "props": [
                            "placeholder": "请输入密码",
                            "secureTextEntry": true
                        ]
                    ]
                ]
            ],
            height: 180
        )
        
        // 4. Image 组件
        addSection(title: "Image 图片组件")
        addDemo(
            template: [
                "type": "flex",
                "id": "image_demo",
                "style": ["width": "100%", "height": "auto", "flexDirection": "row", "padding": 16, "backgroundColor": "#FFFFFF", "cornerRadius": 8],
                "children": [
                    [
                        "type": "view",
                        "id": "img_placeholder1",
                        "style": [
                            "width": 80,
                            "height": 80,
                            "backgroundColor": "#E0E0E0",
                            "cornerRadius": 8
                        ]
                    ],
                    [
                        "type": "view",
                        "id": "img_placeholder2",
                        "style": [
                            "width": 80,
                            "height": 80,
                            "marginLeft": 8,
                            "backgroundColor": "#BDBDBD",
                            "cornerRadius": 40
                        ]
                    ],
                    [
                        "type": "view",
                        "id": "img_placeholder3",
                        "style": [
                            "width": 80,
                            "height": 80,
                            "marginLeft": 8,
                            "backgroundColor": "#9E9E9E",
                            "cornerRadius": 16
                        ]
                    ]
                ]
            ],
            height: 112
        )
        
        // 5. 样式属性
        addSection(title: "Style 样式属性")
        addDemo(
            template: [
                "type": "flex",
                "id": "style_demo",
                "style": ["width": "100%", "height": "auto", "flexDirection": "row", "flexWrap": "wrap", "padding": 16, "backgroundColor": "#FFFFFF", "cornerRadius": 8],
                "children": [
                    // 渐变背景
                    [
                        "type": "view",
                        "id": "gradient_box",
                        "style": [
                            "width": 80,
                            "height": 80,
                            "margin": 4,
                            "backgroundGradient": [
                                "colors": ["#667EEA", "#764BA2"],
                                "direction": "topToBottom"
                            ],
                            "cornerRadius": 8
                        ]
                    ],
                    // 边框
                    [
                        "type": "view",
                        "id": "border_box",
                        "style": [
                            "width": 80,
                            "height": 80,
                            "margin": 4,
                            "backgroundColor": "#FFFFFF",
                            "borderWidth": 2,
                            "borderColor": "#007AFF",
                            "cornerRadius": 8
                        ]
                    ],
                    // 阴影
                    [
                        "type": "view",
                        "id": "shadow_box",
                        "style": [
                            "width": 80,
                            "height": 80,
                            "margin": 4,
                            "backgroundColor": "#FFFFFF",
                            "cornerRadius": 8,
                            "shadowColor": "#000000",
                            "shadowOffset": [0, 4],
                            "shadowRadius": 8,
                            "shadowOpacity": 0.2
                        ]
                    ],
                    // 透明度
                    [
                        "type": "view",
                        "id": "opacity_box",
                        "style": [
                            "width": 80,
                            "height": 80,
                            "margin": 4,
                            "backgroundColor": "#FF5722",
                            "cornerRadius": 8,
                            "opacity": 0.5
                        ]
                    ]
                ]
            ],
            height: 210
        )
        
        // 6. List 列表组件
        addSection(title: "List 列表组件")
        addListDemo()
    }
    
    private func addSection(title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        stackView.addArrangedSubview(label)
    }
    
    private func addDemo(template: [String: Any], height: CGFloat) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: height).isActive = true
        stackView.addArrangedSubview(container)
        
        let containerWidth = UIScreen.main.bounds.width - 32
        if let view = RenderEngine.shared.render(
            json: template,
            containerSize: CGSize(width: containerWidth, height: height)
        ) {
            container.addSubview(view)
        }
    }
    
    private func addListDemo() {
        let items = [
            ["id": "1", "title": "Apple", "subtitle": "iPhone 15 Pro", "price": "¥8999"],
            ["id": "2", "title": "Samsung", "subtitle": "Galaxy S24 Ultra", "price": "¥9999"],
            ["id": "3", "title": "Xiaomi", "subtitle": "Xiaomi 14 Pro", "price": "¥4999"],
            ["id": "4", "title": "Huawei", "subtitle": "Mate 60 Pro", "price": "¥6999"],
            ["id": "5", "title": "OPPO", "subtitle": "Find X7 Pro", "price": "¥5999"]
        ]
        
        let template: [String: Any] = [
            "type": "list",
            "id": "product_list",
            "style": [
                "width": "100%",
                "height": "auto",
                "backgroundColor": "#FFFFFF",
                "cornerRadius": 8
            ],
            "props": [
                "itemTemplate": [
                    "type": "flex",
                    "id": "list_item",
                    "style": [
                        "width": "100%",
                        "height": "auto",
                        "flexDirection": "row",
                        "alignItems": "center",
                        "padding": 16,
                        "borderBottomWidth": 1,
                        "borderBottomColor": "#EEEEEE"
                    ],
                    "children": [
                        // 左侧图标
                        [
                            "type": "view",
                            "id": "icon",
                            "style": [
                                "width": 40,
                                "height": 40,
                                "backgroundColor": "#007AFF",
                                "cornerRadius": 20
                            ]
                        ],
                        // 中间信息
                        [
                            "type": "flex",
                            "id": "info",
                            "style": [
                                "flexGrow": 1,
                                "flexDirection": "column",
                                "marginLeft": 12
                            ],
                            "children": [
                                [
                                    "type": "text",
                                    "id": "title",
                                    "style": [
                                        "width": "100%",
                                        "height": "auto",
                                        "fontSize": 16,
                                        "fontWeight": "bold",
                                        "textColor": "#333333"
                                    ],
                                    "props": [
                                        "text": "${item.title}"
                                    ]
                                ],
                                [
                                    "type": "text",
                                    "id": "subtitle",
                                    "style": [
                                        "width": "100%",
                                        "height": "auto",
                                        "marginTop": 4,
                                        "fontSize": 12,
                                        "textColor": "#999999"
                                    ],
                                    "props": [
                                        "text": "${item.subtitle}"
                                    ]
                                ]
                            ]
                        ],
                        // 右侧价格
                        [
                            "type": "text",
                            "id": "price",
                            "style": [
                                "width": "auto",
                                "height": "auto",
                                "fontSize": 16,
                                "fontWeight": "bold",
                                "textColor": "#FF5722"
                            ],
                            "props": [
                                "text": "${item.price}"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        let data: [String: Any] = [
            "items": items
        ]
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        // 移除固定高度约束，让内容自适应
        stackView.addArrangedSubview(container)
        
        let containerWidth = UIScreen.main.bounds.width - 32
        if let view = RenderEngine.shared.render(
            json: template,
            data: data,
            containerSize: CGSize(width: containerWidth, height: .nan)
        ) {
            container.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
    }
}
