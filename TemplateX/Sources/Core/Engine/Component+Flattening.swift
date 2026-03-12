import UIKit

// MARK: - 视图拍平

private let prunableTypes: Set<String> = ["container"]

extension Component {
    
    /// 判断组件是否为纯布局容器（可以被剪枝）
    ///
    /// 必须同时满足：类型为 container、无事件、无视觉属性（背景色/渐变/边框/圆角/阴影）、
    /// 透明度为 1、不裁剪子视图、display/visibility 正常、不需要强制样式。
    var isPrunable: Bool {
        guard prunableTypes.contains(type) else { return false }
        guard events.isEmpty else { return false }
        guard !forceApplyStyle else { return false }
        
        let s = style
        guard s.display == .flex, s.visibility == .visible else { return false }
        
        if let bgColor = s.backgroundColor, bgColor != .clear { return false }
        if s.backgroundGradient != nil { return false }
        if s.borderWidth > 0 || s.borderColor != nil { return false }
        if s.cornerRadius > 0 || s.cornerRadii != nil { return false }
        if s.shadowOpacity > 0 || s.shadowColor != nil { return false }
        if s.opacity < 1.0 { return false }
        if s.clipsToBounds || s.overflow == .hidden { return false }
        
        return true
    }
    
    /// 创建拍平后的视图树
    ///
    /// isPruned 和 layoutResult.frame 已由 YogaLayoutEngine.collectLayoutResults() 预计算，
    /// 此方法只负责构建 UIView 层级：跳过被剪枝组件，将其子视图提升到最近的非剪枝祖先。
    func createFlattenedViewTree() -> [UIView] {
        if parseError != nil {
            return [Self.createErrorView(for: self)]
        }
        
        if isPruned {
            return children.flatMap { $0.createFlattenedViewTree() }
        }
        
        let v = view ?? {
            let created = createView()
            if self.view == nil { self.view = created }
            return created
        }()
        v.accessibilityIdentifier = id
        
        for child in children {
            for childView in child.createFlattenedViewTree() {
                if childView.superview !== v {
                    v.addSubview(childView)
                }
            }
        }
        
        return [v]
    }
    
    /// 递归更新非剪枝组件的视图（frame 已由 collectLayoutResults 预计算）
    /// 只有 needsViewUpdate 为 true 的组件才调用 updateView()
    func updateFlattenedFrames() {
        // display=none 的组件及其整个子树无需更新
        if style.display == .none { return }
        
        if !isPruned && (needsViewUpdate || forceApplyStyle) {
            updateView()
        }
        children.forEach { $0.updateFlattenedFrames() }
    }
    
    // MARK: - Private
    
    private static func createErrorView(for component: Component) -> UIView {
        #if DEBUG
        let container = UIView()
        container.backgroundColor = UIColor.red.withAlphaComponent(0.3)
        container.layer.borderColor = UIColor.red.cgColor
        container.layer.borderWidth = 1
        
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .red
        label.textAlignment = .center
        label.text = "[\(component.type)] Parse Error"
        
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        component.view = container
        return container
        #else
        let view = UIView()
        view.isHidden = true
        component.view = view
        return view
        #endif
    }
}
