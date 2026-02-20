import UIKit
import TemplateX

/// 组件展示
class ComponentShowcaseViewController: UIViewController {
    
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    
    // MARK: - Demo 配置
    
    private struct DemoConfig {
        let title: String
        let jsonFileName: String
        let height: CGFloat
        let data: [String: Any]?
        
        init(title: String, jsonFileName: String, height: CGFloat, data: [String: Any]? = nil) {
            self.title = title
            self.jsonFileName = jsonFileName
            self.height = height
            self.data = data
        }
    }
    
    private lazy var demos: [DemoConfig] = [
        DemoConfig(title: "Text 文本组件", jsonFileName: "text_demo", height: 180),
        DemoConfig(title: "Button 按钮组件", jsonFileName: "button_demo", height: 180),
        DemoConfig(title: "Input 输入框组件", jsonFileName: "input_demo", height: 180),
        DemoConfig(title: "Image 图片组件", jsonFileName: "image_demo", height: 130),
        DemoConfig(title: "Scroll 滚动组件", jsonFileName: "scroll_demo", height: 120),
        DemoConfig(title: "Input 多行文本", jsonFileName: "multiline_input_demo", height: 132),
        DemoConfig(title: "Style 样式属性", jsonFileName: "style_demo", height: 210),
        DemoConfig(
            title: "List 列表组件",
            jsonFileName: "list_demo",
            height: 360,
            data: [
                "items": [
                    ["id": "1", "title": "Apple", "subtitle": "iPhone 15 Pro", "price": "¥8999"],
                    ["id": "2", "title": "Samsung", "subtitle": "Galaxy S24 Ultra", "price": "¥9999"],
                    ["id": "3", "title": "Xiaomi", "subtitle": "Xiaomi 14 Pro", "price": "¥4999"],
                    ["id": "4", "title": "Huawei", "subtitle": "Mate 60 Pro", "price": "¥6999"],
                    ["id": "5", "title": "OPPO", "subtitle": "Find X7 Pro", "price": "¥5999"]
                ]
            ]
        )
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupScrollView()
        addComponentDemos()
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(scrollView)
        
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // ScrollView 约束到 view 边缘，让系统自动处理 safeArea
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: 16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }
    
    private func addComponentDemos() {
        let containerWidth = UIScreen.main.bounds.width - 32
        
        for demo in demos {
            addSection(title: demo.title)
            
            guard let template = loadJSONTemplate(named: demo.jsonFileName) else {
                addErrorPlaceholder(message: "无法加载 \(demo.jsonFileName).json")
                continue
            }
            
            addDemo(
                template: template,
                height: demo.height,
                containerWidth: containerWidth,
                data: demo.data
            )
        }
    }
    
    // MARK: - JSON Loading
    
    private func loadJSONTemplate(named fileName: String) -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("[ComponentShowcase] JSON file not found: \(fileName).json")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("[ComponentShowcase] Failed to parse JSON: \(fileName).json, error: \(error)")
            return nil
        }
    }
    
    // MARK: - UI Helpers
    
    private func addSection(title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        stackView.addArrangedSubview(label)
    }
    
    private func addDemo(template: [String: Any], height: CGFloat, containerWidth: CGFloat, data: [String: Any]? = nil) {
        // 使用 Builder 模式创建 TemplateXView
        let templateView = TemplateXView { builder in
            builder.config = TemplateXConfig { config in
                config.enablePerformanceMonitor = true
                config.enableSyncFlush = true
            }
            builder.screenSize = UIScreen.main.bounds.size
        }
        
        // 设置布局模式
        templateView.preferredLayoutWidth = containerWidth
        templateView.preferredLayoutHeight = height
        templateView.layoutWidthMode = .exact
        templateView.layoutHeightMode = .exact
        
        templateView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(templateView)
        
        templateView.heightAnchor.constraint(equalToConstant: height).isActive = true
        
        // 加载模板
        if let data = data {
            templateView.loadTemplate(json: template, data: data)
        } else {
            templateView.loadTemplate(json: template)
        }
    }
    
    private func addErrorPlaceholder(message: String) {
        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemRed
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(label)
        label.heightAnchor.constraint(equalToConstant: 60).isActive = true
    }
}
