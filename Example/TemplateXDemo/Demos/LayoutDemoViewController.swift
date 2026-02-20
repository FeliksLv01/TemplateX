import UIKit
import TemplateX

/// 布局系统演示
class LayoutDemoViewController: UIViewController {
    
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    
    // MARK: - Demo 配置
    
    private struct DemoConfig {
        let title: String
        let jsonFileName: String
        let height: CGFloat
    }
    
    private let demos: [DemoConfig] = [
        DemoConfig(title: "Flexbox Row (水平布局)", jsonFileName: "flexbox_row", height: 60),
        DemoConfig(title: "Flexbox Column (垂直布局)", jsonFileName: "flexbox_column", height: 150),
        DemoConfig(title: "Margin & Padding", jsonFileName: "margin_padding", height: 100),
        DemoConfig(title: "Align Items (对齐)", jsonFileName: "align_items", height: 80),
        DemoConfig(title: "Flex Wrap (换行)", jsonFileName: "flex_wrap", height: 100),
        DemoConfig(title: "Aspect Ratio (宽高比)", jsonFileName: "aspect_ratio", height: 100)
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupScrollView()
        addLayoutDemos()
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(scrollView)
        
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
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
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }
    
    private func addLayoutDemos() {
        let containerWidth = UIScreen.main.bounds.width - 32
        
        for demo in demos {
            // 标题
            let titleLabel = UILabel()
            titleLabel.text = demo.title
            titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = .secondaryLabel
            stackView.addArrangedSubview(titleLabel)
            
            // 加载 JSON 模板
            guard let template = loadJSONTemplate(named: demo.jsonFileName) else {
                addErrorPlaceholder(message: "无法加载 \(demo.jsonFileName).json")
                continue
            }
            
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
            templateView.preferredLayoutHeight = demo.height
            templateView.layoutWidthMode = .exact
            templateView.layoutHeightMode = .exact
            
            templateView.translatesAutoresizingMaskIntoConstraints = false
            templateView.backgroundColor = .systemBackground
            templateView.layer.cornerRadius = 8
            
            stackView.addArrangedSubview(templateView)
            
            // 设置高度约束
            templateView.heightAnchor.constraint(equalToConstant: demo.height).isActive = true
            
            // 加载模板
            templateView.loadTemplate(json: template)
        }
    }
    
    // MARK: - JSON Loading
    
    private func loadJSONTemplate(named fileName: String) -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("[LayoutDemo] JSON file not found: \(fileName).json")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("[LayoutDemo] Failed to parse JSON: \(fileName).json, error: \(error)")
            return nil
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
