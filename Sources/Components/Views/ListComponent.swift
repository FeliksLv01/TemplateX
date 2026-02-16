import UIKit

// MARK: - List 组件

/// 列表视图组件 - 基于 UICollectionView 实现
/// 支持垂直/水平滚动、Cell 复用、瀑布流布局
public final class ListComponent: BaseComponent, ComponentFactory {
    
    // MARK: - ComponentFactory
    
    public static var typeIdentifier: String { "list" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = ListComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    // MARK: - Properties
    
    /// 滚动方向
    public enum ScrollDirection: String {
        case horizontal
        case vertical
    }
    
    /// 滚动方向
    public var direction: ScrollDirection = .vertical
    
    /// 列数（用于 grid 布局）
    public var columns: Int = 1
    
    /// 行间距
    public var rowSpacing: CGFloat = 0
    
    /// 列间距
    public var columnSpacing: CGFloat = 0
    
    /// 数据源
    public var dataSource: [Any] = [] {
        didSet {
            // 数据变化时自动刷新 CollectionView
            if dataSource.count != oldValue.count || dataSource.count > 0 {
                collectionView?.reloadData()
            }
        }
    }
    
    /// Cell 模板 ID
    public var cellTemplateId: String?
    
    /// Cell 模板 JSON
    public var cellTemplate: JSONWrapper?
    
    /// 是否显示滚动指示器
    public var showsIndicator: Bool = true
    
    /// 是否启用弹性效果
    public var bounces: Bool = true
    
    /// 内容边距
    public var contentInset: EdgeInsets = .zero
    
    /// Cell 固定高度（可选）
    public var estimatedItemHeight: CGFloat = 44
    
    /// Cell 点击事件
    public var onItemClick: ((Int, Any) -> Void)?
    
    /// 滚动事件
    public var onScroll: ((CGPoint) -> Void)?
    
    /// 加载更多
    public var onLoadMore: (() -> Void)?
    
    /// 加载更多阈值（距离底部多少时触发）
    public var loadMoreThreshold: CGFloat = 100
    
    // MARK: - Private
    
    private weak var collectionView: UICollectionView?
    private var listDataSource: ListDataSource?
    private var listDelegate: ListDelegate?
    
    // MARK: - Init
    
    public init(id: String = UUID().uuidString) {
        super.init(id: id, type: ListComponent.typeIdentifier)
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        let cloned = ListComponent(id: self.id)
        cloned.jsonWrapper = self.jsonWrapper
        cloned.style = self.style.clone()
        cloned.events = self.events
        
        // 复制 List 特有属性
        cloned.direction = self.direction
        cloned.columns = self.columns
        cloned.rowSpacing = self.rowSpacing
        cloned.columnSpacing = self.columnSpacing
        cloned.dataSource = self.dataSource
        cloned.cellTemplateId = self.cellTemplateId
        cloned.cellTemplate = self.cellTemplate
        cloned.showsIndicator = self.showsIndicator
        cloned.bounces = self.bounces
        cloned.contentInset = self.contentInset
        cloned.estimatedItemHeight = self.estimatedItemHeight
        cloned.loadMoreThreshold = self.loadMoreThreshold
        
        // 注意: 不在这里递归克隆子组件，由 RenderEngine.cloneComponentTree 统一处理
        
        return cloned
    }
    
    // MARK: - Parse
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
        
        // 列表默认裁剪
        style.clipsToBounds = true
        
        // 解析列表特有属性
        if let props = json.props {
            parseListProps(from: props)
        }
        
        // 解析事件
        if let eventsJson = json.events {
            events = eventsJson.rawDictionary
        }
    }
    
    private func parseListProps(from props: JSONWrapper) {
        if let dir = props.string("direction") {
            direction = ScrollDirection(rawValue: dir.lowercased()) ?? .vertical
        }
        
        columns = props.int("columns") ?? 1
        rowSpacing = props.cgFloat("rowSpacing", default: 0)
        columnSpacing = props.cgFloat("columnSpacing", default: 0)
        
        showsIndicator = props.bool("showsIndicator", default: true)
        bounces = props.bool("bounces", default: true)
        contentInset = props.edgeInsets("contentInset")
        
        if let height = props.cgFloat("estimatedItemHeight") {
            estimatedItemHeight = height
        }
        
        loadMoreThreshold = props.cgFloat("loadMoreThreshold", default: 100)
        
        // Cell 模板 - 支持多种方式
        cellTemplateId = props.string("cellTemplate")
        
        // 优先使用 itemTemplate（新格式）
        if let itemTemplateJson = props.child("itemTemplate") {
            cellTemplate = itemTemplateJson
        }
        // 回退到 cell（旧格式）
        else if let cellJson = props.child("cell") {
            cellTemplate = cellJson
        }
    }
    
    // MARK: - View
    
    public override func createView() -> UIView {
        let layout = createCollectionViewLayout()
        let collectionView = SelfSizingCollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.backgroundColor = style.backgroundColor ?? .clear
        collectionView.showsVerticalScrollIndicator = showsIndicator && direction == .vertical
        collectionView.showsHorizontalScrollIndicator = showsIndicator && direction == .horizontal
        collectionView.bounces = bounces
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
    
    private func createCollectionViewLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        
        layout.scrollDirection = direction == .horizontal ? .horizontal : .vertical
        layout.minimumLineSpacing = rowSpacing
        layout.minimumInteritemSpacing = columnSpacing
        
        // 如果是单列，使用预估高度
        if columns == 1 {
            layout.estimatedItemSize = CGSize(width: UIScreen.main.bounds.width, height: estimatedItemHeight)
        }
        
        return layout
    }
    
    public override func applyLayout() {
        guard let view = view else { return }
        
        var newFrame = layoutResult.frame
        
        // 检查是否是 auto 高度
        let isAutoHeight = style.height.isAuto
        
        if isAutoHeight, let collectionView = view as? UICollectionView {
            // 计算内容高度
            collectionView.layoutIfNeeded()
            let contentHeight = collectionView.contentSize.height + contentInset.top + contentInset.bottom
            
            // 更新 frame 高度
            newFrame.size.height = contentHeight
            
            // 更新 layoutResult（这样父视图可以知道实际高度）
            var updatedResult = layoutResult
            updatedResult.frame = newFrame
            layoutResult = updatedResult
        }
        
        view.frame = newFrame
    }
    
    public override func updateView() {
        guard let collectionView = collectionView else { return }
        
        collectionView.showsVerticalScrollIndicator = showsIndicator && direction == .vertical
        collectionView.showsHorizontalScrollIndicator = showsIndicator && direction == .horizontal
        collectionView.bounces = bounces
        collectionView.contentInset = contentInset.uiEdgeInsets
        
        // 更新布局
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = direction == .horizontal ? .horizontal : .vertical
            layout.minimumLineSpacing = rowSpacing
            layout.minimumInteritemSpacing = columnSpacing
        }
        
        // 处理 auto 高度
        if let selfCollectionView = collectionView as? SelfSizingCollectionView {
            let isAutoHeight = style.height.isAuto
            selfCollectionView.isAutoSizing = isAutoHeight
            
            // auto 高度：禁用滚动；固定高度：启用滚动
            collectionView.isScrollEnabled = !isAutoHeight
        }
        
        super.updateView()
    }
    
    // MARK: - Data
    
    /// 更新数据源
    public func updateData(_ data: [Any]) {
        self.dataSource = data
        collectionView?.reloadData()
    }
    
    /// 插入数据
    public func insertItems(at indices: [Int], data: [Any]) {
        for (i, index) in indices.enumerated() {
            if index <= dataSource.count && i < data.count {
                dataSource.insert(data[i], at: index)
            }
        }
        let indexPaths = indices.map { IndexPath(item: $0, section: 0) }
        collectionView?.insertItems(at: indexPaths)
    }
    
    /// 删除数据
    public func deleteItems(at indices: [Int]) {
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
    public func reloadItems(at indices: [Int]) {
        let indexPaths = indices.map { IndexPath(item: $0, section: 0) }
        collectionView?.reloadItems(at: indexPaths)
    }
    
    /// 滚动到指定位置
    public func scrollToItem(at index: Int, animated: Bool = true) {
        guard index < dataSource.count else { return }
        let indexPath = IndexPath(item: index, section: 0)
        let position: UICollectionView.ScrollPosition = direction == .horizontal ? .centeredHorizontally : .centeredVertically
        collectionView?.scrollToItem(at: indexPath, at: position, animated: animated)
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
            TXLogger.warning("[ListDataSource] cellForItemAt: invalid index \(indexPath.item), dataSource.count = \(component?.dataSource.count ?? 0)")
            return cell
        }
        
        let itemData = component.dataSource[indexPath.item]
        
        // 使用 Cell 模板渲染
        if let cellTemplate = component.cellTemplate {
            
            // 计算 Cell 尺寸
            let cellSize = calculateCellSize(collectionView: collectionView, component: component)
            let templateId = component.cellTemplateId ?? "list_cell_\(component.id)"
            
            cell.configure(
                with: cellTemplate,
                templateId: templateId,
                data: itemData,
                index: indexPath.item,
                containerSize: cellSize
            )
        } else {
            TXLogger.warning("[ListDataSource] cellForItemAt: no cellTemplate found")
        }
        
        return cell
    }
    
    /// 计算 Cell 尺寸
    private func calculateCellSize(collectionView: UICollectionView, component: ListComponent) -> CGSize {
        let columns = CGFloat(max(1, component.columns))
        let totalSpacing = component.columnSpacing * (columns - 1)
        let insets = component.contentInset
        
        if component.direction == .vertical {
            // 优先使用 collectionView 的实际宽度，如果为 0 则使用组件的布局宽度
            var containerWidth = collectionView.bounds.width
            if containerWidth == 0 {
                containerWidth = component.layoutResult.frame.width
            }
            
            let availableWidth = containerWidth - insets.left - insets.right - totalSpacing
            let itemWidth = availableWidth / columns
            
            return CGSize(width: itemWidth, height: component.estimatedItemHeight)
        } else {
            // 优先使用 collectionView 的实际高度，如果为 0 则使用组件的布局高度
            var containerHeight = collectionView.bounds.height
            if containerHeight == 0 {
                containerHeight = component.layoutResult.frame.height
            }
            
            let availableHeight = containerHeight - insets.top - insets.bottom - totalSpacing
            let itemHeight = availableHeight / columns
            return CGSize(width: component.estimatedItemHeight, height: itemHeight)
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
        
        // 检查是否需要加载更多
        checkLoadMore(scrollView)
    }
    
    private func checkLoadMore(_ scrollView: UIScrollView) {
        guard let component = component,
              let onLoadMore = component.onLoadMore,
              !isLoadingMore else { return }
        
        let threshold = component.loadMoreThreshold
        
        if component.direction == .vertical {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.height
            
            if offsetY + frameHeight + threshold >= contentHeight && contentHeight > 0 {
                isLoadingMore = true
                onLoadMore()
                
                // 延迟重置加载状态
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
    
    // MARK: - FlowLayout Delegate
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let component = component else {
            return CGSize(width: 100, height: 100)
        }
        
        // 计算 Cell 宽度
        let itemWidth = calculateItemWidth(collectionView: collectionView, component: component)
        
        // 如果有 Cell 模板，使用 RenderEngine 计算实际高度
        if let cellTemplate = component.cellTemplate,
           indexPath.item < component.dataSource.count {
            
            let itemData = component.dataSource[indexPath.item]
            
            // 准备数据上下文
            var context: [String: Any] = [:]
            if let dictData = itemData as? [String: Any] {
                context = dictData
            } else {
                context["item"] = itemData
            }
            context["index"] = indexPath.item
            
            let templateId = component.cellTemplateId ?? "list_cell_\(component.id)"
            
            // 使用 RenderEngine 计算高度（带缓存）
            let height = RenderEngine.shared.calculateHeight(
                json: cellTemplate.rawDictionary,
                templateId: templateId,
                data: context,
                containerWidth: itemWidth,
                useCache: true
            )
            
            // 确保高度有效
            if height > 0 {
                if component.direction == .vertical {
                    return CGSize(width: itemWidth, height: height)
                } else {
                    return CGSize(width: height, height: itemWidth)
                }
            }
        }
        
        // 回退到预估高度
        if component.direction == .vertical {
            return CGSize(width: itemWidth, height: component.estimatedItemHeight)
        } else {
            let itemHeight = calculateItemHeight(collectionView: collectionView, component: component)
            return CGSize(width: component.estimatedItemHeight, height: itemHeight)
        }
    }
    
    /// 计算 Cell 宽度（垂直滚动时）
    private func calculateItemWidth(collectionView: UICollectionView, component: ListComponent) -> CGFloat {
        let columns = CGFloat(max(1, component.columns))
        let totalSpacing = component.columnSpacing * (columns - 1)
        let insets = component.contentInset
        let availableWidth = collectionView.bounds.width - insets.left - insets.right - totalSpacing
        return availableWidth / columns
    }
    
    /// 计算 Cell 高度（水平滚动时）
    private func calculateItemHeight(collectionView: UICollectionView, component: ListComponent) -> CGFloat {
        let columns = CGFloat(max(1, component.columns))
        let totalSpacing = component.columnSpacing * (columns - 1)
        let insets = component.contentInset
        let availableHeight = collectionView.bounds.height - insets.top - insets.bottom - totalSpacing
        return availableHeight / columns
    }
}

// MARK: - TemplateXCell

/// 模板渲染 Cell
/// 
/// 使用 RenderEngine 进行模板渲染和更新：
/// - 首次渲染：使用 renderWithCache() 创建视图
/// - Cell 复用：使用 quickUpdate() 快速更新数据
public class TemplateXCell: UICollectionViewCell {
    
    public static let reuseIdentifier = "TemplateXCell"
    
    /// 渲染的内容视图
    private var contentRootView: UIView?
    
    /// 当前绑定的模板 ID
    private var currentTemplateId: String?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        contentView.clipsToBounds = true
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        // 注意：不清理 contentRootView，复用时通过 quickUpdate 更新
        // 只有当模板 ID 变化时才需要重新渲染
    }
    
    /// 配置 Cell（完整版本）
    ///
    /// - Parameters:
    ///   - template: 模板 JSON Wrapper
    ///   - templateId: 模板标识符（用于缓存）
    ///   - data: 绑定数据
    ///   - index: 数据索引
    ///   - containerSize: 容器尺寸
    public func configure(
        with template: JSONWrapper,
        templateId: String,
        data: Any,
        index: Int,
        containerSize: CGSize
    ) {
        // 准备数据上下文
        // 注意：无论 data 是什么类型，都需要包装到 "item" 键下
        // 因为模板中的表达式使用 ${item.xxx} 格式
        var context: [String: Any] = [
            "item": data,
            "index": index
        ]
        
        // 检查是否需要重新渲染（模板变化或首次渲染）
        let needsRender = contentRootView == nil || currentTemplateId != templateId
        
        if needsRender {
            // 移除旧视图
            contentRootView?.removeFromSuperview()
            
            // 首次渲染或模板变化：使用缓存渲染
            if let view = RenderEngine.shared.renderWithCache(
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
                TXLogger.error("[TemplateXCell] configure: renderWithCache failed")
            }
        } else {
            // Cell 复用：使用 quickUpdate 快速更新数据
            if let view = contentRootView {
                RenderEngine.shared.quickUpdate(
                    view: view,
                    data: context,
                    containerSize: containerSize
                )
            }
        }
    }
    
    /// 配置 Cell（简化版本，兼容旧 API）
    public func configure(with template: JSONWrapper, data: Any, index: Int) {
        // 使用默认 templateId 和 contentView 的尺寸
        configure(
            with: template,
            templateId: "default_cell_\(template.type ?? "unknown")",
            data: data,
            index: index,
            containerSize: contentView.bounds.size
        )
    }
}

// MARK: - GridLayoutComponent

/// 网格布局组件 - List 的便捷封装
/// 用于固定列数的网格展示
public final class GridComponent: BaseComponent, ComponentFactory {
    
    public static var typeIdentifier: String { "grid" }
    
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = GridComponent(id: id)
        component.jsonWrapper = json
        component.parseFromJSON(json)
        return component
    }
    
    /// 内部使用的 List 组件
    private let listComponent: ListComponent
    
    public init(id: String = UUID().uuidString) {
        listComponent = ListComponent(id: "\(id)_list")
        super.init(id: id, type: GridComponent.typeIdentifier)
    }
    
    // MARK: - Clone
    
    public override func clone() -> Component {
        let cloned = GridComponent(id: self.id)
        cloned.jsonWrapper = self.jsonWrapper
        cloned.style = self.style.clone()
        cloned.events = self.events
        
        // 注意: 不在这里递归克隆子组件，由 RenderEngine.cloneComponentTree 统一处理
        
        return cloned
    }
    
    private func parseFromJSON(_ json: JSONWrapper) {
        // 使用基类的通用解析方法
        parseBaseParams(from: json)
        
        // 解析 Grid 特有属性
        if let props = json.props {
            // Grid 默认垂直滚动，多列
            listComponent.direction = .vertical
            listComponent.columns = props.int("columns") ?? 2
            listComponent.rowSpacing = props.cgFloat("rowSpacing", default: 0)
            listComponent.columnSpacing = props.cgFloat("columnSpacing", default: 0)
        }
    }
    
    public override func createView() -> UIView {
        let view = listComponent.createView()
        self.view = view
        return view
    }
    
    public func updateData(_ data: [Any]) {
        listComponent.updateData(data)
    }
}

// MARK: - SelfSizingCollectionView

/// 自适应内容高度的 UICollectionView
/// 当 isAutoSizing = true 时，根据 contentSize 自动调整自身高度
private class SelfSizingCollectionView: UICollectionView {
    
    /// 是否启用自动尺寸调整
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
