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
        guard let template = loadJSONTemplate(named: "basic_card") else {
            print("[BasicRenderDemo] Failed to load basic_card.json")
            return
        }
        
        // 使用 TemplateXView 加载模板
        templateView.loadTemplate(json: template)
    }
    
    // MARK: - JSON Loading
    
    private func loadJSONTemplate(named fileName: String) -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("[BasicRenderDemo] JSON file not found: \(fileName).json")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("[BasicRenderDemo] Failed to parse JSON: \(fileName).json, error: \(error)")
            return nil
        }
    }
}
