import UIKit
import yoga

// MARK: - Yoga 布局引擎

/// Yoga 布局引擎封装（基于 Yoga C API）
/// 设计目标：
/// 1. 直接使用 Yoga C API，支持子线程调用
/// 2. 从统一的 ComponentStyle 读取布局属性
/// 3. 支持 CSS display 和 visibility 语义
/// 4. 使用节点池优化内存分配
/// 5. 支持增量布局（Yoga 剪枝优化）
public final class YogaLayoutEngine {
    
    // MARK: - 单例
    
    public static let shared = YogaLayoutEngine()
    
    // MARK: - 依赖
    
    private let bridge = YogaCBridge.shared
    private let nodePool = YogaNodePool.shared
    
    // MARK: - 配置
    
    /// 是否启用增量布局优化
    /// 开启后会复用组件上缓存的 YGNode，只在样式变化时重新计算
    public var enableIncrementalLayout: Bool = true
    
    private init() {}
    
    // MARK: - 布局计算
    
    /// 计算布局（使用 Yoga C API，可在任意线程调用）
    /// 
    /// 支持两种模式：
    /// 1. 增量布局（enableIncrementalLayout = true）：复用组件上的 YGNode，样式变化时标记 dirty
    /// 2. 全量布局（enableIncrementalLayout = false）：每次重建 YGNode 树
    ///
    /// - Parameters:
    ///   - component: 根组件
    ///   - containerSize: 容器尺寸
    /// - Returns: 布局结果映射 [组件ID: LayoutResult]
    public func calculateLayout(
        for component: Component,
        containerSize: CGSize
    ) -> [String: LayoutResult] {
        
        // 1. 构建或更新 YGNode 树
        let rootNode: YGNodeRef
        var nodeMap: [String: YGNodeRef] = [:]
        
        if enableIncrementalLayout {
            // 增量模式：复用组件上的 YGNode
            rootNode = buildOrUpdateYogaTree(component: component, nodeMap: &nodeMap)
        } else {
            // 全量模式：每次重建
            rootNode = buildYogaTree(component: component, nodeMap: &nodeMap)
        }
        
        // 2. 计算布局
        bridge.calculateLayout(
            rootNode,
            width: Float(containerSize.width),
            height: containerSize.height.isNaN ? Float.nan : Float(containerSize.height),
            direction: .LTR
        )
        
        // 3. 收集结果
        var results: [String: LayoutResult] = [:]
        collectLayoutResults(component: component, nodeMap: nodeMap, results: &results)
        
        // 4. 增量模式下不释放节点树（保留给下次复用）
        //    全量模式下释放节点树
        if !enableIncrementalLayout {
            nodePool.releaseTree(rootNode)
        }
                
        return results
    }
    
    /// 直接在目标视图上应用布局（主线程调用）
    /// - Parameters:
    ///   - component: 组件
    ///   - view: 已绑定的视图
    ///   - containerSize: 容器尺寸
    public func applyLayout(
        for component: Component,
        to view: UIView,
        containerSize: CGSize
    ) {
        let results = calculateLayout(for: component, containerSize: containerSize)
        applyLayoutResults(results, to: component, view: view)
    }
    
    // MARK: - 增量布局（Yoga 剪枝优化核心）
    
    /// 构建或更新 Yoga 树（增量模式）
    ///
    /// 增量布局的核心思路：
    /// 1. 如果组件已有 yogaNode，检查样式是否变化
    /// 2. 样式变化时才重新设置 Yoga 属性并标记 dirty
    /// 3. Yoga 内部会跳过 clean 节点的布局计算
    ///
    /// - Parameters:
    ///   - component: 组件
    ///   - nodeMap: 节点映射表（输出参数）
    /// - Returns: 根节点
    private func buildOrUpdateYogaTree(
        component: Component,
        nodeMap: inout [String: YGNodeRef]
    ) -> YGNodeRef {
        // 使用栈模拟递归，避免深层递归栈溢出
        // 采用两阶段处理：先遍历创建/获取节点，再反向建立父子关系
        
        struct StackItem {
            let component: Component
            let parentNode: YGNodeRef?
            let childIndex: Int
        }
        
        var stack: [StackItem] = [StackItem(component: component, parentNode: nil, childIndex: 0)]
        
        while let item = stack.popLast() {
            let comp = item.component
            
            // 获取或创建 YGNode
            let node: YGNodeRef
            let isTextNode = comp is TextComponent  // 只有 Text 节点有 measure 函数
            
            if let existingNode = comp.yogaNode {
                // 已有节点：检查样式是否变化
                node = existingNode
                
                if let lastStyle = comp.lastLayoutStyle {
                    // 检查样式是否变化
                    if lastStyle != comp.style {
                        // 样式变化：重新应用并标记 dirty
                        bridge.applyStyle(comp.style, to: node)
                        comp.lastLayoutStyle = comp.style
                        
                        // 只对叶子节点（TextComponent）标记 dirty
                        // 容器节点的样式变化会在下次 calculateLayout 时自动检测
                        if isTextNode {
                            bridge.markDirty(node)
                        }
                    }
                    // 样式未变化，节点保持 clean 状态，Yoga 会跳过
                } else {
                    // 首次应用样式
                    bridge.applyStyle(comp.style, to: node)
                    comp.lastLayoutStyle = comp.style
                }
            } else {
                // 新节点
                node = nodePool.acquire()
                comp.yogaNode = node
                bridge.applyStyle(comp.style, to: node)
                comp.lastLayoutStyle = comp.style
            }
            
            nodeMap[comp.id] = node
            
            // 设置文本测量函数
            if let textComponent = comp as? TextComponent {
                setupTextMeasureFunc(node: node, textComponent: textComponent)
            }
            
            // 建立父子关系
            if let parentNode = item.parentNode {
                // 检查是否已经是正确的父子关系
                let currentChildCount = Int(YGNodeGetChildCount(parentNode))
                if item.childIndex < currentChildCount {
                    // 位置已有节点，检查是否是同一个
                    if let existingChild = YGNodeGetChild(parentNode, size_t(item.childIndex)), existingChild == node {
                        // 已经是正确的父子关系，跳过
                    } else {
                        // 不同节点，需要替换
                        // 先移除旧节点（如果有）
                        if let existingChild = YGNodeGetChild(parentNode, size_t(item.childIndex)) {
                            bridge.removeChild(existingChild, from: parentNode)
                        }
                        bridge.insertChild(node, into: parentNode, at: item.childIndex)
                    }
                } else {
                    // 新增子节点
                    bridge.insertChild(node, into: parentNode, at: item.childIndex)
                }
            }
            
            // 子组件入栈（逆序，保证正确的处理顺序）
            for (index, child) in comp.children.enumerated().reversed() {
                stack.append(StackItem(component: child, parentNode: node, childIndex: index))
            }
            
            // 清理多余的子节点（当子组件数量减少时）
            let currentChildCount = Int(YGNodeGetChildCount(node))
            if currentChildCount > comp.children.count {
                for i in (comp.children.count..<currentChildCount).reversed() {
                    if let childToRemove = YGNodeGetChild(node, size_t(i)) {
                        bridge.removeChild(childToRemove, from: node)
                    }
                }
            }
        }
        
        return component.yogaNode!
    }
    
    // MARK: - 全量构建 Yoga 树（原有逻辑，作为 fallback）
    
    private func buildYogaTree(
        component: Component,
        nodeMap: inout [String: YGNodeRef]
    ) -> YGNodeRef {
        let node = nodePool.acquire()
        nodeMap[component.id] = node
        
        // 应用样式
        bridge.applyStyle(component.style, to: node)
        
        // 设置文本测量函数
        if let textComponent = component as? TextComponent {
            setupTextMeasureFunc(node: node, textComponent: textComponent)
        }
        
        // 递归构建子节点
        for (index, child) in component.children.enumerated() {
            let childNode = buildYogaTree(component: child, nodeMap: &nodeMap)
            bridge.insertChild(childNode, into: node, at: index)
        }
        
        return node
    }
    
    // MARK: - 文本测量
    
    private func setupTextMeasureFunc(node: YGNodeRef, textComponent: TextComponent) {
        let context = TextMeasureContext(
            text: textComponent.text,
            fontSize: textComponent.fontSize ?? textComponent.style.fontSize ?? 14,
            fontWeight: parseFontWeight(textComponent.fontWeight ?? textComponent.style.fontWeight),
            lineHeight: textComponent.lineHeight,
            letterSpacing: textComponent.letterSpacing,
            numberOfLines: textComponent.numberOfLines
        )
        
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        bridge.setContext(node, contextPtr)
        bridge.setMeasureFunc(node, textMeasureFunc)
    }
    
    /// 解析字体粗细字符串为 UIFont.Weight
    private func parseFontWeight(_ weight: String?) -> UIFont.Weight {
        guard let weight = weight else { return .regular }
        switch weight.lowercased() {
        case "thin", "100": return .thin
        case "ultralight", "200": return .ultraLight
        case "light", "300": return .light
        case "regular", "normal", "400": return .regular
        case "medium", "500": return .medium
        case "semibold", "600": return .semibold
        case "bold", "700": return .bold
        case "heavy", "800": return .heavy
        case "black", "900": return .black
        default: return .regular
        }
    }
    
    // MARK: - 收集结果
    
    /// 收集布局结果
    /// 
    /// 注意：在全量模式下会释放文本测量上下文
    /// 增量模式下上下文会在 releaseYogaNode 时释放
    private func collectLayoutResults(
        component: Component,
        nodeMap: [String: YGNodeRef],
        results: inout [String: LayoutResult]
    ) {
        guard let node = nodeMap[component.id] else { return }
        
        // 全量模式下释放测量上下文
        // 增量模式下保留上下文，在 releaseYogaNode 时释放
        if !enableIncrementalLayout {
            if let contextPtr = bridge.getContext(node) {
                Unmanaged<TextMeasureContext>.fromOpaque(contextPtr).release()
                bridge.setContext(node, nil)
            }
        }
        
        var result = LayoutResult()
        result.frame = bridge.getLayoutFrame(node)
        results[component.id] = result
        
        
        for child in component.children {
            collectLayoutResults(component: child, nodeMap: nodeMap, results: &results)
        }
    }
    
    // MARK: - 应用布局结果到视图
    
    private func applyLayoutResults(
        _ results: [String: LayoutResult],
        to component: Component,
        view: UIView
    ) {
        if let result = results[component.id] {
            view.frame = result.frame
        }
        
        // 递归应用到子视图
        for (index, child) in component.children.enumerated() {
            if index < view.subviews.count {
                applyLayoutResults(results, to: child, view: view.subviews[index])
            }
        }
    }
    
    // MARK: - 预热
    
    /// 预热布局引擎（预创建节点池）
    public func warmUp(nodeCount: Int = 64) {
        nodePool.warmUp(count: nodeCount)
    }
    
    // MARK: - Yoga 节点清理
    
    /// 释放组件树上的所有 YGNode（递归）
    /// 
    /// 用于组件回收或销毁时清理 Yoga 节点
    /// 会同时释放文本测量上下文
    ///
    /// - Parameter component: 根组件
    public func releaseYogaNodes(for component: Component) {
        // 使用栈模拟递归，避免深层递归
        var stack: [Component] = [component]
        
        while let comp = stack.popLast() {
            // 释放当前节点
            if let node = comp.yogaNode {
                // 释放文本测量上下文（如果有）
                if let contextPtr = bridge.getContext(node) {
                    Unmanaged<TextMeasureContext>.fromOpaque(contextPtr).release()
                    bridge.setContext(node, nil)
                }
                
                nodePool.release(node)
                comp.yogaNode = nil
            }
            comp.lastLayoutStyle = nil
            
            // 子组件入栈
            stack.append(contentsOf: comp.children)
        }
    }
}

// MARK: - 文本测量函数（C 回调）

/// 文本测量 C 函数
private let textMeasureFunc: YGMeasureFunc = { node, width, widthMode, height, heightMode in
    guard let node = node,
          let contextPtr = YGNodeGetContext(node) else {
        return YGSize(width: 0, height: 0)
    }
    
    let context = Unmanaged<TextMeasureContext>.fromOpaque(contextPtr).takeUnretainedValue()
    
    // 确定宽度约束
    let maxWidth: CGFloat
    switch widthMode {
    case .exactly:
        maxWidth = CGFloat(width)
    case .atMost:
        maxWidth = CGFloat(width)
    case .undefined:
        maxWidth = .greatestFiniteMagnitude
    @unknown default:
        maxWidth = .greatestFiniteMagnitude
    }
    
    // 计算文本尺寸
    let size = measureTextSize(
        text: context.text,
        fontSize: context.fontSize,
        fontWeight: context.fontWeight,
        lineHeight: context.lineHeight,
        letterSpacing: context.letterSpacing,
        numberOfLines: context.numberOfLines,
        maxWidth: maxWidth
    )
    
    return YGSize(width: Float(size.width), height: Float(size.height))
}

/// 文本测量（线程安全）
private func measureTextSize(
    text: String,
    fontSize: CGFloat,
    fontWeight: UIFont.Weight,
    lineHeight: CGFloat?,
    letterSpacing: CGFloat?,
    numberOfLines: Int,
    maxWidth: CGFloat
) -> CGSize {
    guard !text.isEmpty else { return .zero }
    
    let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
    
    var attributes: [NSAttributedString.Key: Any] = [.font: font]
    
    if let lineHeight = lineHeight {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        attributes[.paragraphStyle] = paragraphStyle
    }
    
    if let letterSpacing = letterSpacing {
        attributes[.kern] = letterSpacing
    }
    
    let constraintSize = CGSize(
        width: maxWidth,
        height: .greatestFiniteMagnitude
    )
    
    let boundingRect = (text as NSString).boundingRect(
        with: constraintSize,
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attributes,
        context: nil
    )
    
    var resultHeight = ceil(boundingRect.height)
    
    // 处理行数限制
    if numberOfLines > 0 {
        let singleLineHeight = lineHeight ?? font.lineHeight
        let maxHeight = singleLineHeight * CGFloat(numberOfLines)
        resultHeight = min(resultHeight, maxHeight)
    }
    
    return CGSize(width: ceil(boundingRect.width), height: resultHeight)
}

// MARK: - Yoga 枚举转换（为了兼容旧代码，保留 yogaValue 扩展）

extension FlexDirection {
    var yogaValue: YGFlexDirection {
        return ygValue
    }
}

extension FlexWrap {
    var yogaValue: YGWrap {
        return ygValue
    }
}

extension JustifyContent {
    var yogaValue: YGJustify {
        return ygValue
    }
}

extension AlignItems {
    var yogaValue: YGAlign {
        return ygValue
    }
}

extension AlignSelf {
    var yogaValue: YGAlign {
        return ygValue
    }
}

extension AlignContent {
    var yogaValue: YGAlign {
        return ygValue
    }
}

extension PositionType {
    var yogaValue: YGPositionType {
        return ygValue
    }
}

extension Display {
    var yogaValue: YGDisplay {
        return ygValue
    }
}

extension Overflow {
    var yogaValue: YGOverflow {
        return ygValue
    }
}
