import UIKit
import TemplateX
import TemplateXService

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    private var fpsLabel: FPSLabel?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // 注册 ImageLoader（必须在使用 TemplateX 前注册）
        TemplateX.registerImageLoader(SDWebImageLoader())
        
        // 注册事件处理器
        TemplateX.registerActionHandler(DemoActionHandler())
        
        // 预热 TemplateX 引擎（异步执行，不阻塞启动）
        DispatchQueue.global(qos: .userInitiated).async {
            TemplateX.warmUp()
        }
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .white
        
        let navController = UINavigationController(rootViewController: DemoListViewController())
        navController.navigationBar.prefersLargeTitles = true
        
        window?.rootViewController = navController
        window?.makeKeyAndVisible()
        
        // 显示 FPS 监控（仅 Debug 模式）
        #if DEBUG
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            self?.fpsLabel = FPSLabel.show(in: window)
        }
        #endif
        
        return true
    }
}

// MARK: - Demo ActionHandler

/// Demo 事件处理器：弹 Alert 展示事件信息
final class DemoActionHandler: TemplateXActionHandler {
    
    func handleAction(url: String, params: [String: Any], context: EventContext) {
        let paramsDesc = params.isEmpty ? "无" : params.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        
        let message = "URL: \(url)\n\n参数:\n\(paramsDesc)\n\n组件: \(context.componentId)"
        
        let alert = UIAlertController(
            title: "事件触发",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // 获取当前最上层 VC 来弹窗
        guard let topVC = topViewController() else { return }
        topVC.present(alert, animated: true)
    }
    
    private func topViewController() -> UIViewController? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
              var vc = window.rootViewController else { return nil }
        while let presented = vc.presentedViewController {
            vc = presented
        }
        if let nav = vc as? UINavigationController {
            return nav.visibleViewController ?? nav
        }
        return vc
    }
}
