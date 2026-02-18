import UIKit

// MARK: - 手势处理器

/// 手势处理器
/// 将 UIGestureRecognizer 事件转换为 TemplateX 事件
public final class GestureHandler: NSObject {
    
    // MARK: - 属性
    
    /// 关联的组件 ID
    public let componentId: String
    
    /// 关联的视图
    public weak var view: UIView?
    
    /// 关联的组件
    public weak var component: (any Component)?
    
    /// 已添加的手势识别器
    private var gestureRecognizers: [EventType: UIGestureRecognizer] = [:]
    
    /// 事件管理器
    private let eventManager = EventManager.shared
    
    // MARK: - Init
    
    public init(componentId: String, view: UIView, component: (any Component)? = nil) {
        self.componentId = componentId
        self.view = view
        self.component = component
        super.init()
    }
    
    deinit {
        removeAllGestures()
    }
    
    // MARK: - 手势配置
    
    /// 配置手势（从事件配置）
    public func configure(events: [String: Any]) {
        for (key, _) in events {
            guard let eventType = EventType(rawValue: key) else { continue }
            addGesture(for: eventType)
        }
    }
    
    /// 添加手势
    public func addGesture(for eventType: EventType) {
        guard let view = view else { return }
        guard gestureRecognizers[eventType] == nil else { return }
        
        let gesture: UIGestureRecognizer?
        
        switch eventType {
        case .tap:
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            gesture = tap
            
        case .doubleTap:
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            gesture = doubleTap
            
        case .longPress:
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            gesture = longPress
            
        case .pan:
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            gesture = pan
            
        case .swipe:
            // 添加四个方向的滑动
            let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipeRight.direction = .right
            view.addGestureRecognizer(swipeRight)
            
            let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipeLeft.direction = .left
            view.addGestureRecognizer(swipeLeft)
            
            let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipeUp.direction = .up
            view.addGestureRecognizer(swipeUp)
            
            let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipeDown.direction = .down
            view.addGestureRecognizer(swipeDown)
            
            gestureRecognizers[eventType] = swipeRight  // 只存一个作为标记
            return
            
        case .pinch:
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            gesture = pinch
            
        case .rotation:
            let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
            gesture = rotation
            
        default:
            gesture = nil
        }
        
        if let gesture = gesture {
            view.addGestureRecognizer(gesture)
            gestureRecognizers[eventType] = gesture
            view.isUserInteractionEnabled = true
        }
    }
    
    /// 移除手势
    public func removeGesture(for eventType: EventType) {
        guard let gesture = gestureRecognizers.removeValue(forKey: eventType) else { return }
        view?.removeGestureRecognizer(gesture)
    }
    
    /// 移除所有手势
    public func removeAllGestures() {
        for (_, gesture) in gestureRecognizers {
            view?.removeGestureRecognizer(gesture)
        }
        gestureRecognizers.removeAll()
    }
    
    // MARK: - 手势处理
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        dispatchEvent(type: .tap, gesture: gesture)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        dispatchEvent(type: .doubleTap, gesture: gesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 只在开始时触发
        if gesture.state == .began {
            dispatchEvent(type: .longPress, gesture: gesture)
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        var context = createEventContext(type: .pan, gesture: gesture)
        
        // 添加 pan 特有的数据
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        context.extra["translationX"] = translation.x
        context.extra["translationY"] = translation.y
        context.extra["velocityX"] = velocity.x
        context.extra["velocityY"] = velocity.y
        context.gestureState = gesture.state
        
        eventManager.dispatch(context)
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        var context = createEventContext(type: .swipe, gesture: gesture)
        
        // 添加方向信息
        switch gesture.direction {
        case .right:
            context.extra["direction"] = "right"
        case .left:
            context.extra["direction"] = "left"
        case .up:
            context.extra["direction"] = "up"
        case .down:
            context.extra["direction"] = "down"
        default:
            context.extra["direction"] = "unknown"
        }
        
        eventManager.dispatch(context)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        var context = createEventContext(type: .pinch, gesture: gesture)
        
        context.extra["scale"] = gesture.scale
        context.extra["velocity"] = gesture.velocity
        context.gestureState = gesture.state
        
        eventManager.dispatch(context)
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        var context = createEventContext(type: .rotation, gesture: gesture)
        
        context.extra["rotation"] = gesture.rotation
        context.extra["velocity"] = gesture.velocity
        context.gestureState = gesture.state
        
        eventManager.dispatch(context)
    }
    
    // MARK: - 辅助方法
    
    private func dispatchEvent(type: EventType, gesture: UIGestureRecognizer) {
        let context = createEventContext(type: type, gesture: gesture)
        eventManager.dispatch(context)
    }
    
    private func createEventContext(type: EventType, gesture: UIGestureRecognizer) -> EventContext {
        var context = EventContext(
            type: type,
            componentId: componentId,
            view: view,
            component: component
        )
        
        context.location = gesture.location(in: view)
        
        if let window = view?.window {
            context.globalLocation = gesture.location(in: window)
        }
        
        context.gestureState = gesture.state
        
        return context
    }
}

// MARK: - 手势处理器管理

/// 手势处理器管理器
/// 管理所有组件的手势处理器
/// 注意：此类只在主线程访问（处理 UIGestureRecognizer），无需加锁
public final class GestureHandlerManager {
    
    // MARK: - 单例
    
    public static let shared = GestureHandlerManager()
    
    // MARK: - 存储
    
    /// 组件 -> 手势处理器
    private var handlers: [String: GestureHandler] = [:]
    
    private init() {}
    
    // MARK: - API
    
    /// 为组件创建手势处理器
    @discardableResult
    public func createHandler(
        for component: Component,
        view: UIView
    ) -> GestureHandler {
        // 如果已存在，先移除
        if let existing = handlers[component.id] {
            existing.removeAllGestures()
        }
        
        let handler = GestureHandler(
            componentId: component.id,
            view: view,
            component: component
        )
        
        handlers[component.id] = handler
        
        return handler
    }
    
    /// 获取组件的手势处理器
    public func getHandler(for componentId: String) -> GestureHandler? {
        return handlers[componentId]
    }
    
    /// 移除组件的手势处理器
    public func removeHandler(for componentId: String) {
        if let handler = handlers.removeValue(forKey: componentId) {
            handler.removeAllGestures()
        }
    }
    
    /// 清除所有手势处理器
    public func clear() {
        for (_, handler) in handlers {
            handler.removeAllGestures()
        }
        handlers.removeAll()
    }
    
    /// 配置组件的事件
    public func configureEvents(
        for component: Component,
        view: UIView,
        events: [String: Any]
    ) {
        // 1. 创建或获取处理器
        let handler = createHandler(for: component, view: view)
        
        // 2. 配置手势
        handler.configure(events: events)
        
        // 3. 绑定事件到 EventManager
        EventManager.shared.bindEvents(from: events, to: component.id)
    }
}

// MARK: - UIView 扩展

extension UIView {
    
    private static var gestureHandlerKey: UInt8 = 0
    
    /// 关联的手势处理器
    var gestureHandler: GestureHandler? {
        get {
            return objc_getAssociatedObject(self, &Self.gestureHandlerKey) as? GestureHandler
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.gestureHandlerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

// MARK: - 触摸反馈

/// 触摸反馈处理器
public final class TouchFeedbackHandler {
    
    /// 高亮效果
    public static func applyHighlight(to view: UIView, highlighted: Bool) {
        UIView.animate(withDuration: 0.1) {
            view.alpha = highlighted ? 0.7 : 1.0
        }
    }
    
    /// 缩放效果
    public static func applyScale(to view: UIView, pressed: Bool) {
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction],
            animations: {
                view.transform = pressed ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        )
    }
    
    /// 波纹效果（Material Design 风格）
    public static func applyRipple(to view: UIView, at point: CGPoint) {
        let rippleView = UIView()
        rippleView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        
        let size = max(view.bounds.width, view.bounds.height) * 2
        rippleView.frame = CGRect(x: 0, y: 0, width: size, height: size)
        rippleView.center = point
        rippleView.layer.cornerRadius = size / 2
        rippleView.alpha = 1
        rippleView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        view.addSubview(rippleView)
        view.clipsToBounds = true
        
        UIView.animate(
            withDuration: 0.4,
            animations: {
                rippleView.transform = .identity
                rippleView.alpha = 0
            },
            completion: { _ in
                rippleView.removeFromSuperview()
            }
        )
    }
}
