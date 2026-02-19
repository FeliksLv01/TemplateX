import UIKit

// MARK: - Scroll 组件

/// 滚动视图组件
/// 支持水平/垂直滚动，弹性效果，分页
final class ScrollComponent: TemplateXComponent<TemplateXScrollView, ScrollComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        var direction: String?
        var scrollDirection: String?
        @Default<True> var showsIndicator: Bool
        @Default<True> var bounces: Bool
        @Default<False> var pagingEnabled: Bool
        var contentInsetTop: CGFloat?
        var contentInsetLeft: CGFloat?
        var contentInsetBottom: CGFloat?
        var contentInsetRight: CGFloat?
        
        /// 获取滚动方向
        var scrollDir: ScrollDirection {
            let dir = direction ?? scrollDirection ?? "vertical"
            return ScrollDirection(rawValue: dir.lowercased()) ?? .vertical
        }
        
        /// 获取内容边距
        var contentInset: UIEdgeInsets {
            UIEdgeInsets(
                top: contentInsetTop ?? 0,
                left: contentInsetLeft ?? 0,
                bottom: contentInsetBottom ?? 0,
                right: contentInsetRight ?? 0
            )
        }
    }
    
    /// 滚动方向
    enum ScrollDirection: String {
        case horizontal
        case vertical
        case both
    }
    
    // MARK: - ComponentFactory
    
    override class var typeIdentifier: String { "scroll" }
    
    // MARK: - 事件回调
    
    var onScroll: ((CGPoint) -> Void)?
    var onScrollEnd: ((CGPoint) -> Void)?
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let scrollView = TemplateXScrollView()
        scrollView.delegate = scrollView
        self.view = scrollView
        return scrollView
    }
    
    override func didParseProps() {
        // 滚动视图默认裁剪
        style.clipsToBounds = true
    }
    
    override func configureView(_ view: TemplateXScrollView) {
        let direction = props.scrollDir
        
        view.direction = direction
        view.showsHorizontalScrollIndicator = props.showsIndicator && (direction == .horizontal || direction == .both)
        view.showsVerticalScrollIndicator = props.showsIndicator && (direction == .vertical || direction == .both)
        view.bounces = props.bounces
        view.isPagingEnabled = props.pagingEnabled
        view.contentInset = props.contentInset
        view.onScroll = onScroll
        view.onScrollEnd = onScrollEnd
    }
    
    // MARK: - Public Methods
    
    /// 更新内容尺寸
    func updateContentSize() {
        guard let scrollView = view as? UIScrollView else { return }
        
        // 计算所有子视图的 bounds
        var contentRect = CGRect.zero
        for subview in scrollView.subviews {
            contentRect = contentRect.union(subview.frame)
        }
        
        // 添加 padding
        let padding = style.padding
        contentRect.size.width += padding.right
        contentRect.size.height += padding.bottom
        
        scrollView.contentSize = contentRect.size
    }
}

// MARK: - TemplateXScrollView

/// 自定义滚动视图
class TemplateXScrollView: UIScrollView, UIScrollViewDelegate {
    
    var direction: ScrollComponent.ScrollDirection = .vertical
    
    /// 滚动回调
    var onScroll: ((CGPoint) -> Void)?
    var onScrollEnd: ((CGPoint) -> Void)?
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(scrollView.contentOffset)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        onScrollEnd?(scrollView.contentOffset)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            onScrollEnd?(scrollView.contentOffset)
        }
    }
}
