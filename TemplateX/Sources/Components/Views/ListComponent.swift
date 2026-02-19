import UIKit

// MARK: - List 组件

/// 列表视图组件 - 基于 UICollectionView 实现
/// 支持垂直/水平滚动、Cell 复用、瀑布流布局
final class ListComponent: TemplateXComponent<SelfSizingCollectionView, ListComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        var direction: String?
        var columns: Int?
        var rowSpacing: CGFloat?
        var columnSpacing: CGFloat?
        @Default<False>
        var showsIndicator: Bool
        @Default<True>
        var bounces: Bool
        var estimatedItemHeight: CGFloat?
        var loadMoreThreshold: CGFloat?
        var cellTemplate: String?
        
        /// 滚动方向
        var scrollDirection: ScrollDirection {
            ScrollDirection(rawValue: direction?.lowercased() ?? "vertical") ?? .vertical
        }
    }
    
    /// 滚动方向
    enum ScrollDirection: String {
        case horizontal
        case vertical
    }
    
    // MARK: - ComponentFactory
    
    override class var typeIdentifier: String { "list" }
    
    // MARK: - 运行时属性（不通过 Props 解析）
    
    /// 数据源
    var dataSource: [Any] = [] {
        didSet {
            if dataSource.count != oldValue.count || dataSource.count > 0 {
                collectionView?.reloadData()
            }
        }
    }
    
    /// Cell 模板 JSON
    var cellTemplate: JSONWrapper?
    
    /// Cell 模板 ID
    var cellTemplateId: String?
    
    /// 内容边距
    var contentInset: EdgeInsets = .zero
    
    /// 预加载管理器
    var preloadManager: ListPreloadManager?
    
    // MARK: - 事件回调
    
    var onItemClick: ((Int, Any) -> Void)?
    var onScroll: ((CGPoint) -> Void)?
    var onLoadMore: (() -> Void)?
    
    // MARK: - Private
    
    private weak var collectionView: UICollectionView?
    private var listDataSource: ListDataSource?
    private var listDelegate: ListDelegate?
    
    // MARK: - 自定义 Props 解析
    
    override class func parseProps(from json: JSONWrapper?) -> Props {
        guard let json = json else { return Props() }
        
        var props = Props()
        props.direction = json.string("direction")
        props.columns = json.int("columns")
        props.rowSpacing = json.cgFloat("rowSpacing")
        props.columnSpacing = json.cgFloat("columnSpacing")
        props.showsIndicator = json.bool("showsIndicator", default: true)
        props.bounces = json.bool("bounces", default: true)
        props.estimatedItemHeight = json.cgFloat("estimatedItemHeight")
        props.loadMoreThreshold = json.cgFloat("loadMoreThreshold")
        props.cellTemplate = json.string("cellTemplate")
        return props
    }
    
    override func didParseProps() {
        // 列表默认裁剪
        style.clipsToBounds = true
        
        // 解析 Cell 模板
        if let propsJson = jsonWrapper?.props {
            // 解析内容边距
            contentInset = propsJson.edgeInsets("contentInset")
            
            // Cell 模板 - 支持多种方式
            cellTemplateId = props.cellTemplate
            
            // 优先使用 itemTemplate（新格式）
            if let itemTemplateJson = propsJson.child("itemTemplate") {
                cellTemplate = itemTemplateJson
            }
            // 回退到 cell（旧格式）
            else if let cellJson = propsJson.child("cell") {
                cellTemplate = cellJson
            }
        }
    }
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let layout = createCollectionViewLayout()
        let collectionView = SelfSizingCollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.backgroundColor = style.backgroundColor ?? .clear
        collectionView.showsVerticalScrollIndicator = props.showsIndicator && props.scrollDirection == .vertical
        collectionView.showsHorizontalScrollIndicator = props.showsIndicator && props.scrollDirection == .horizontal
        collectionView.bounces = props.bounces
        collectionView.contentInset = contentInset.uiEdgeInsets
        
        // 注册 Cell
        collectionView.register(TemplateXCell.self, forCellWithReuseIdentifier: TemplateXCell.reuseIdentifier)
        
        // 设置数据源和代理
        let dataSource = ListDataSource(component: self)
        let delegate = ListDelegate(component: self)
        
        collectionView.dataSource = dataSource
        collectionView.delegate = delegate
        
        self.listDataSource = dataSource
        self.listDelegate = delegate
        self.collectionView = collectionView
        self.view = collectionView
        
        return collectionView
    }
    
    override func configureView(_ view: SelfSizingCollectionView) {
        view.showsVerticalScrollIndicator = props.showsIndicator && props.scrollDirection == .vertical
        view.showsHorizontalScrollIndicator = props.showsIndicator && props.scrollDirection == .horizontal
        view.bounces = props.bounces
        view.contentInset = contentInset.uiEdgeInsets
        
        // 更新布局
        if let layout = view.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = props.scrollDirection == .horizontal ? .horizontal : .vertical
            layout.minimumLineSpacing = props.rowSpacing ?? 0
            layout.minimumInteritemSpacing = props.columnSpacing ?? 0
        }
        
        // 处理 auto 高度
        let isAutoHeight = style.height.isAuto
        view.isAutoSizing = isAutoHeight
        view.isScrollEnabled = !isAutoHeight
    }
    
    override func applyLayout() {
        guard let view = view else { return }
        
        var newFrame = layoutResult.frame
        
        // 检查是否是 auto 高度
        let isAutoHeight = style.height.isAuto
        
        if isAutoHeight, let collectionView = view as? UICollectionView {
            collectionView.layoutIfNeeded()
            let contentHeight = collectionView.contentSize.height + contentInset.top + contentInset.bottom
            newFrame.size.height = contentHeight
            
            var updatedResult = layoutResult
            updatedResult.frame = newFrame
            layoutResult = updatedResult
        }
        
        view.frame = newFrame
    }
    
    // MARK: - Private
    
    private func createCollectionViewLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        
        layout.scrollDirection = props.scrollDirection == .horizontal ? .horizontal : .vertical
        layout.minimumLineSpacing = props.rowSpacing ?? 0
        layout.minimumInteritemSpacing = props.columnSpacing ?? 0
        
        // 如果是单列，使用预估高度
        if (props.columns ?? 1) == 1 {
            layout.estimatedItemSize = CGSize(
                width: UIScreen.main.bounds.width,
                height: props.estimatedItemHeight ?? 44
            )
        }
        
        return layout
    }
    
    // MARK: - Data Methods
    
    /// 更新数据源
    func updateData(_ data: [Any]) {
        self.dataSource = data
        collectionView?.reloadData()
    }
    
    /// 插入数据
    func insertItems(at indices: [Int], data: [Any]) {
        for (i, index) in indices.enumerated() {
            if index <= dataSource.count && i < data.count {
                dataSource.insert(data[i], at: index)
            }
        }
        let indexPaths = indices.map { IndexPath(item: $0, section: 0) }
        collectionView?.insertItems(at: indexPaths)
    }
    
    /// 删除数据
    func deleteItems(at indices: [Int]) {
        let sortedIndices = indices.sorted(by: >)
        for index in sortedIndices {
            if index < dataSource.count {
                dataSource.remove(at: index)
            }
        }
        let indexPaths = indices.map { IndexPath(item: $0, section: 0) }
        collectionView?.deleteItems(at: indexPaths)
    }
    
    /// 刷新指定项
    func reloadItems(at indices: [Int]) {
        let indexPaths = indices.map { IndexPath(item: $0, section: 0) }
        collectionView?.reloadItems(at: indexPaths)
    }
    
    /// 滚动到指定位置
    func scrollToItem(at index: Int, animated: Bool = true) {
        guard index < dataSource.count else { return }
        let indexPath = IndexPath(item: index, section: 0)
        let position: UICollectionView.ScrollPosition = props.scrollDirection == .horizontal ? .centeredHorizontally : .centeredVertically
        collectionView?.scrollToItem(at: indexPath, at: position, animated: animated)
    }
    
    // MARK: - Clone
    
    override func clone() -> Component {
        let cloned = super.clone() as! ListComponent
        cloned.dataSource = self.dataSource
        cloned.cellTemplate = self.cellTemplate
        cloned.cellTemplateId = self.cellTemplateId
        cloned.contentInset = self.contentInset
        return cloned
    }
}

// MARK: - ListDataSource

private class ListDataSource: NSObject, UICollectionViewDataSource {
    
    weak var component: ListComponent?
    
    init(component: ListComponent) {
        self.component = component
        super.init()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return component?.dataSource.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TemplateXCell.reuseIdentifier, for: indexPath) as! TemplateXCell
        
        guard let component = component,
              indexPath.item < component.dataSource.count else {
            TXLogger.warning("[ListDataSource] cellForItemAt: invalid index \(indexPath.item)")
            return cell
        }
        
        let itemData = component.dataSource[indexPath.item]
        
        if let cellTemplate = component.cellTemplate {
            let cellSize = calculateCellSize(collectionView: collectionView, component: component)
            let templateId = component.cellTemplateId ?? "list_cell_\(component.id)"
            
            // 尝试使用预加载的视图
            if let preloadManager = component.preloadManager,
               let (preloadedView, preloadedComponent) = preloadManager.dequeuePreloadedView(for: indexPath.item) {
                cell.configureWithPreloaded(
                    view: preloadedView,
                    component: preloadedComponent,
                    templateId: templateId
                )
            } else {
                cell.configure(
                    with: cellTemplate,
                    templateId: templateId,
                    data: itemData,
                    index: indexPath.item,
                    containerSize: cellSize
                )
            }
        }
        
        return cell
    }
    
    private func calculateCellSize(collectionView: UICollectionView, component: ListComponent) -> CGSize {
        let columns = CGFloat(max(1, component.props.columns ?? 1))
        let totalSpacing = (component.props.columnSpacing ?? 0) * (columns - 1)
        let insets = component.contentInset
        
        if component.props.scrollDirection == .vertical {
            var containerWidth = collectionView.bounds.width
            if containerWidth == 0 {
                containerWidth = component.layoutResult.frame.width
            }
            
            let availableWidth = containerWidth - insets.left - insets.right - totalSpacing
            let itemWidth = availableWidth / columns
            
            return CGSize(width: itemWidth, height: component.props.estimatedItemHeight ?? 44)
        } else {
            var containerHeight = collectionView.bounds.height
            if containerHeight == 0 {
                containerHeight = component.layoutResult.frame.height
            }
            
            let availableHeight = containerHeight - insets.top - insets.bottom - totalSpacing
            let itemHeight = availableHeight / columns
            return CGSize(width: component.props.estimatedItemHeight ?? 44, height: itemHeight)
        }
    }
}

// MARK: - ListDelegate

private class ListDelegate: NSObject, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    weak var component: ListComponent?
    private var isLoadingMore = false
    
    init(component: ListComponent) {
        self.component = component
        super.init()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let component = component,
              indexPath.item < component.dataSource.count else { return }
        
        let itemData = component.dataSource[indexPath.item]
        component.onItemClick?(indexPath.item, itemData)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let component = component else { return }
        
        component.onScroll?(scrollView.contentOffset)
        checkLoadMore(scrollView)
        triggerPreload(scrollView)
    }
    
    private func triggerPreload(_ scrollView: UIScrollView) {
        guard let component = component,
              let collectionView = scrollView as? UICollectionView,
              let preloadManager = component.preloadManager else { return }
        
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems.sorted { $0.item < $1.item }
        guard let first = visibleIndexPaths.first?.item,
              let last = visibleIndexPaths.last?.item else { return }
        
        let visibleRange = first..<(last + 1)
        
        preloadManager.handleScroll(
            scrollView: scrollView,
            visibleRange: visibleRange,
            dataSource: component.dataSource
        )
    }
    
    private func checkLoadMore(_ scrollView: UIScrollView) {
        guard let component = component,
              let onLoadMore = component.onLoadMore,
              !isLoadingMore else { return }
        
        let threshold = component.props.loadMoreThreshold ?? 100
        
        if component.props.scrollDirection == .vertical {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.height
            
            if offsetY + frameHeight + threshold >= contentHeight && contentHeight > 0 {
                isLoadingMore = true
                onLoadMore()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isLoadingMore = false
                }
            }
        } else {
            let offsetX = scrollView.contentOffset.x
            let contentWidth = scrollView.contentSize.width
            let frameWidth = scrollView.frame.width
            
            if offsetX + frameWidth + threshold >= contentWidth && contentWidth > 0 {
                isLoadingMore = true
                onLoadMore()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isLoadingMore = false
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let component = component else {
            return CGSize(width: 100, height: 100)
        }
        
        let itemWidth = calculateItemWidth(collectionView: collectionView, component: component)
        
        // 优先使用预加载管理器的高度缓存
        if let preloadManager = component.preloadManager,
           let cachedHeight = preloadManager.cachedHeight(for: indexPath.item) {
            if component.props.scrollDirection == .vertical {
                return CGSize(width: itemWidth, height: cachedHeight)
            } else {
                return CGSize(width: cachedHeight, height: itemWidth)
            }
        }
        
        // 如果有 Cell 模板，计算实际高度
        if let cellTemplate = component.cellTemplate,
           indexPath.item < component.dataSource.count {
            
            let itemData = component.dataSource[indexPath.item]
            
            var context: [String: Any] = [:]
            if let dictData = itemData as? [String: Any] {
                context = dictData
            } else {
                context["item"] = itemData
            }
            context["index"] = indexPath.item
            
            let templateId = component.cellTemplateId ?? "list_cell_\(component.id)"
            
            let height = TemplateXRenderEngine.shared.calculateHeight(
                json: cellTemplate.rawDictionary,
                templateId: templateId,
                data: context,
                containerWidth: itemWidth,
                useCache: true
            )
            
            if height > 0 {
                if component.props.scrollDirection == .vertical {
                    return CGSize(width: itemWidth, height: height)
                } else {
                    return CGSize(width: height, height: itemWidth)
                }
            }
        }
        
        // 回退到预估高度
        if component.props.scrollDirection == .vertical {
            return CGSize(width: itemWidth, height: component.props.estimatedItemHeight ?? 44)
        } else {
            let itemHeight = calculateItemHeight(collectionView: collectionView, component: component)
            return CGSize(width: component.props.estimatedItemHeight ?? 44, height: itemHeight)
        }
    }
    
    private func calculateItemWidth(collectionView: UICollectionView, component: ListComponent) -> CGFloat {
        let columns = CGFloat(max(1, component.props.columns ?? 1))
        let totalSpacing = (component.props.columnSpacing ?? 0) * (columns - 1)
        let insets = component.contentInset
        let availableWidth = collectionView.bounds.width - insets.left - insets.right - totalSpacing
        return availableWidth / columns
    }
    
    private func calculateItemHeight(collectionView: UICollectionView, component: ListComponent) -> CGFloat {
        let columns = CGFloat(max(1, component.props.columns ?? 1))
        let totalSpacing = (component.props.columnSpacing ?? 0) * (columns - 1)
        let insets = component.contentInset
        let availableHeight = collectionView.bounds.height - insets.top - insets.bottom - totalSpacing
        return availableHeight / columns
    }
}

// MARK: - TemplateXCell

/// 模板渲染 Cell
class TemplateXCell: UICollectionViewCell {
    
    static let reuseIdentifier = "TemplateXCell"
    
    private var contentRootView: UIView?
    private var currentTemplateId: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentView.clipsToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    func configure(
        with template: JSONWrapper,
        templateId: String,
        data: Any,
        index: Int,
        containerSize: CGSize
    ) {
        var context: [String: Any] = [
            "item": data,
            "index": index
        ]
        
        let needsRender = contentRootView == nil || currentTemplateId != templateId
        
        if needsRender {
            contentRootView?.removeFromSuperview()
            
            if let view = TemplateXRenderEngine.shared.renderWithCache(
                json: template.rawDictionary,
                templateId: templateId,
                data: context,
                containerSize: containerSize
            ) {
                contentView.addSubview(view)
                view.frame = contentView.bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                contentRootView = view
                currentTemplateId = templateId
            }
        } else {
            if let view = contentRootView {
                TemplateXRenderEngine.shared.quickUpdate(
                    view: view,
                    data: context,
                    containerSize: containerSize
                )
            }
        }
    }
    
    func configure(with template: JSONWrapper, data: Any, index: Int) {
        configure(
            with: template,
            templateId: "default_cell_\(template.type ?? "unknown")",
            data: data,
            index: index,
            containerSize: contentView.bounds.size
        )
    }
    
    func configureWithPreloaded(
        view: UIView,
        component: Component,
        templateId: String
    ) {
        contentRootView?.removeFromSuperview()
        
        contentView.addSubview(view)
        view.frame = contentView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentRootView = view
        currentTemplateId = templateId
        
        let viewId = TemplateXRenderEngine.shared.generateViewIdentifier(view)
        TemplateXRenderEngine.shared.cacheComponent(component, forViewId: viewId)
    }
}

// MARK: - GridComponent

/// 网格布局组件 - List 的便捷封装
final class GridComponent: TemplateXComponent<SelfSizingCollectionView, GridComponent.Props> {
    
    struct Props: ComponentProps {
        var columns: Int?
        var rowSpacing: CGFloat?
        var columnSpacing: CGFloat?
    }
    
    override class var typeIdentifier: String { "grid" }
    
    /// 内部使用的 List 组件
    private var listComponent: ListComponent?
    
    override func createView() -> UIView {
        // Grid 内部使用 ListComponent
        let list = ListComponent(id: "\(id)_list")
        list.props.direction = "vertical"
        list.props.columns = props.columns ?? 2
        list.props.rowSpacing = props.rowSpacing
        list.props.columnSpacing = props.columnSpacing
        list.style = style
        
        listComponent = list
        let view = list.createView()
        self.view = view
        return view
    }
    
    func updateData(_ data: [Any]) {
        listComponent?.updateData(data)
    }
}

// MARK: - SelfSizingCollectionView

/// 自适应内容高度的 UICollectionView
class SelfSizingCollectionView: UICollectionView {
    
    var isAutoSizing: Bool = false {
        didSet {
            if isAutoSizing {
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    override var contentSize: CGSize {
        didSet {
            if isAutoSizing && oldValue != contentSize {
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        if isAutoSizing {
            layoutIfNeeded()
            return CGSize(
                width: UIView.noIntrinsicMetric,
                height: contentSize.height
            )
        }
        return super.intrinsicContentSize
    }
}
