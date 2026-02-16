import UIKit
import TemplateX

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
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
        
        return true
    }
}
