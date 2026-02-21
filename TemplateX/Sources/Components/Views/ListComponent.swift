import UIKit

// MARK: - List 组件

/// 列表视图组件 - 基于 UICollectionView 实现
/// 支持垂直/水平滚动、Cell 复用、瀑布流布局
final class ListComponent: TemplateXComponent<SelfSizingCollectionView, ListComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        var direction: String?
        var columns: Int?
        
        /// 横向滚动时，垂直方向的行数（用于 3×n 网格布局）
        var rows: Int?
        
        var rowSpacing: CGFloat?
        var columnSpacing: CGFloat?
        @Default<False>
        var showsIndicator: Bool
        @Default<True>
        var bounces: Bool
        /// 预估 item 高度（固定值）
        var estimatedItemHeight: CGFloat?
        /// 预估 item 高度表达式（如 "${itemWidth + 50}"，支持动态计算）
        var estimatedItemHeightExpr: String?
        var loadMoreThreshold: CGFloat?
        var cellTemplate: String?
        
        // MARK: - 新增属性
        
        /// 分页滚动（适用于横向滑动的 Banner 或网格）
        @Default<False>
        var isPagingEnabled: Bool
        
        /// 固定 item 宽度（横向滚动时优先使用）
        var itemWidth: CGFloat?
        
        /// 固定 item 高度（垂直滚动时优先使用）
        var itemHeight: CGFloat?
        
        /// 数据源绑定表达式（如 "${section.items}"）
        var items: String?
        
        /// 内容边距（支持从 JSON 解析）
        var contentInsetLeft: CGFloat?
        var contentInsetRight: CGFloat?
        var contentInsetTop: CGFloat?
        var contentInsetBottom: CGFloat?
        
        /// 自动调整列表高度（根据 Cell 最大高度）
        /// 适用于横向滚动列表，动态调整列表容器高度
        @Default<False>
        var autoAdjustHeight: Bool
        
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
            // 数据变化时清除高度缓存
            cachedMaxItemHeight = nil
            if dataSource.count != oldValue.count || dataSource.count > 0 {
                // 如果 collectionView 还没有有效的 frame，延迟到 applyLayout 再 reload
                if let cv = collectionView, cv.frame.width > 0 && cv.frame.height > 0 {
                    cv.reloadData()
                    // 重置滚动位置到起点（考虑 contentInset）
                    cv.contentOffset = CGPoint(x: -cv.contentInset.left, y: -cv.contentInset.top)
                } else {
                    needsReloadAfterLayout = true
                }
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
    
    /// 缓存的最大 Cell 高度（用于横向滚动列表统一高度）
    var cachedMaxItemHeight: CGFloat?
    
    /// 解析后的预估高度（支持表达式计算）
    var resolvedEstimatedItemHeight: CGFloat?
    
    // MARK: - 事件回调
    
    var onItemClick: ((Int, Any) -> Void)?
    var onScroll: ((CGPoint) -> Void)?
    var onLoadMore: (() -> Void)?
    
    // MARK: - Private
    
    private weak var collectionView: UICollectionView?
    private var listDataSource: ListDataSource?
    private var listDelegate: ListDelegate?
    
    /// 标记是否需要在 applyLayout 后执行 reloadData
    private var needsReloadAfterLayout = false
    
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
        props.loadMoreThreshold = json.cgFloat("loadMoreThreshold")
        props.cellTemplate = json.string("cellTemplate")
        
        // estimatedItemHeight 支持数字或表达式
        if let heightValue = json.cgFloat("estimatedItemHeight") {
            props.estimatedItemHeight = heightValue
        } else if let heightExpr = json.string("estimatedItemHeight") {
            props.estimatedItemHeightExpr = heightExpr
        }
        
        // 新增属性解析
        props.rows = json.int("rows")
        props.isPagingEnabled = json.bool("isPagingEnabled", default: false)
        props.itemWidth = json.cgFloat("itemWidth")
        props.itemHeight = json.cgFloat("itemHeight")
        props.items = json.string("items")
        
        // 内容边距
        props.contentInsetLeft = json.cgFloat("contentInsetLeft")
        props.contentInsetRight = json.cgFloat("contentInsetRight")
        props.contentInsetTop = json.cgFloat("contentInsetTop")
        props.contentInsetBottom = json.cgFloat("contentInsetBottom")
        
        // 自动调整高度
        props.autoAdjustHeight = json.bool("autoAdjustHeight", default: false)
        
        return props
    }
    
    override func didParseProps() {
        // 列表默认裁剪
        style.clipsToBounds = true
        
        // 解析 Cell 模板
        if let propsJson = jsonWrapper?.props {
            // 解析内容边距（优先使用单独属性，其次使用 contentInset 对象）
            if props.contentInsetLeft != nil || props.contentInsetRight != nil ||
               props.contentInsetTop != nil || props.contentInsetBottom != nil {
                contentInset = EdgeInsets(
                    top: props.contentInsetTop ?? 0,
                    left: props.contentInsetLeft ?? 0,
                    bottom: props.contentInsetBottom ?? 0,
                    right: props.contentInsetRight ?? 0
                )
            } else {
                contentInset = propsJson.edgeInsets("contentInset")
            }
            
            // Cell 模板 - 支持多种方式
            cellTemplateId = props.cellTemplate
            
            // 优先使用 itemTemplate（新格式）
            if let itemTemplateJson = propsJson.child("itemTemplate") {
                cellTemplate = itemTemplateJson
                TXLogger.debug("[ListComponent] didParseProps: found itemTemplate, keys=\(itemTemplateJson.rawDictionary.keys)")
            }
            // 回退到 cell（旧格式）
            else if let cellJson = propsJson.child("cell") {
                cellTemplate = cellJson
                TXLogger.debug("[ListComponent] didParseProps: found cell template")
            } else {
                TXLogger.warning("[ListComponent] didParseProps: NO cellTemplate found! propsJson.keys=\(propsJson.rawDictionary.keys)")
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
        collectionView.isPagingEnabled = props.isPagingEnabled
        
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
        
        // 如果 dataSource 已经有数据，标记需要在 applyLayout 后 reloadData
        // 此时 frame 还是 (0,0,0,0)，直接 reloadData 不会触发 cellForItemAt
        TXLogger.debug("[ListComponent] createView: id=\(id), dataSource.count=\(self.dataSource.count), cellTemplate=\(cellTemplate != nil), frame=\(collectionView.frame)")
        if !self.dataSource.isEmpty {
            needsReloadAfterLayout = true
            TXLogger.debug("[ListComponent] createView: needsReloadAfterLayout = true")
        }
        
        return collectionView
    }
    
    override func configureView(_ view: SelfSizingCollectionView) {
        view.showsVerticalScrollIndicator = props.showsIndicator && props.scrollDirection == .vertical
        view.showsHorizontalScrollIndicator = props.showsIndicator && props.scrollDirection == .horizontal
        view.bounces = props.bounces
        view.contentInset = contentInset.uiEdgeInsets
        
        // 更新布局参数
        if let layout = view.collectionViewLayout as? VerticalGridFlowLayout {
            // 纵向优先布局
            layout.rows = props.rows ?? 3
            layout.rowSpacing = props.rowSpacing ?? 0
            layout.columnSpacing = props.columnSpacing ?? 0
            // 不设置 sectionInset，边距由 collectionView.contentInset 处理
            layout.isPagingEnabled = props.isPagingEnabled
            
            // 计算 itemSize（需要在布局计算时更新）
            // itemSize 会在 ListDataSource 中计算并设置
            
            // VerticalGridFlowLayout 自己处理分页，禁用系统分页
            view.isPagingEnabled = false
            
            // 分页模式下使用快速减速，让手势更灵敏
            if props.isPagingEnabled {
                view.decelerationRate = .fast
            }
        } else if let layout = view.collectionViewLayout as? UICollectionViewFlowLayout {
            // 标准 FlowLayout
            layout.scrollDirection = props.scrollDirection == .horizontal ? .horizontal : .vertical
            
            // 注意：FlowLayout 的 lineSpacing/interitemSpacing 语义与滚动方向相关
            // - 横向滚动：lineSpacing = 列间距，interitemSpacing = 行间距
            // - 纵向滚动：lineSpacing = 行间距，interitemSpacing = 列间距
            if props.scrollDirection == .horizontal {
                layout.minimumLineSpacing = props.columnSpacing ?? 0
                layout.minimumInteritemSpacing = props.rowSpacing ?? 0
            } else {
                layout.minimumLineSpacing = props.rowSpacing ?? 0
                layout.minimumInteritemSpacing = props.columnSpacing ?? 0
            }
            view.isPagingEnabled = props.isPagingEnabled
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
        
        // frame 设置后，如果有待加载的数据，执行 reloadData
        if needsReloadAfterLayout, let collectionView = collectionView {
            needsReloadAfterLayout = false
            TXLogger.debug("[ListComponent] applyLayout: reloadData after frame set, frame=\(collectionView.frame)")
            collectionView.reloadData()
            // 重置滚动位置到起点（考虑 contentInset）
            collectionView.contentOffset = CGPoint(x: -collectionView.contentInset.left, y: -collectionView.contentInset.top)
        }
    }
    
    // MARK: - Private
    
    private func createCollectionViewLayout() -> UICollectionViewLayout {
        // 横向滚动 + rows 参数 → 使用纵向优先布局
        if props.scrollDirection == .horizontal, let rows = props.rows, rows > 1 {
            let layout = VerticalGridFlowLayout()
            layout.rows = rows
            layout.rowSpacing = props.rowSpacing ?? 0
            layout.columnSpacing = props.columnSpacing ?? 0
            // 不设置 sectionInset，边距由 collectionView.contentInset 处理
            layout.isPagingEnabled = props.isPagingEnabled
            layout.columnsPerPage = 1  // 每页显示 1 列
            return layout
        }
        
        // 默认使用 FlowLayout
        let layout = UICollectionViewFlowLayout()
        
        layout.scrollDirection = props.scrollDirection == .horizontal ? .horizontal : .vertical
        
        // 注意：FlowLayout 的 lineSpacing/interitemSpacing 语义与滚动方向相关
        if props.scrollDirection == .horizontal {
            layout.minimumLineSpacing = props.columnSpacing ?? 0
            layout.minimumInteritemSpacing = props.rowSpacing ?? 0
            
            // 横向滚动：设置初始 itemSize，后续由 sizeForItemAt 更新
            // 优先级：cachedMaxItemHeight > resolvedEstimatedItemHeight > props.itemHeight > props.estimatedItemHeight > 100
            let itemWidth = props.itemWidth ?? 100
            let itemHeight = cachedMaxItemHeight 
                ?? resolvedEstimatedItemHeight 
                ?? props.itemHeight 
                ?? props.estimatedItemHeight 
                ?? 100
            layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            TXLogger.debug("[ListComponent] createLayout: horizontal itemSize=(\(itemWidth), \(itemHeight))")
        } else {
            layout.minimumLineSpacing = props.rowSpacing ?? 0
            layout.minimumInteritemSpacing = props.columnSpacing ?? 0
        }
        
        // 垂直滚动 + 单列：使用预估高度（自动尺寸计算）
        // 横向滚动不使用 estimatedItemSize，由 sizeForItemAt 控制
        if props.scrollDirection == .vertical && (props.columns ?? 1) == 1 {
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
        cloned.resolvedEstimatedItemHeight = self.resolvedEstimatedItemHeight
        // 不复制 cachedMaxItemHeight，让新实例重新计算
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
        let count = component?.dataSource.count ?? 0
        TXLogger.debug("[ListDataSource] numberOfItemsInSection: \(count), component=\(component != nil)")
        return count
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
            
            // 更新 VerticalGridFlowLayout 的 itemSize（只需要设置一次）
            if indexPath.item == 0,
               let layout = collectionView.collectionViewLayout as? VerticalGridFlowLayout {
                layout.itemSize = cellSize
            }
            
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
        let insets = component.contentInset
        
        if component.props.scrollDirection == .vertical {
            // 垂直滚动：根据 columns 计算 itemWidth
            let columns = CGFloat(max(1, component.props.columns ?? 1))
            let totalSpacing = (component.props.columnSpacing ?? 0) * (columns - 1)
            
            var containerWidth = collectionView.bounds.width
            if containerWidth == 0 {
                containerWidth = component.layoutResult.frame.width
            }
            
            // 优先使用固定的 itemWidth，否则根据 columns 计算
            let itemWidth: CGFloat
            if let fixedWidth = component.props.itemWidth {
                itemWidth = fixedWidth
            } else {
                let availableWidth = containerWidth - insets.left - insets.right - totalSpacing
                itemWidth = availableWidth / columns
            }
            
            // 优先使用固定的 itemHeight，否则使用 estimatedItemHeight
            let itemHeight = component.props.itemHeight ?? component.props.estimatedItemHeight ?? 44
            
            return CGSize(width: itemWidth, height: itemHeight)
        } else {
            // 横向滚动：根据 rows 计算 itemHeight
            let rows = CGFloat(max(1, component.props.rows ?? 1))
            let totalSpacing = (component.props.rowSpacing ?? 0) * (rows - 1)
            
            var containerHeight = collectionView.bounds.height
            if containerHeight == 0 {
                containerHeight = component.layoutResult.frame.height
            }
            
            var containerWidth = collectionView.bounds.width
            if containerWidth == 0 {
                containerWidth = component.layoutResult.frame.width
            }
            
            // 优先使用固定的 itemWidth，否则根据容器宽度自动计算
            let itemWidth: CGFloat
            if let fixedWidth = component.props.itemWidth {
                itemWidth = fixedWidth
            } else {
                // 横向滚动时，itemWidth = 容器宽度 - 左右 inset
                // 适用于分页滚动场景，每页显示一列
                itemWidth = containerWidth - insets.left - insets.right
            }
            
            // 优先使用固定的 itemHeight，否则根据 rows 计算
            let itemHeight: CGFloat
            if let fixedHeight = component.props.itemHeight {
                itemHeight = fixedHeight
            } else {
                let availableHeight = containerHeight - insets.top - insets.bottom - totalSpacing
                itemHeight = availableHeight / rows
            }
            
            return CGSize(width: itemWidth, height: itemHeight)
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
            TXLogger.debug("[ListDelegate] sizeForItemAt: component is nil")
            return CGSize(width: 100, height: 100)
        }
        
        TXLogger.debug("[ListDelegate] sizeForItemAt: index=\(indexPath.item), collectionView.bounds=\(collectionView.bounds)")
        
        // VerticalGridFlowLayout 自己管理 itemSize，不需要 delegate
        if let layout = collectionViewLayout as? VerticalGridFlowLayout {
            return layout.itemSize
        }
        
        let itemWidth = calculateItemWidth(collectionView: collectionView, component: component)
        
        // 1. 如果有固定 itemHeight，直接使用
        if let fixedHeight = component.props.itemHeight {
            return CGSize(width: itemWidth, height: fixedHeight)
        }
        
        // 2. 如果有缓存的最大高度，直接使用（横向滚动场景）
        if let cachedMaxHeight = component.cachedMaxItemHeight {
            return CGSize(width: itemWidth, height: cachedMaxHeight)
        }
        
        // 3. 横向滚动列表：计算所有 Cell 的最大高度
        if component.props.scrollDirection == .horizontal,
           let cellTemplate = component.cellTemplate,
           !component.dataSource.isEmpty {
            
            let templateId = component.cellTemplateId ?? "list_cell_\(component.id)"
            var maxHeight: CGFloat = 0
            
            // 遍历所有数据计算高度，取最大值
            for (index, itemData) in component.dataSource.enumerated() {
                var context: [String: Any] = ["item": itemData, "index": index]
                if let dictData = itemData as? [String: Any] {
                    for (key, value) in dictData {
                        context[key] = value
                    }
                }
                
                let height = TemplateXRenderEngine.shared.calculateHeight(
                    json: cellTemplate.rawDictionary,
                    templateId: templateId,
                    data: context,
                    containerWidth: itemWidth,
                    useCache: true
                )
                maxHeight = max(maxHeight, height)
            }
            
            // 缓存最大高度
            if maxHeight > 0 {
                component.cachedMaxItemHeight = maxHeight
                TXLogger.debug("[ListComponent] cachedMaxItemHeight = \(maxHeight)")
                return CGSize(width: itemWidth, height: maxHeight)
            }
        }
        
        // 4. 垂直滚动列表：每个 Cell 独立计算高度
        if component.props.scrollDirection == .vertical,
           let cellTemplate = component.cellTemplate,
           indexPath.item < component.dataSource.count {
            
            // 优先使用预加载管理器的高度缓存
            if let preloadManager = component.preloadManager,
               let cachedHeight = preloadManager.cachedHeight(for: indexPath.item) {
                return CGSize(width: itemWidth, height: cachedHeight)
            }
            
            let itemData = component.dataSource[indexPath.item]
            var context: [String: Any] = ["item": itemData, "index": indexPath.item]
            if let dictData = itemData as? [String: Any] {
                for (key, value) in dictData {
                    context[key] = value
                }
            }
            
            let templateId = component.cellTemplateId ?? "list_cell_\(component.id)"
            let calculatedHeight = TemplateXRenderEngine.shared.calculateHeight(
                json: cellTemplate.rawDictionary,
                templateId: templateId,
                data: context,
                containerWidth: itemWidth,
                useCache: true
            )
            
            if calculatedHeight > 0 {
                return CGSize(width: itemWidth, height: calculatedHeight)
            }
        }
        
        // 5. 回退到预估高度
        let fallbackHeight = component.props.estimatedItemHeight ?? 44
        return CGSize(width: itemWidth, height: fallbackHeight)
    }
    
    private func calculateItemWidth(collectionView: UICollectionView, component: ListComponent) -> CGFloat {
        // 优先使用固定的 itemWidth
        if let fixedWidth = component.props.itemWidth {
            return fixedWidth
        }
        
        let insets = component.contentInset
        
        if component.props.scrollDirection == .vertical {
            // 垂直滚动：根据 columns 计算
            let columns = CGFloat(max(1, component.props.columns ?? 1))
            let totalSpacing = (component.props.columnSpacing ?? 0) * (columns - 1)
            let availableWidth = collectionView.bounds.width - insets.left - insets.right - totalSpacing
            return availableWidth / columns
        } else {
            // 横向滚动：itemWidth = 容器宽度 - 左右 inset（适用于分页滚动）
            return collectionView.bounds.width - insets.left - insets.right
        }
    }
    
    private func calculateItemHeight(collectionView: UICollectionView, component: ListComponent) -> CGFloat {
        // 优先使用固定的 itemHeight
        if let fixedHeight = component.props.itemHeight {
            return fixedHeight
        }
        
        // 根据滚动方向选择正确的参数
        let rowCount: CGFloat
        let spacing: CGFloat
        
        if component.props.scrollDirection == .horizontal {
            // 横向滚动：使用 rows 参数（垂直方向的行数）
            rowCount = CGFloat(max(1, component.props.rows ?? 1))
            spacing = component.props.rowSpacing ?? 0
        } else {
            // 垂直滚动：使用 columns 参数（向后兼容）
            rowCount = CGFloat(max(1, component.props.columns ?? 1))
            spacing = component.props.columnSpacing ?? 0
        }
        
        let totalSpacing = spacing * (rowCount - 1)
        let insets = component.contentInset
        let availableHeight = collectionView.bounds.height - insets.top - insets.bottom - totalSpacing
        let calculatedHeight = availableHeight / rowCount
        
        // 诊断日志
        TXLogger.verbose("[ListComponent] calculateItemHeight: direction=\(component.props.scrollDirection), rows=\(Int(rowCount)), availableHeight=\(availableHeight), spacing=\(totalSpacing) -> itemHeight=\(calculatedHeight)")
        
        return calculatedHeight
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
            } else {
                TXLogger.error("[TemplateXCell] configure FAILED: renderWithCache returned nil, templateId=\(templateId), containerSize=\(containerSize)")
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
