import UIKit

// MARK: - 事件类型

/// 支持的事件类型
public enum EventType: String, CaseIterable {
    case tap = "onTap"
    case doubleTap = "onDoubleTap"
    case longPress = "onLongPress"
    case pan = "onPan"
    case swipe = "onSwipe"
    case pinch = "onPinch"
    case rotation = "onRotation"
    
    /// 触摸相关
    case touchDown = "onTouchDown"
    case touchUp = "onTouchUp"
    case touchCancel = "onTouchCancel"
    
    /// 焦点相关
    case focus = "onFocus"
    case blur = "onBlur"
    
    /// 值变化
    case valueChange = "onValueChange"
}

// MARK: - 事件数据

/// 事件上下文数据
public struct EventContext {
    /// 事件类型
    public let type: EventType
    
    /// 触发事件的组件 ID
    public let componentId: String
    
    /// 触发事件的视图
    public weak var view: UIView?
    
    /// 触发事件的组件
    public weak var component: (any Component)?
    
    /// 事件时间戳
    public let timestamp: TimeInterval
    
    /// 触摸位置（相对于视图）
    public var location: CGPoint?
    
    /// 触摸位置（相对于窗口）
    public var globalLocation: CGPoint?
    
    /// 手势状态
    public var gestureState: UIGestureRecognizer.State?
    
    /// 额外数据
    public var extra: [String: Any] = [:]
    
    public init(
        type: EventType,
        componentId: String,
        view: UIView? = nil,
        component: (any Component)? = nil
    ) {
        self.type = type
        self.componentId = componentId
        self.view = view
        self.component = component
        self.timestamp = Date().timeIntervalSince1970
    }
}

// MARK: - 事件处理器

/// 事件处理器协议
public protocol EventHandler: AnyObject {
    /// 处理事件
    /// - Parameters:
    ///   - context: 事件上下文
    /// - Returns: 是否继续冒泡
    func handleEvent(_ context: EventContext) -> Bool
}

/// 事件处理闭包
public typealias EventCallback = (EventContext) -> Bool

// MARK: - 事件动作

/// 事件触发的动作类型
public enum EventAction {
    /// URL 动作（params 中可能包含未求值的表达式模板）
    /// 通过 ServiceRegistry.actionHandler 传递给接入方处理
    case url(String, params: [String: Any]?)
    
    /// 自定义闭包（Swift 原生代码使用）
    case custom(EventCallback)
}

// MARK: - 事件绑定

/// 事件绑定配置
public struct EventBinding {
    /// 事件类型
    public let type: EventType
    
    /// 绑定的动作
    public let action: EventAction
    
    /// 是否阻止冒泡
    public var stopPropagation: Bool = false
    
    /// 是否阻止默认行为
    public var preventDefault: Bool = false
    
    /// 节流时间（毫秒）
    public var throttle: Int = 0
    
    /// 防抖时间（毫秒）
    public var debounce: Int = 0
    
    public init(type: EventType, action: EventAction) {
        self.type = type
        self.action = action
    }
}

// MARK: - 事件管理器

/// 事件管理器
/// 负责事件的注册、分发和处理
/// 注意：此类只在主线程访问（处理 UI 事件），无需加锁
public final class EventManager {
    
    // MARK: - 单例
    
    public static let shared = EventManager()
    
    // MARK: - 配置
    
    public struct Config {
        /// 是否启用事件冒泡
        public var enableBubbling: Bool = true
        
        /// 是否启用事件捕获（从根到目标）
        public var enableCapturing: Bool = false
        
        /// 默认节流时间
        public var defaultThrottle: Int = 0
        
        /// 是否记录事件日志
        public var enableEventLog: Bool = false
        
        public init() {}
    }
    
    public var config = Config()
    
    // MARK: - 存储
    
    /// 组件事件绑定: componentId -> [EventType: [EventBinding]]
    private var eventBindings: [String: [EventType: [EventBinding]]] = [:]
    
    /// 全局事件监听器: EventType -> [handler]
    private var globalListeners: [EventType: [WeakHandler]] = [:]
    
    /// 节流控制: componentId_eventType -> lastFireTime
    private var throttleTimers: [String: TimeInterval] = [:]
    
    /// 防抖控制: componentId_eventType -> workItem
    private var debounceWorkItems: [String: DispatchWorkItem] = [:]
    
    // MARK: - 依赖
    
    private let expressionEngine = ExpressionEngine.shared
    
    private init() {}
    
    // MARK: - 事件绑定
    
    /// 绑定事件到组件
    public func bindEvent(_ binding: EventBinding, to componentId: String) {
        var componentBindings = eventBindings[componentId] ?? [:]
        var typeBindings = componentBindings[binding.type] ?? []
        typeBindings.append(binding)
        componentBindings[binding.type] = typeBindings
        eventBindings[componentId] = componentBindings
    }
    
    /// 从 JSON 配置绑定事件
    ///
    /// 支持两种格式：
    /// 1. 简写 URL 字符串：`"onTap": "app://follow"`
    /// 2. 完整配置：`"onTap": { "url": "app://follow", "params": { ... } }`
    public func bindEvents(from json: [String: Any], to componentId: String) {
        for (key, value) in json {
            guard let eventType = EventType(rawValue: key) else { continue }
            
            let binding: EventBinding
            
            if let urlString = value as? String {
                // 简写：直接传 URL 字符串
                binding = EventBinding(type: eventType, action: .url(urlString, params: nil))
            } else if let config = value as? [String: Any] {
                // 完整配置
                binding = parseEventConfig(type: eventType, config: config)
            } else {
                continue
            }
            
            bindEvent(binding, to: componentId)
        }
    }
    
    /// 解除组件的所有事件绑定
    public func unbindAllEvents(from componentId: String) {
        eventBindings.removeValue(forKey: componentId)
        
        // 清理节流和防抖
        let prefix = "\(componentId)_"
        throttleTimers = throttleTimers.filter { !$0.key.hasPrefix(prefix) }
        
        for (key, workItem) in debounceWorkItems where key.hasPrefix(prefix) {
            workItem.cancel()
            debounceWorkItems.removeValue(forKey: key)
        }
    }
    
    // MARK: - 全局监听
    
    /// 添加全局事件监听器
    public func addGlobalListener(_ type: EventType, handler: EventHandler) {
        var handlers = globalListeners[type] ?? []
        handlers.append(WeakHandler(handler))
        globalListeners[type] = handlers
    }
    
    /// 移除全局事件监听器
    public func removeGlobalListener(_ type: EventType, handler: EventHandler) {
        guard var handlers = globalListeners[type] else { return }
        handlers.removeAll { $0.handler === handler }
        globalListeners[type] = handlers
    }
    
    // MARK: - 事件分发
    
    /// 分发事件
    /// - Parameter context: 事件上下文
    /// - Returns: 事件是否被处理
    @discardableResult
    public func dispatch(_ context: EventContext) -> Bool {
        if config.enableEventLog {
            TXLogger.debug("EventManager Dispatch: \(context.type.rawValue) -> \(context.componentId)")
        }
        
        // 1. 捕获阶段（从根到目标）
        if config.enableCapturing {
            let path = buildEventPath(from: context.component)
            for _ in path.reversed() {
                // 捕获阶段处理...
            }
        }
        
        // 2. 目标阶段
        let handled = handleEventAtTarget(context)
        
        // 3. 冒泡阶段
        if config.enableBubbling && !handled {
            return bubbleEvent(context)
        }
        
        // 4. 全局监听器
        notifyGlobalListeners(context)
        
        return handled
    }
    
    /// 在目标组件处理事件
    private func handleEventAtTarget(_ context: EventContext) -> Bool {
        let bindings = eventBindings[context.componentId]?[context.type] ?? []
        
        var handled = false
        
        for binding in bindings {
            // 检查节流
            if binding.throttle > 0 && !checkThrottle(context, binding: binding) {
                continue
            }
            
            // 检查防抖
            if binding.debounce > 0 {
                scheduleDebounce(context, binding: binding)
                continue
            }
            
            // 执行动作
            let result = executeAction(binding.action, context: context)
            
            if result {
                handled = true
            }
            
            if binding.stopPropagation {
                return true  // 停止冒泡
            }
        }
        
        return handled
    }
    
    /// 事件冒泡
    private func bubbleEvent(_ context: EventContext) -> Bool {
        guard let component = context.component,
              let parent = component.parent else {
            return false
        }
        
        let parentContext = EventContext(
            type: context.type,
            componentId: parent.id,
            view: parent.view,
            component: parent
        )
        
        return dispatch(parentContext)
    }
    
    /// 通知全局监听器
    private func notifyGlobalListeners(_ context: EventContext) {
        let handlers = globalListeners[context.type] ?? []
        
        for weakHandler in handlers {
            _ = weakHandler.handler?.handleEvent(context)
        }
    }
    
    // MARK: - 动作执行
    
    /// 执行事件动作
    private func executeAction(_ action: EventAction, context: EventContext) -> Bool {
        switch action {
        case .url(let urlString, let rawParams):
            return executeURLAction(urlString, rawParams: rawParams, context: context)
            
        case .custom(let callback):
            return callback(context)
        }
    }
    
    /// 执行 URL 动作
    /// 1. 从组件 bindings 获取数据上下文
    /// 2. 求值 URL 和 params 中的表达式
    /// 3. 通过 ServiceRegistry.actionHandler 传递给接入方
    private func executeURLAction(_ urlString: String, rawParams: [String: Any]?, context: EventContext) -> Bool {
        // 从组件 bindings 获取数据上下文
        let dataContext = context.component?.bindings ?? [:]
        
        // 求值 URL 中的表达式（如 "app://detail?id=${post.id}"）
        let resolvedUrl: String
        if expressionEngine.containsBinding(urlString) {
            resolvedUrl = expressionEngine.resolveBinding(urlString, context: dataContext) as? String ?? urlString
        } else {
            resolvedUrl = urlString
        }
        
        // 求值 params 中的表达式（递归处理嵌套字典/数组）
        let resolvedParams: [String: Any]
        if let rawParams = rawParams {
            resolvedParams = expressionEngine.resolveBindings(rawParams, context: dataContext)
        } else {
            resolvedParams = [:]
        }
        
        // 通过 Service 传递给接入方
        guard let handler = ServiceRegistry.shared.actionHandler else {
            TXLogger.warning("ActionHandler not registered. Call TemplateX.registerActionHandler(...) to handle events.")
            return false
        }
        
        handler.handleAction(url: resolvedUrl, params: resolvedParams, context: context)
        
        if config.enableEventLog {
            TXLogger.debug("EventManager URL Action: \(resolvedUrl), params: \(resolvedParams)")
        }
        
        return true
    }
    
    // MARK: - 节流和防抖
    
    private func checkThrottle(_ context: EventContext, binding: EventBinding) -> Bool {
        let key = "\(context.componentId)_\(context.type.rawValue)"
        let now = Date().timeIntervalSince1970 * 1000  // 转为毫秒
        
        let lastTime = throttleTimers[key] ?? 0
        
        if now - lastTime < Double(binding.throttle) {
            return false
        }
        
        throttleTimers[key] = now
        
        return true
    }
    
    private func scheduleDebounce(_ context: EventContext, binding: EventBinding) {
        let key = "\(context.componentId)_\(context.type.rawValue)"
        
        // 取消之前的
        debounceWorkItems[key]?.cancel()
        
        // 创建新的
        let workItem = DispatchWorkItem { [weak self] in
            _ = self?.executeAction(binding.action, context: context)
        }
        debounceWorkItems[key] = workItem
        
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(binding.debounce),
            execute: workItem
        )
    }
    
    // MARK: - 辅助方法
    
    private func buildEventPath(from component: (any Component)?) -> [any Component] {
        var path: [any Component] = []
        var current = component
        
        while let c = current {
            path.append(c)
            current = c.parent
        }
        
        return path
    }
    
    /// 解析事件配置
    ///
    /// 支持格式：
    /// ```json
    /// { "url": "app://follow", "params": { "userId": "${user.id}" } }
    /// ```
    private func parseEventConfig(type: EventType, config: [String: Any]) -> EventBinding {
        var binding: EventBinding
        
        if let url = config["url"] as? String {
            binding = EventBinding(type: type, action: .url(url, params: config["params"] as? [String: Any]))
        } else {
            // 无 url 字段时，尝试将整个 config 作为 params，url 为空
            TXLogger.warning("Event config missing 'url' field, ignored: \(config)")
            binding = EventBinding(type: type, action: .url("", params: nil))
        }
        
        binding.stopPropagation = config["stopPropagation"] as? Bool ?? false
        binding.preventDefault = config["preventDefault"] as? Bool ?? false
        binding.throttle = config["throttle"] as? Int ?? 0
        binding.debounce = config["debounce"] as? Int ?? 0
        
        return binding
    }
}

// MARK: - 弱引用包装

private class WeakHandler {
    weak var handler: EventHandler?
    
    init(_ handler: EventHandler) {
        self.handler = handler
    }
}
