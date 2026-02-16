import Foundation
import yoga

// MARK: - Yoga C API 桥接层

/// Yoga C API 的 Swift 封装
/// 线程安全：YGNode 操作本身是线程安全的，但需要注意同一棵树不要并发修改
public final class YogaCBridge {
    
    // MARK: - Singleton
    
    public static let shared = YogaCBridge()
    
    private init() {}
    
    // MARK: - Node Creation
    
    /// 创建新节点
    @inlinable
    public func createNode() -> YGNodeRef {
        return YGNodeNew()
    }
    
    /// 创建带配置的节点
    @inlinable
    public func createNode(with config: YGConfigRef) -> YGNodeRef {
        return YGNodeNewWithConfig(config)
    }
    
    /// 释放节点
    @inlinable
    public func freeNode(_ node: YGNodeRef) {
        YGNodeFree(node)
    }
    
    /// 递归释放节点树
    @inlinable
    public func freeNodeRecursive(_ node: YGNodeRef) {
        YGNodeFreeRecursive(node)
    }
    
    /// 重置节点到默认状态
    @inlinable
    public func resetNode(_ node: YGNodeRef) {
        YGNodeReset(node)
    }
    
    // MARK: - Tree Structure
    
    /// 插入子节点
    @inlinable
    public func insertChild(_ child: YGNodeRef, into parent: YGNodeRef, at index: Int) {
        YGNodeInsertChild(parent, child, size_t(index))
    }
    
    /// 移除子节点
    @inlinable
    public func removeChild(_ child: YGNodeRef, from parent: YGNodeRef) {
        YGNodeRemoveChild(parent, child)
    }
    
    /// 移除所有子节点
    @inlinable
    public func removeAllChildren(from node: YGNodeRef) {
        YGNodeRemoveAllChildren(node)
    }
    
    /// 获取子节点
    @inlinable
    public func getChild(_ node: YGNodeRef, at index: Int) -> YGNodeRef? {
        return YGNodeGetChild(node, size_t(index))
    }
    
    /// 获取子节点数量
    @inlinable
    public func getChildCount(_ node: YGNodeRef) -> Int {
        return Int(YGNodeGetChildCount(node))
    }
    
    /// 获取父节点
    @inlinable
    public func getParent(_ node: YGNodeRef) -> YGNodeRef? {
        return YGNodeGetParent(node)
    }
    
    // MARK: - Layout Calculation
    
    /// 计算布局
    @inlinable
    public func calculateLayout(
        _ node: YGNodeRef,
        width: Float,
        height: Float,
        direction: YGDirection = .LTR
    ) {
        YGNodeCalculateLayout(node, width, height, direction)
    }
    
    /// 标记节点为脏（需要重新布局）
    @inlinable
    public func markDirty(_ node: YGNodeRef) {
        YGNodeMarkDirty(node)
    }
    
    /// 节点是否脏
    @inlinable
    public func isDirty(_ node: YGNodeRef) -> Bool {
        return YGNodeIsDirty(node)
    }
    
    // MARK: - Layout Results
    
    /// 获取布局结果 - 左边距
    @inlinable
    public func getLayoutLeft(_ node: YGNodeRef) -> Float {
        return YGNodeLayoutGetLeft(node)
    }
    
    /// 获取布局结果 - 上边距
    @inlinable
    public func getLayoutTop(_ node: YGNodeRef) -> Float {
        return YGNodeLayoutGetTop(node)
    }
    
    /// 获取布局结果 - 宽度
    @inlinable
    public func getLayoutWidth(_ node: YGNodeRef) -> Float {
        return YGNodeLayoutGetWidth(node)
    }
    
    /// 获取布局结果 - 高度
    @inlinable
    public func getLayoutHeight(_ node: YGNodeRef) -> Float {
        return YGNodeLayoutGetHeight(node)
    }
    
    /// 获取完整的布局 Frame
    @inlinable
    public func getLayoutFrame(_ node: YGNodeRef) -> CGRect {
        return CGRect(
            x: CGFloat(YGNodeLayoutGetLeft(node)),
            y: CGFloat(YGNodeLayoutGetTop(node)),
            width: CGFloat(YGNodeLayoutGetWidth(node)),
            height: CGFloat(YGNodeLayoutGetHeight(node))
        )
    }
    
    // MARK: - Style Setters
    
    /// 设置宽度
    @inlinable
    public func setWidth(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetWidth(node, value)
    }
    
    @inlinable
    public func setWidthPercent(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetWidthPercent(node, value)
    }
    
    @inlinable
    public func setWidthAuto(_ node: YGNodeRef) {
        YGNodeStyleSetWidthAuto(node)
    }
    
    /// 设置高度
    @inlinable
    public func setHeight(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetHeight(node, value)
    }
    
    @inlinable
    public func setHeightPercent(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetHeightPercent(node, value)
    }
    
    @inlinable
    public func setHeightAuto(_ node: YGNodeRef) {
        YGNodeStyleSetHeightAuto(node)
    }
    
    /// 设置最小尺寸
    @inlinable
    public func setMinWidth(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetMinWidth(node, value)
    }
    
    @inlinable
    public func setMinHeight(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetMinHeight(node, value)
    }
    
    /// 设置最大尺寸
    @inlinable
    public func setMaxWidth(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetMaxWidth(node, value)
    }
    
    @inlinable
    public func setMaxHeight(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetMaxHeight(node, value)
    }
    
    /// 设置边距
    @inlinable
    public func setMargin(_ node: YGNodeRef, edge: YGEdge, value: Float) {
        YGNodeStyleSetMargin(node, edge, value)
    }
    
    /// 设置内边距
    @inlinable
    public func setPadding(_ node: YGNodeRef, edge: YGEdge, value: Float) {
        YGNodeStyleSetPadding(node, edge, value)
    }
    
    /// 设置 Flex 属性
    @inlinable
    public func setFlexGrow(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetFlexGrow(node, value)
    }
    
    @inlinable
    public func setFlexShrink(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetFlexShrink(node, value)
    }
    
    @inlinable
    public func setFlexBasis(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetFlexBasis(node, value)
    }
    
    @inlinable
    public func setFlexBasisAuto(_ node: YGNodeRef) {
        YGNodeStyleSetFlexBasisAuto(node)
    }
    
    /// 设置 Flex 容器属性
    @inlinable
    public func setFlexDirection(_ node: YGNodeRef, _ value: YGFlexDirection) {
        YGNodeStyleSetFlexDirection(node, value)
    }
    
    @inlinable
    public func setFlexWrap(_ node: YGNodeRef, _ value: YGWrap) {
        YGNodeStyleSetFlexWrap(node, value)
    }
    
    @inlinable
    public func setJustifyContent(_ node: YGNodeRef, _ value: YGJustify) {
        YGNodeStyleSetJustifyContent(node, value)
    }
    
    @inlinable
    public func setAlignItems(_ node: YGNodeRef, _ value: YGAlign) {
        YGNodeStyleSetAlignItems(node, value)
    }
    
    @inlinable
    public func setAlignSelf(_ node: YGNodeRef, _ value: YGAlign) {
        YGNodeStyleSetAlignSelf(node, value)
    }
    
    @inlinable
    public func setAlignContent(_ node: YGNodeRef, _ value: YGAlign) {
        YGNodeStyleSetAlignContent(node, value)
    }
    
    /// 设置定位
    @inlinable
    public func setPositionType(_ node: YGNodeRef, _ value: YGPositionType) {
        YGNodeStyleSetPositionType(node, value)
    }
    
    @inlinable
    public func setPosition(_ node: YGNodeRef, edge: YGEdge, value: Float) {
        YGNodeStyleSetPosition(node, edge, value)
    }
    
    /// 设置显示
    @inlinable
    public func setDisplay(_ node: YGNodeRef, _ value: YGDisplay) {
        YGNodeStyleSetDisplay(node, value)
    }
    
    /// 设置溢出
    @inlinable
    public func setOverflow(_ node: YGNodeRef, _ value: YGOverflow) {
        YGNodeStyleSetOverflow(node, value)
    }
    
    /// 设置宽高比
    @inlinable
    public func setAspectRatio(_ node: YGNodeRef, _ value: Float) {
        YGNodeStyleSetAspectRatio(node, value)
    }
    
    // MARK: - Context
    
    /// 设置上下文（用于关联 Component）
    @inlinable
    public func setContext(_ node: YGNodeRef, _ context: UnsafeMutableRawPointer?) {
        YGNodeSetContext(node, context)
    }
    
    /// 获取上下文
    @inlinable
    public func getContext(_ node: YGNodeRef) -> UnsafeMutableRawPointer? {
        return YGNodeGetContext(node)
    }
    
    // MARK: - Measure Function
    
    /// 设置测量函数（用于文本等需要自定义测量的节点）
    @inlinable
    public func setMeasureFunc(_ node: YGNodeRef, _ func: YGMeasureFunc?) {
        YGNodeSetMeasureFunc(node, `func`)
    }
    
    /// 是否有测量函数
    @inlinable
    public func hasMeasureFunc(_ node: YGNodeRef) -> Bool {
        return YGNodeHasMeasureFunc(node)
    }
}

// MARK: - ComponentStyle to Yoga

extension YogaCBridge {
    
    /// 将 ComponentStyle 应用到 YGNode
    public func applyStyle(_ style: ComponentStyle, to node: YGNodeRef) {
        // === 尺寸 ===
        switch style.width {
        case .auto:
            setWidthAuto(node)
        case .point(let value):
            setWidth(node, Float(value))
        case .percent(let value):
            setWidthPercent(node, Float(value))
        }
        
        switch style.height {
        case .auto:
            setHeightAuto(node)
        case .point(let value):
            setHeight(node, Float(value))
        case .percent(let value):
            setHeightPercent(node, Float(value))
        }
        
        // 最小/最大尺寸
        if style.minWidth > 0 {
            setMinWidth(node, Float(style.minWidth))
        }
        if style.minHeight > 0 {
            setMinHeight(node, Float(style.minHeight))
        }
        if style.maxWidth < .greatestFiniteMagnitude {
            setMaxWidth(node, Float(style.maxWidth))
        }
        if style.maxHeight < .greatestFiniteMagnitude {
            setMaxHeight(node, Float(style.maxHeight))
        }
        
        // === 边距 ===
        setMargin(node, edge: .top, value: Float(style.margin.top))
        setMargin(node, edge: .left, value: Float(style.margin.left))
        setMargin(node, edge: .bottom, value: Float(style.margin.bottom))
        setMargin(node, edge: .right, value: Float(style.margin.right))
        
        setPadding(node, edge: .top, value: Float(style.padding.top))
        setPadding(node, edge: .left, value: Float(style.padding.left))
        setPadding(node, edge: .bottom, value: Float(style.padding.bottom))
        setPadding(node, edge: .right, value: Float(style.padding.right))
        
        // === Flex ===
        setFlexGrow(node, Float(style.flexGrow))
        setFlexShrink(node, Float(style.flexShrink))
        if !style.flexBasis.isNaN {
            setFlexBasis(node, Float(style.flexBasis))
        } else {
            setFlexBasisAuto(node)
        }
        
        // === Flex 容器 ===
        setFlexDirection(node, style.flexDirection.ygValue)
        setFlexWrap(node, style.flexWrap.ygValue)
        setJustifyContent(node, style.justifyContent.ygValue)
        setAlignItems(node, style.alignItems.ygValue)
        setAlignSelf(node, style.alignSelf.ygValue)
        setAlignContent(node, style.alignContent.ygValue)
        
        // === 定位 ===
        setPositionType(node, style.positionType.ygValue)
        if style.positionType == .absolute {
            if style.position.top != 0 {
                setPosition(node, edge: .top, value: Float(style.position.top))
            }
            if style.position.left != 0 {
                setPosition(node, edge: .left, value: Float(style.position.left))
            }
            if style.position.bottom != 0 {
                setPosition(node, edge: .bottom, value: Float(style.position.bottom))
            }
            if style.position.right != 0 {
                setPosition(node, edge: .right, value: Float(style.position.right))
            }
        }
        
        // === 显示 ===
        setDisplay(node, style.display.ygValue)
        setOverflow(node, style.overflow.ygValue)
        
        // === 宽高比 ===
        if !style.aspectRatio.isNaN {
            setAspectRatio(node, Float(style.aspectRatio))
        }
    }
}

// MARK: - Yoga Enum Conversions

extension FlexDirection {
    var ygValue: YGFlexDirection {
        switch self {
        case .row: return .row
        case .rowReverse: return .rowReverse
        case .column: return .column
        case .columnReverse: return .columnReverse
        }
    }
}

extension FlexWrap {
    var ygValue: YGWrap {
        switch self {
        case .noWrap: return .noWrap
        case .wrap: return .wrap
        case .wrapReverse: return .wrapReverse
        }
    }
}

extension JustifyContent {
    var ygValue: YGJustify {
        switch self {
        case .flexStart: return .flexStart
        case .flexEnd: return .flexEnd
        case .center: return .center
        case .spaceBetween: return .spaceBetween
        case .spaceAround: return .spaceAround
        case .spaceEvenly: return .spaceEvenly
        }
    }
}

extension AlignItems {
    var ygValue: YGAlign {
        switch self {
        case .flexStart: return .flexStart
        case .flexEnd: return .flexEnd
        case .center: return .center
        case .stretch: return .stretch
        case .baseline: return .baseline
        }
    }
}

extension AlignSelf {
    var ygValue: YGAlign {
        switch self {
        case .auto: return .auto
        case .flexStart: return .flexStart
        case .flexEnd: return .flexEnd
        case .center: return .center
        case .stretch: return .stretch
        case .baseline: return .baseline
        }
    }
}

extension AlignContent {
    var ygValue: YGAlign {
        switch self {
        case .flexStart: return .flexStart
        case .flexEnd: return .flexEnd
        case .center: return .center
        case .stretch: return .stretch
        case .spaceBetween: return .spaceBetween
        case .spaceAround: return .spaceAround
        }
    }
}

extension PositionType {
    var ygValue: YGPositionType {
        switch self {
        case .relative: return .relative
        case .absolute: return .absolute
        }
    }
}

extension Display {
    var ygValue: YGDisplay {
        switch self {
        case .flex: return .flex
        case .none: return .none
        }
    }
}

extension Overflow {
    var ygValue: YGOverflow {
        switch self {
        case .visible: return .visible
        case .hidden: return .hidden
        case .scroll: return .scroll
        }
    }
}
