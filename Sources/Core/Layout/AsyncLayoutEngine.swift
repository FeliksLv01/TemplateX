import Foundation
import yoga

// MARK: - 异步布局引擎

/// 异步 Yoga 布局引擎
/// 使用 Yoga C API 在子线程计算布局，避免阻塞主线程
public final class AsyncLayoutEngine {
    
    // MARK: - Singleton
    
    public static let shared = AsyncLayoutEngine()
    
    // MARK: - Dependencies
    
    private let bridge = YogaCBridge.shared
    private let nodePool = YogaNodePool.shared
    
    // MARK: - Layout Queue
    
    /// 专用布局队列（串行，避免同一棵树并发问题）
    private let layoutQueue = DispatchQueue(
        label: "com.templatex.layout",
        qos: .userInitiated
    )
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API (同步)
    
    /// 同步计算布局（在当前线程）
    /// 适用于简单场景或已在子线程调用
    public func calculateLayoutSync(
        for component: Component,
        containerSize: CGSize
    ) -> [String: LayoutResult] {
        // 1. 构建 YGNode 树
        var nodeMap: [String: YGNodeRef] = [:]
        let rootNode = buildYogaTree(component: component, nodeMap: &nodeMap)
        
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
        
        // 4. 释放节点树
        nodePool.releaseTree(rootNode)
        
        return results
    }
    
    // MARK: - Public API (异步)
    
    /// 异步计算布局（在子线程）
    /// - Parameters:
    ///   - component: 组件树（必须在主线程传入，内部会复制必要数据）
    ///   - containerSize: 容器尺寸
    ///   - completion: 完成回调（在主线程调用）
    public func calculateLayoutAsync(
        for component: Component,
        containerSize: CGSize,
        completion: @escaping ([String: LayoutResult]) -> Void
    ) {
        // 在主线程提取布局数据
        let layoutData = extractLayoutData(from: component)
        
        // 切换到布局队列
        layoutQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. 构建 YGNode 树
            var nodeMap: [String: YGNodeRef] = [:]
            let rootNode = self.buildYogaTreeFromData(layoutData, nodeMap: &nodeMap)
            
            // 2. 计算布局
            self.bridge.calculateLayout(
                rootNode,
                width: Float(containerSize.width),
                height: containerSize.height.isNaN ? Float.nan : Float(containerSize.height),
                direction: .LTR
            )
            
            // 3. 收集结果
            var results: [String: LayoutResult] = [:]
            self.collectLayoutResultsFromData(layoutData, nodeMap: nodeMap, results: &results)
            
            // 4. 释放节点树
            self.nodePool.releaseTree(rootNode)
            
            // 5. 回调主线程
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
    
    // MARK: - Batch API
    
    /// 批量异步计算布局（多棵树并行）
    public func calculateLayoutBatchAsync(
        components: [(component: Component, containerSize: CGSize)],
        completion: @escaping ([[String: LayoutResult]]) -> Void
    ) {
        // 提取所有布局数据
        let layoutDataList = components.map { (extractLayoutData(from: $0.component), $0.containerSize) }
        
        layoutQueue.async { [weak self] in
            guard let self = self else { return }
            
            var allResults: [[String: LayoutResult]] = []
            
            for (layoutData, containerSize) in layoutDataList {
                var nodeMap: [String: YGNodeRef] = [:]
                let rootNode = self.buildYogaTreeFromData(layoutData, nodeMap: &nodeMap)
                
                self.bridge.calculateLayout(
                    rootNode,
                    width: Float(containerSize.width),
                    height: containerSize.height.isNaN ? Float.nan : Float(containerSize.height),
                    direction: .LTR
                )
                
                var results: [String: LayoutResult] = [:]
                self.collectLayoutResultsFromData(layoutData, nodeMap: nodeMap, results: &results)
                
                self.nodePool.releaseTree(rootNode)
                allResults.append(results)
            }
            
            DispatchQueue.main.async {
                completion(allResults)
            }
        }
    }
    
    // MARK: - 预热
    
    /// 预热布局引擎（预创建节点池）
    public func warmUp(nodeCount: Int = 64) {
        nodePool.warmUp(count: nodeCount)
    }
    
    // MARK: - Private: 构建 Yoga 树
    
    /// 从 Component 构建 YGNode 树
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
    
    /// 从布局数据构建 YGNode 树（线程安全版本）
    private func buildYogaTreeFromData(
        _ data: LayoutData,
        nodeMap: inout [String: YGNodeRef]
    ) -> YGNodeRef {
        let node = nodePool.acquire()
        nodeMap[data.id] = node
        
        // 应用样式
        bridge.applyStyle(data.style, to: node)
        
        // 设置文本测量函数
        if let textData = data.textData {
            setupTextMeasureFuncFromData(node: node, textData: textData)
        }
        
        // 递归构建子节点
        for (index, childData) in data.children.enumerated() {
            let childNode = buildYogaTreeFromData(childData, nodeMap: &nodeMap)
            bridge.insertChild(childNode, into: node, at: index)
        }
        
        return node
    }
    
    // MARK: - Private: 文本测量
    
    /// 设置文本测量函数
    private func setupTextMeasureFunc(node: YGNodeRef, textComponent: TextComponent) {
        let context = TextMeasureContext(
            text: textComponent.text,
            fontSize: textComponent.fontSize,
            fontWeight: textComponent.fontWeight,
            lineHeight: textComponent.lineHeight,
            letterSpacing: textComponent.letterSpacing,
            numberOfLines: textComponent.numberOfLines
        )
        
        // 使用 Unmanaged 传递上下文
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        bridge.setContext(node, contextPtr)
        bridge.setMeasureFunc(node, textMeasureFunc)
    }
    
    /// 从数据设置文本测量函数
    private func setupTextMeasureFuncFromData(node: YGNodeRef, textData: TextLayoutData) {
        let context = TextMeasureContext(
            text: textData.text,
            fontSize: textData.fontSize,
            fontWeight: textData.fontWeight,
            lineHeight: textData.lineHeight,
            letterSpacing: textData.letterSpacing,
            numberOfLines: textData.numberOfLines
        )
        
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        bridge.setContext(node, contextPtr)
        bridge.setMeasureFunc(node, textMeasureFunc)
    }
    
    // MARK: - Private: 收集结果
    
    /// 收集布局结果
    private func collectLayoutResults(
        component: Component,
        nodeMap: [String: YGNodeRef],
        results: inout [String: LayoutResult]
    ) {
        guard let node = nodeMap[component.id] else { return }
        
        // 释放测量上下文
        if let contextPtr = bridge.getContext(node) {
            Unmanaged<TextMeasureContext>.fromOpaque(contextPtr).release()
            bridge.setContext(node, nil)
        }
        
        var result = LayoutResult()
        result.frame = bridge.getLayoutFrame(node)
        results[component.id] = result
        
        for child in component.children {
            collectLayoutResults(component: child, nodeMap: nodeMap, results: &results)
        }
    }
    
    /// 从布局数据收集结果
    private func collectLayoutResultsFromData(
        _ data: LayoutData,
        nodeMap: [String: YGNodeRef],
        results: inout [String: LayoutResult]
    ) {
        guard let node = nodeMap[data.id] else { return }
        
        // 释放测量上下文
        if let contextPtr = bridge.getContext(node) {
            Unmanaged<TextMeasureContext>.fromOpaque(contextPtr).release()
            bridge.setContext(node, nil)
        }
        
        var result = LayoutResult()
        result.frame = bridge.getLayoutFrame(node)
        results[data.id] = result
        
        for childData in data.children {
            collectLayoutResultsFromData(childData, nodeMap: nodeMap, results: &results)
        }
    }
    
    // MARK: - Private: 布局数据提取
    
    /// 从组件提取布局数据（线程安全的值类型）
    private func extractLayoutData(from component: Component) -> LayoutData {
        var textData: TextLayoutData?
        
        if let textComponent = component as? TextComponent {
            textData = TextLayoutData(
                text: textComponent.text,
                fontSize: textComponent.fontSize,
                fontWeight: textComponent.fontWeight,
                lineHeight: textComponent.lineHeight,
                letterSpacing: textComponent.letterSpacing,
                numberOfLines: textComponent.numberOfLines
            )
        }
        
        return LayoutData(
            id: component.id,
            style: component.style,
            textData: textData,
            children: component.children.map { extractLayoutData(from: $0) }
        )
    }
}

// MARK: - 布局数据（值类型，线程安全）

/// 布局数据 - 从 Component 提取的纯数据
private struct LayoutData {
    let id: String
    let style: ComponentStyle
    let textData: TextLayoutData?
    let children: [LayoutData]
}

/// 文本布局数据
private struct TextLayoutData {
    let text: String
    let fontSize: CGFloat
    let fontWeight: UIFont.Weight
    let lineHeight: CGFloat?
    let letterSpacing: CGFloat?
    let numberOfLines: Int
}

/// 文本测量数据（用于传递给 C 回调）
final class TextMeasureContext {
    let text: String
    let fontSize: CGFloat
    let fontWeight: UIFont.Weight
    let lineHeight: CGFloat?
    let letterSpacing: CGFloat?
    let numberOfLines: Int
    
    init(text: String, fontSize: CGFloat, fontWeight: UIFont.Weight,
         lineHeight: CGFloat?, letterSpacing: CGFloat?, numberOfLines: Int) {
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.numberOfLines = numberOfLines
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
    let size = measureText(
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
private func measureText(
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
