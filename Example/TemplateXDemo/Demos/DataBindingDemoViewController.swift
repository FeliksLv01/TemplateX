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
        guard let template = loadJSONTemplate(named: "user_card") else {
            print("[DataBindingDemo] Failed to load user_card.json")
            return
        }
        
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
    
    // MARK: - JSON Loading
    
    private func loadJSONTemplate(named fileName: String) -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("[DataBindingDemo] JSON file not found: \(fileName).json")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("[DataBindingDemo] Failed to parse JSON: \(fileName).json, error: \(error)")
            return nil
        }
    }
}
