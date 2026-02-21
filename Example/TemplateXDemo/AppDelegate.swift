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
