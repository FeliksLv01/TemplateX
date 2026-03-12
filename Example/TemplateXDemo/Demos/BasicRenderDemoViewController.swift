import UIKit
import TemplateX

class BasicRenderDemoViewController: UIViewController {
    
    private var templateView: TemplateXView!
    private var viewHierarchyLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupTemplateView()
        setupViewHierarchyLabel()
        renderTemplate()
    }
    
    private func setupTemplateView() {
        templateView = TemplateXView { builder in
            builder.config = TemplateXConfig { config in
                config.enablePerformanceMonitor = true
                config.enableSyncFlush = true
            }
            builder.screenSize = UIScreen.main.bounds.size
            builder.fontScale = 1.0
        }
        
        templateView.preferredLayoutWidth = UIScreen.main.bounds.width - 32
        templateView.preferredLayoutHeight = 260
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
            templateView.heightAnchor.constraint(equalToConstant: 260)
        ])
    }
    
    private func setupViewHierarchyLabel() {
        viewHierarchyLabel = UILabel()
        viewHierarchyLabel.numberOfLines = 0
        viewHierarchyLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        viewHierarchyLabel.textColor = .secondaryLabel
        viewHierarchyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(viewHierarchyLabel)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: templateView.bottomAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            
            viewHierarchyLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
            viewHierarchyLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            viewHierarchyLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            viewHierarchyLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            viewHierarchyLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func renderTemplate() {
        guard let template = loadJSONTemplate(named: "basic_card") else {
            print("[BasicRenderDemo] Failed to load basic_card.json")
            return
        }
        
        let data: [String: Any] = [
            "card": [
                "id": "card_001",
                "title": "Hello TemplateX!",
                "subtitle": "高性能 iOS DSL 动态渲染框架",
                "stat1": "8",
                "stat2": "6",
                "stat3": "42",
                "buttonText": "了解更多"
            ]
        ]
        
        templateView.loadTemplate(json: template, data: data)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.printViewHierarchy()
        }
    }
    
    private func printViewHierarchy() {
        var lines: [String] = []
        lines.append("View Flattening: ON")
        lines.append("")
        
        let totalViews = countViews(templateView)
        lines.append("UIView count: \(totalViews)")
        lines.append("")
        lines.append("View Hierarchy:")
        dumpViewTree(templateView, indent: 0, lines: &lines)
        
        viewHierarchyLabel.text = lines.joined(separator: "\n")
    }
    
    private func countViews(_ view: UIView) -> Int {
        return 1 + view.subviews.reduce(0) { $0 + countViews($1) }
    }
    
    private func dumpViewTree(_ view: UIView, indent: Int, lines: inout [String]) {
        let prefix = String(repeating: "  ", count: indent)
        let typeName = String(describing: type(of: view))
        let id = view.accessibilityIdentifier ?? "-"
        let frame = view.frame
        lines.append("\(prefix)\(typeName) [\(id)] (\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))x\(Int(frame.height)))")
        for sub in view.subviews {
            dumpViewTree(sub, indent: indent + 1, lines: &lines)
        }
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
