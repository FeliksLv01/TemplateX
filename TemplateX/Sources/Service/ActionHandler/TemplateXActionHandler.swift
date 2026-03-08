import UIKit

// MARK: - TemplateXActionHandler

/// 事件动作处理协议
///
/// 接入方实现此协议以处理模板中的点击/手势事件。
/// 模板中 events 的 url 和 params（表达式已求值）会通过此协议传出。
///
/// 使用示例：
/// ```swift
/// class AppActionHandler: TemplateXActionHandler {
///     func handleAction(url: String, params: [String: Any], context: EventContext) {
///         guard let url = URL(string: url) else { return }
///         switch url.host {
///         case "follow":
///             let userId = params["userId"] as? String ?? ""
///             UserService.follow(userId: userId)
///         default:
///             Router.open(url, params: params)
///         }
///     }
/// }
///
/// // App 启动时注册
/// TemplateX.registerActionHandler(AppActionHandler())
/// ```
public protocol TemplateXActionHandler: AnyObject {
    
    /// 处理 URL 动作
    ///
    /// - Parameters:
    ///   - url: 动作 URL（如 "app://follow"、"https://xxx"），表达式已求值
    ///   - params: 已解析的参数字典，表达式已求值
    ///   - context: 事件上下文（包含 componentId、view、component 等信息）
    func handleAction(url: String, params: [String: Any], context: EventContext)
}
