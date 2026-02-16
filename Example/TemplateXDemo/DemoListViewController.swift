import UIKit
import TemplateX

/// 示例列表页
class DemoListViewController: UITableViewController {
    
    private let demos: [(title: String, description: String, action: () -> UIViewController)] = [
        (
            "基础渲染",
            "演示基本的 JSON → 视图渲染流程",
            { BasicRenderDemoViewController() }
        ),
        (
            "数据绑定",
            "演示 ${expression} 数据绑定和表达式求值",
            { DataBindingDemoViewController() }
        ),
        (
            "增量更新",
            "演示 Diff + Patch 增量更新机制",
            { IncrementalUpdateDemoViewController() }
        ),
        (
            "布局系统",
            "演示 Yoga Flexbox 布局能力",
            { LayoutDemoViewController() }
        ),
        (
            "组件展示",
            "展示所有内置组件",
            { ComponentShowcaseViewController() }
        ),
        (
            "性能测试",
            "渲染性能基准测试",
            { PerformanceDemoViewController() }
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "TemplateX Demo"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        // 配置引擎
        RenderEngine.shared.config.enablePerformanceMonitor = true
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return demos.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let demo = demos[indexPath.row]
        
        var config = cell.defaultContentConfiguration()
        config.text = demo.title
        config.secondaryText = demo.description
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let demo = demos[indexPath.row]
        let viewController = demo.action()
        viewController.title = demo.title
        navigationController?.pushViewController(viewController, animated: true)
    }
}
