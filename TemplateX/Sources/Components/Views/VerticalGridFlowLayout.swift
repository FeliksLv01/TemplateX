import UIKit

/// 纵向优先网格布局
///
/// 适用于横向滚动的网格布局，item 按纵向优先排列：
/// ```
/// 1  4  7
/// 2  5  8
/// 3  6  9
/// ```
///
/// 配置参数：
/// - `rows`: 垂直方向的行数
/// - `itemSize`: 每个 item 的尺寸
/// - `rowSpacing`: 行间距（垂直方向）
/// - `columnSpacing`: 列间距（水平方向）
/// - `sectionInset`: section 边距
final class VerticalGridFlowLayout: UICollectionViewLayout {
    
    // MARK: - Configuration
    
    /// 垂直方向的行数
    var rows: Int = 3 {
        didSet { invalidateLayout() }
    }
    
    /// 每个 item 的尺寸
    var itemSize: CGSize = CGSize(width: 100, height: 60) {
        didSet { invalidateLayout() }
    }
    
    /// 行间距（垂直方向）
    var rowSpacing: CGFloat = 0 {
        didSet { invalidateLayout() }
    }
    
    /// 列间距（水平方向）
    var columnSpacing: CGFloat = 0 {
        didSet { invalidateLayout() }
    }
    
    /// section 边距
    var sectionInset: UIEdgeInsets = .zero {
        didSet { invalidateLayout() }
    }
    
    /// 是否启用分页（每页显示固定数量的列）
    var isPagingEnabled: Bool = false
    
    /// 每页显示的列数（仅当 isPagingEnabled = true 时有效）
    var columnsPerPage: Int = 1
    
    // MARK: - Cached Layout Attributes
    
    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0
    
    // MARK: - Layout Preparation
    
    override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        
        cachedAttributes.removeAll()
        
        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 0, rows > 0 else { return }
        
        // 计算列数
        let columns = (itemCount + rows - 1) / rows  // 向上取整
        
        // 计算内容尺寸
        // 注意：不包含 sectionInset，边距由 collectionView.contentInset 处理
        contentHeight = collectionView.bounds.height
        contentWidth = CGFloat(columns) * itemSize.width
            + CGFloat(max(0, columns - 1)) * columnSpacing
        
        // 生成每个 item 的布局属性
        for item in 0..<itemCount {
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            
            // 计算该 item 在网格中的位置
            // 纵向优先：先填满一列，再移到下一列
            let column = item / rows
            let row = item % rows
            
            // x/y 从 0 开始，边距由 contentInset 处理
            let x = CGFloat(column) * (itemSize.width + columnSpacing)
            let y = CGFloat(row) * (itemSize.height + rowSpacing)
            
            attributes.frame = CGRect(x: x, y: y, width: itemSize.width, height: itemSize.height)
            cachedAttributes.append(attributes)
        }
    }
    
    // MARK: - Collection View Layout Overrides
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // 返回与 rect 相交的所有 item 的属性
        return cachedAttributes.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cachedAttributes.count else { return nil }
        return cachedAttributes[indexPath.item]
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.size != collectionView.bounds.size
    }
    
    // MARK: - Paging Support
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard isPagingEnabled, columnsPerPage > 0 else {
            return proposedContentOffset
        }
        
        guard let collectionView = collectionView else {
            return proposedContentOffset
        }
        
        // 计算每页宽度（包含列间距）
        let pageWidth = CGFloat(columnsPerPage) * (itemSize.width + columnSpacing)
        
        // 考虑 contentInset 的影响
        let leftInset = collectionView.contentInset.left
        
        // 当前偏移量（相对于内容起点）
        let currentOffsetX = proposedContentOffset.x + leftInset
        
        // 根据速度方向决定翻页
        var targetPage: CGFloat
        if abs(velocity.x) > 0.2 {
            // 有明显速度时，根据速度方向翻页
            let currentPage = currentOffsetX / pageWidth
            if velocity.x > 0 {
                targetPage = ceil(currentPage)
            } else {
                targetPage = floor(currentPage)
            }
        } else {
            // 无明显速度时，吸附到最近的页
            targetPage = round(currentOffsetX / pageWidth)
        }
        
        // 计算总页数
        let itemCount = collectionView.numberOfItems(inSection: 0)
        let totalColumns = (itemCount + rows - 1) / rows
        let totalPages = CGFloat((totalColumns + columnsPerPage - 1) / columnsPerPage)
        
        // 限制页码范围
        targetPage = max(0, min(targetPage, totalPages - 1))
        
        // 返回对齐到页边界的偏移量（减去 leftInset 恢复到 contentOffset 坐标系）
        let targetX = targetPage * pageWidth - leftInset
        
        return CGPoint(x: targetX, y: proposedContentOffset.y)
    }
}
