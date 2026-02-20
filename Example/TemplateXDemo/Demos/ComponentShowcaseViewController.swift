import UIKit
import TemplateX

/// 组件展示（使用 UITableView）
class ComponentShowcaseViewController: UITableViewController {
    
    // MARK: - Demo 配置
    
    private struct DemoConfig {
        let title: String
        let jsonFileName: String
        let data: [String: Any]?
        
        init(title: String, jsonFileName: String, data: [String: Any]? = nil) {
            self.title = title
            self.jsonFileName = jsonFileName
            self.data = data
        }
    }
    
    private lazy var demos: [DemoConfig] = [
        DemoConfig(title: "Text 文本组件", jsonFileName: "text_demo"),
        DemoConfig(title: "Button 按钮组件", jsonFileName: "button_demo"),
        DemoConfig(title: "Input 输入框组件", jsonFileName: "input_demo"),
        DemoConfig(title: "Image 图片组件", jsonFileName: "image_demo"),
        DemoConfig(title: "Scroll 滚动组件", jsonFileName: "scroll_demo"),
        DemoConfig(title: "Input 多行文本", jsonFileName: "multiline_input_demo"),
        DemoConfig(title: "Style 样式属性", jsonFileName: "style_demo"),
        DemoConfig(
            title: "List 列表组件",
            jsonFileName: "list_demo",
            data: [
                "items": [
                    ["id": "1", "title": "Apple", "subtitle": "iPhone 15 Pro", "price": "¥8999"],
                    ["id": "2", "title": "Samsung", "subtitle": "Galaxy S24 Ultra", "price": "¥9999"],
                    ["id": "3", "title": "Xiaomi", "subtitle": "Xiaomi 14 Pro", "price": "¥4999"],
                    ["id": "4", "title": "Huawei", "subtitle": "Mate 60 Pro", "price": "¥6999"],
                    ["id": "5", "title": "OPPO", "subtitle": "Find X7 Pro", "price": "¥5999"],
                    ["id": "6", "title": "Vivo", "subtitle": "X100 Pro", "price": "¥4999"],
                    ["id": "7", "title": "OnePlus", "subtitle": "12 Pro", "price": "¥4499"],
                    ["id": "8", "title": "Google", "subtitle": "Pixel 8 Pro", "price": "¥7999"],
                    ["id": "9", "title": "Sony", "subtitle": "Xperia 1 V", "price": "¥8999"],
                    ["id": "10", "title": "Motorola", "subtitle": "Edge 40 Pro", "price": "¥3999"],
                    ["id": "11", "title": "Realme", "subtitle": "GT5 Pro", "price": "¥3299"],
                    ["id": "12", "title": "Honor", "subtitle": "Magic 6 Pro", "price": "¥5499"],
                    ["id": "13", "title": "Asus", "subtitle": "ROG Phone 8", "price": "¥6999"],
                    ["id": "14", "title": "Nubia", "subtitle": "RedMagic 9 Pro", "price": "¥4999"],
                    ["id": "15", "title": "ZTE", "subtitle": "Axon 60 Ultra", "price": "¥3999"],
                    ["id": "16", "title": "Meizu", "subtitle": "21 Pro", "price": "¥4299"],
                    ["id": "17", "title": "Nothing", "subtitle": "Phone 2", "price": "¥3999"],
                    ["id": "18", "title": "Lenovo", "subtitle": "Legion Y90", "price": "¥5999"],
                    ["id": "19", "title": "Xiaomi", "subtitle": "Redmi K70 Pro", "price": "¥2999"],
                    ["id": "20", "title": "iQOO", "subtitle": "12 Pro", "price": "¥4499"]
                ]
            ]
        )
    ]
    
    // 模板缓存
    private var templateCache: [String: [String: Any]] = [:]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.register(TemplateXDemoCell.self, forCellReuseIdentifier: TemplateXDemoCell.reuseIdentifier)
        
        // 预加载模板
        preloadTemplates()
    }
    
    private func preloadTemplates() {
        for demo in demos {
            _ = loadJSONTemplate(named: demo.jsonFileName)
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return demos.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let demo = demos[indexPath.section]
        
        guard let template = loadJSONTemplate(named: demo.jsonFileName) else {
            let cell = UITableViewCell()
            cell.textLabel?.text = "无法加载 \(demo.jsonFileName).json"
            cell.textLabel?.textColor = .systemRed
            cell.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: TemplateXDemoCell.reuseIdentifier,
            for: indexPath
        ) as! TemplateXDemoCell
        
        cell.configure(
            template: template,
            templateId: demo.jsonFileName,
            data: demo.data,
            cellWidth: tableView.bounds.width
        )
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return demos[section].title
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let demo = demos[indexPath.section]
        
        guard let template = loadJSONTemplate(named: demo.jsonFileName) else {
            return 60
        }
        
        return TemplateXDemoCell.calculateHeight(
            template: template,
            templateId: demo.jsonFileName,
            data: demo.data,
            containerWidth: tableView.bounds.width
        )
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
            header.textLabel?.textColor = .label
        }
    }
    
    // MARK: - JSON Loading
    
    private func loadJSONTemplate(named fileName: String) -> [String: Any]? {
        // 检查缓存
        if let cached = templateCache[fileName] {
            return cached
        }
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("[ComponentShowcase] JSON file not found: \(fileName).json")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let template = json as? [String: Any] {
                templateCache[fileName] = template
                return template
            }
            return nil
        } catch {
            print("[ComponentShowcase] Failed to parse JSON: \(fileName).json, error: \(error)")
            return nil
        }
    }
}
