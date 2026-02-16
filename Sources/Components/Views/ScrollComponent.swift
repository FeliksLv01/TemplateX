import UIKit

// MARK: - Scroll 组件

/// 滚动视图组件
/// 支持水平/垂直滚动，弹性效果，分页
public final class ScrollComponent: BaseComponent, ComponentFactory {
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "scroll" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = ScrollComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Properties
    
    /// 滚动方向
    public enum ScrollDirection: String {
        case horizontal
        case vertical
        case both
    }
    
    /// 滚动方向
    public var direction: ScrollDirection = .vertical
    
    /// 是否显示滚动指示器
    public var showsIndicator: Bool = true
    
    /// 是否启用弹性效果
    public var bounces: Bool = true
    
    /// 是否启用分页
    public var pagingEnabled: Bool = false
    
    /// 内容边距
    public var contentInset: EdgeInsets = .zero
    
    /// 滚动事件回调
    public var onScroll: ((CGPoint) -> Void)?
    public var onScrollEnd: ((CGPoint) -> Void)?
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: ScrollComponent.typeIdentifier)
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        let cloned = ScrollComponent(id: self.id)
        cloned.jsonWrapper = self.jsonWrapper
        cloned.style = self.style.clone()
        cloned.events = self.events
        
        // 复制 Scroll 特有属性
        cloned.direction = self.direction
        cloned.showsIndicator = self.showsIndicator
        cloned.bounces = self.bounces
        cloned.pagingEnabled = self.pagingEnabled
        cloned.contentInset = self.contentInset
        
        // 注意: 不在这里递归克隆子组件，由 RenderEngine.cloneComponentTree 统一处理
        
        return cloned
    }
    
    // MARK: - Parse
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
        
        // 滚动视图默认裁剪
        style.clipsToBounds = true
        
        // 解析滚动特有属性
        if let props = json.props {
            parseScrollProps(from: props)
        }
        
        // 解析事件
        if let eventsJson = json.events {
            events = eventsJson.rawDictionary
        }
    }
    
    private func parseScrollProps(from props: JSONWrapper) {
        if let dir = props.string("direction") {
            direction = ScrollDirection(rawValue: dir.lowercased()) ?? .vertical
        } else if let dir = props.string("scrollDirection") {
            direction = ScrollDirection(rawValue: dir.lowercased()) ?? .vertical
        }
        
        showsIndicator = props.bool("showsIndicator", default: true)
        bounces = props.bool("bounces", default: true)
        pagingEnabled = props.bool("pagingEnabled", default: false)
        
        // 内容边距
        contentInset = props.edgeInsets("contentInset")
    }
    
    // MARK: - View
    
    public override func createView() -> UIView {
        let scrollView = TemplateXScrollView()
        scrollView.direction = direction
        scrollView.showsHorizontalScrollIndicator = showsIndicator && (direction == .horizontal || direction == .both)
        scrollView.showsVerticalScrollIndicator = showsIndicator && (direction == .vertical || direction == .both)
        scrollView.bounces = bounces
        scrollView.isPagingEnabled = pagingEnabled
        scrollView.contentInset = contentInset.uiEdgeInsets
        scrollView.delegate = scrollView
        scrollView.onScroll = onScroll
        scrollView.onScrollEnd = onScrollEnd
        self.view = scrollView
        return scrollView
    }
    
    public override func updateView() {
        if let scrollView = view as? TemplateXScrollView {
            scrollView.direction = direction
            scrollView.showsHorizontalScrollIndicator = showsIndicator && (direction == .horizontal || direction == .both)
            scrollView.showsVerticalScrollIndicator = showsIndicator && (direction == .vertical || direction == .both)
            scrollView.bounces = bounces
            scrollView.isPagingEnabled = pagingEnabled
            scrollView.contentInset = contentInset.uiEdgeInsets
            scrollView.onScroll = onScroll
            scrollView.onScrollEnd = onScrollEnd
        }
        super.updateView()
    }
    
    /// 更新内容尺寸
    public func updateContentSize() {
        guard let scrollView = view as? UIScrollView else { return }
        
        // 计算所有子视图的 bounds
        var contentRect = CGRect.zero
        for subview in scrollView.subviews {
            contentRect = contentRect.union(subview.frame)
        }
        
        // 添加 padding - 从 style 读取
        let padding = style.padding
        contentRect.size.width += padding.right
        contentRect.size.height += padding.bottom
        
        scrollView.contentSize = contentRect.size
    }
}

// MARK: - TemplateXScrollView

/// 自定义滚动视图
public class TemplateXScrollView: UIScrollView, UIScrollViewDelegate {
    
    public var direction: ScrollComponent.ScrollDirection = .vertical
    
    /// 滚动回调
    public var onScroll: ((CGPoint) -> Void)?
    public var onScrollEnd: ((CGPoint) -> Void)?
    
    // MARK: - UIScrollViewDelegate
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(scrollView.contentOffset)
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        onScrollEnd?(scrollView.contentOffset)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            onScrollEnd?(scrollView.contentOffset)
        }
    }
}
