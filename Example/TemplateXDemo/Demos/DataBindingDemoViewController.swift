import UIKit
import TemplateX

/// 数据绑定演示
class DataBindingDemoViewController: UIViewController {
    
    private var templateView: TemplateXView!
    
    private var userData: [String: Any] = [
        "user": [
            "name": "Alice",
            "age": 28,
            "avatar": "https://example.com/avatar.png",
            "isVip": true
        ],
        "stats": [
            "followers": 1234,
            "following": 567,
            "posts": 89
        ]
    ]
    
    // 用户信息卡片模板 - 统一 style 格式
    private let template: [String: Any] = [
        "type": "flex",
        "id": "user_card",
        "style": [
            "width": "100%",
            "height": "100%",
            "flexDirection": "column",
            "padding": 16,
            "backgroundColor": "#FFFFFF"
        ],
        "children": [
            // 用户名 + VIP 标识
            [
                "type": "flex",
                "id": "header",
                "style": ["width": "100%", "height": "auto", "flexDirection": "row", "alignItems": "center"],
                "children": [
                    [
                        "type": "text",
                        "id": "name",
                        "style": [
                            "width": "auto",
                            "height": "auto",
                            "fontSize": 20,
                            "fontWeight": "bold",
                            "textColor": "#333333"
                        ],
                        "props": [
                            "text": "${user.name}"
                        ]
                    ],
                    [
                        "type": "text",
                        "id": "vip_badge",
                        "style": [
                            "width": "auto",
                            "height": "auto",
                            "marginLeft": 8,
                            "backgroundColor": "#FFD700",
                            "cornerRadius": 4,
                            "paddingHorizontal": 6,
                            "paddingVertical": 2,
                            "fontSize": 12,
                            "textColor": "#FFFFFF"
                        ],
                        "props": [
                            "text": "VIP"
                        ],
                        "bindings": [
                            "display": "${user.isVip}"
                        ]
                    ]
                ]
            ],
            // 年龄信息
            [
                "type": "text",
                "id": "age_info",
                "style": [
                    "width": "100%",
                    "height": "auto",
                    "marginTop": 8,
                    "fontSize": 14,
                    "textColor": "#666666"
                ],
                "props": [
                    "text": "${'年龄: ' + user.age + ' 岁'}"
                ]
            ],
            // 统计数据
            [
                "type": "flex",
                "id": "stats_row",
                "style": ["width": "100%", "height": "auto", "flexDirection": "row", "marginTop": 16],
                "children": [
                    [
                        "type": "flex",
                        "id": "followers_stat",
                        "style": ["flexGrow": 1, "flexDirection": "column", "alignItems": "center"],
                        "children": [
                            [
                                "type": "text",
                                "id": "followers_count",
                                "style": [
                                    "width": "auto",
                                    "height": "auto",
                                    "fontSize": 18,
                                    "fontWeight": "bold",
                                    "textColor": "#333333"
                                ],
                                "props": [
                                    "text": "${stats.followers}"
                                ]
                            ],
                            [
                                "type": "text",
                                "id": "followers_label",
                                "style": [
                                    "width": "auto",
                                    "height": "auto",
                                    "marginTop": 4,
                                    "fontSize": 12,
                                    "textColor": "#999999"
                                ],
                                "props": [
                                    "text": "粉丝"
                                ]
                            ]
                        ]
                    ],
                    [
                        "type": "flex",
                        "id": "following_stat",
                        "style": ["flexGrow": 1, "flexDirection": "column", "alignItems": "center"],
                        "children": [
                            [
                                "type": "text",
                                "id": "following_count",
                                "style": [
                                    "width": "auto",
                                    "height": "auto",
                                    "fontSize": 18,
                                    "fontWeight": "bold",
                                    "textColor": "#333333"
                                ],
                                "props": [
                                    "text": "${stats.following}"
                                ]
                            ],
                            [
                                "type": "text",
                                "id": "following_label",
                                "style": [
                                    "width": "auto",
                                    "height": "auto",
                                    "marginTop": 4,
                                    "fontSize": 12,
                                    "textColor": "#999999"
                                ],
                                "props": [
                                    "text": "关注"
                                ]
                            ]
                        ]
                    ],
                    [
                        "type": "flex",
                        "id": "posts_stat",
                        "style": ["flexGrow": 1, "flexDirection": "column", "alignItems": "center"],
                        "children": [
                            [
                                "type": "text",
                                "id": "posts_count",
                                "style": [
                                    "width": "auto",
                                    "height": "auto",
                                    "fontSize": 18,
                                    "fontWeight": "bold",
                                    "textColor": "#333333"
                                ],
                                "props": [
                                    "text": "${stats.posts}"
                                ]
                            ],
                            [
                                "type": "text",
                                "id": "posts_label",
                                "style": [
                                    "width": "auto",
                                    "height": "auto",
                                    "marginTop": 4,
                                    "fontSize": 12,
                                    "textColor": "#999999"
                                ],
                                "props": [
                                    "text": "动态"
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupUI()
        renderTemplate()
    }
    
    private func setupUI() {
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
        templateView.preferredLayoutHeight = 250
        templateView.layoutWidthMode = .exact
        templateView.layoutHeightMode = .exact
        
        templateView.translatesAutoresizingMaskIntoConstraints = false
        templateView.backgroundColor = .systemBackground
        templateView.layer.cornerRadius = 12
        
        view.addSubview(templateView)
        
        // 更新按钮
        let updateButton = UIButton(type: .system)
        updateButton.setTitle("更新数据", for: .normal)
        updateButton.addTarget(self, action: #selector(updateData), for: .touchUpInside)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(updateButton)
        
        NSLayoutConstraint.activate([
            templateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            templateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            templateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            templateView.heightAnchor.constraint(equalToConstant: 250),
            
            updateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            updateButton.topAnchor.constraint(equalTo: templateView.bottomAnchor, constant: 20)
        ])
    }
    
    private func renderTemplate() {
        // 使用 TemplateXView 加载模板
        templateView.loadTemplate(json: template, data: userData)
    }
    
    @objc private func updateData() {
        // 随机更新数据
        userData["user"] = [
            "name": ["Alice", "Bob", "Charlie", "David"].randomElement()!,
            "age": Int.random(in: 18...45),
            "isVip": Bool.random()
        ]
        
        userData["stats"] = [
            "followers": Int.random(in: 100...10000),
            "following": Int.random(in: 50...1000),
            "posts": Int.random(in: 10...500)
        ]
        
        // 使用 TemplateXView 的增量更新方法
        templateView.updateData(userData)
    }
}
