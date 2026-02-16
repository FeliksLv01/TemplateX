import UIKit

// MARK: - Diff 补丁器

/// Diff 结果应用器
/// 将 DiffResult 中的操作应用到实际的组件树和视图树
public final class DiffPatcher {
    
    // MARK: - 单例
    
    public static let shared = DiffPatcher()
    
    // MARK: - 依赖
    
    private let viewRecyclePool = ViewRecyclePool.shared
    private let layoutEngine = YogaLayoutEngine.shared
    
    // MARK: - 配置
    
    public struct Config {
        /// 是否启用视图复用
        public var enableViewRecycle: Bool = true
        
        /// 是否启用动画
        public var enableAnimation: Bool = false
        
        /// 动画时长
        public var animationDuration: TimeInterval = 0.25
        
        public init() {}
    }
    
    public var config = Config()
    
    private init() {}
    
    // MARK: - Public API
    
    /// 应用 Diff 结果
    /// - Parameters:
    ///   - diffResult: Diff 结果
    ///   - rootComponent: 根组件（当前组件树）
    ///   - rootView: 根视图
    ///   - containerSize: 容器尺寸（用于重新布局）
    public func apply(
        _ diffResult: DiffResult,
        to rootComponent: Component,
        rootView: UIView,
        containerSize: CGSize
    ) {
        guard diffResult.hasDiff else { return }
        
        // 建立组件索引
        var componentIndex = buildComponentIndex(rootComponent)
        var viewIndex = buildViewIndex(rootView)
        
        // 按顺序执行操作
        // 注意：删除操作需要最后执行，以避免索引失效
        var deleteOperations: [DiffOperation] = []
        var otherOperations: [DiffOperation] = []
        
        for operation in diffResult.operations {
            switch operation {
            case .delete:
                deleteOperations.append(operation)
            default:
                otherOperations.append(operation)
            }
        }
        
        // 先执行非删除操作（只修改组件树和创建视图，不计算布局）
        for operation in otherOperations {
            applyOperation(
                operation,
                componentIndex: &componentIndex,
                viewIndex: &viewIndex,
                skipLayout: true
            )
        }
        
        // 最后执行删除操作（从后向前删除）
        for operation in deleteOperations.reversed() {
            applyOperation(
                operation,
                componentIndex: &componentIndex,
                viewIndex: &viewIndex,
                skipLayout: true
            )
        }
        
        // 所有操作完成后，统一重新计算整个根组件的布局
        let layoutResults = layoutEngine.calculateLayout(for: rootComponent, containerSize: containerSize)
        applyLayoutResults(layoutResults, to: rootComponent)
        
        // 更新整个视图树
        updateViewTree(rootComponent)
    }
    
    /// 快速更新：只更新数据绑定，不改变结构
    /// - Parameters:
    ///   - data: 新数据
    ///   - component: 组件
    ///   - containerSize: 容器尺寸
    public func quickUpdate(
        data: [String: Any],
        to component: Component,
        containerSize: CGSize
    ) {
        // 更新绑定
        DataBindingManager.shared.bind(data: data, to: component)
        
        // 重新计算布局
        let layoutResults = layoutEngine.calculateLayout(for: component, containerSize: containerSize)
        applyLayoutResults(layoutResults, to: component)
        
        // 更新视图
        updateViewTree(component)
    }
    
    // MARK: - Private: 操作应用
    
    private func applyOperation(
        _ operation: DiffOperation,
        componentIndex: inout [String: Component],
        viewIndex: inout [String: UIView],
        skipLayout: Bool = false
    ) {
        switch operation {
        case .insert(let component, let index, let parentId):
            applyInsert(
                component: component,
                index: index,
                parentId: parentId,
                componentIndex: &componentIndex,
                viewIndex: &viewIndex
            )
            
        case .delete(let componentId, let parentId):
            applyDelete(
                componentId: componentId,
                parentId: parentId,
                componentIndex: &componentIndex,
                viewIndex: &viewIndex
            )
            
        case .update(let componentId, let newComponent, let changes):
            applyUpdate(
                componentId: componentId,
                newComponent: newComponent,
                changes: changes,
                componentIndex: &componentIndex,
                viewIndex: &viewIndex,
                skipLayout: skipLayout
            )
            
        case .move(let componentId, _, let toIndex, let parentId):
            applyMove(
                componentId: componentId,
                toIndex: toIndex,
                parentId: parentId,
                componentIndex: &componentIndex,
                viewIndex: &viewIndex
            )
            
        case .replace(let oldId, let newComponent, let parentId):
            applyReplace(
                oldComponentId: oldId,
                newComponent: newComponent,
                parentId: parentId,
                componentIndex: &componentIndex,
                viewIndex: &viewIndex
            )
        }
    }
    
    // MARK: - Insert
    
    private func applyInsert(
        component: Component,
        index: Int,
        parentId: String,
        componentIndex: inout [String: Component],
        viewIndex: inout [String: UIView]
    ) {
        // 1. 找到父组件
        guard let parentComponent = componentIndex[parentId] else {
            TXLogger.warning("DiffPatcher: Parent component not found: \(parentId)")
            return
        }
        
        // 2. 添加到组件树
        let safeIndex = min(index, parentComponent.children.count)
        if safeIndex < parentComponent.children.count {
            parentComponent.children.insert(component, at: safeIndex)
        } else {
            parentComponent.children.append(component)
        }
        component.parent = parentComponent
        
        // 3. 更新索引
        addToIndex(component, componentIndex: &componentIndex)
        
        // 4. 创建视图树（只创建视图，不计算布局）
        let result = createViewTreeOnly(component)
        
        // 5. 添加到父视图
        if let parentView = parentComponent.view ?? viewIndex[parentId] {
            let viewSafeIndex = min(safeIndex, parentView.subviews.count)
            
            // 检查是否是扁平化产生的临时容器
            if result.isHidden && result.componentType == nil {
                // 提取临时容器中的所有子视图，添加到父视图
                var insertIndex = viewSafeIndex
                for subview in result.subviews {
                    subview.removeFromSuperview()
                    parentView.insertSubview(subview, at: insertIndex)
                    insertIndex += 1
                }
            } else {
                parentView.insertSubview(result, at: viewSafeIndex)
            }
        }
        
        // 注意：布局和视图更新在 apply() 最后统一处理
        
        // 6. 动画（需要延迟到布局完成后执行）
        if config.enableAnimation {
            // 对于扁平化组件，需要对所有子视图应用动画
            let viewsToAnimate: [UIView]
            if result.isHidden && result.componentType == nil {
                viewsToAnimate = result.subviews
            } else {
                viewsToAnimate = [result]
            }
            
            for view in viewsToAnimate {
                view.alpha = 0
            }
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: self.config.animationDuration) {
                    for view in viewsToAnimate {
                        view.alpha = 1
                    }
                }
            }
        }
    }
    
    /// 递归创建视图树（只创建视图，不计算布局）
    ///
    /// 扁平化原理：
    /// - 纯布局容器（无视觉效果、无事件）不创建真实 UIView
    /// - 子组件直接添加到最近的非扁平化祖先视图
    ///
    /// 注意：此方法只创建视图层级，不处理布局偏移。
    /// 布局偏移统一在 applyLayoutResults() 中处理。
    private func createViewTreeOnly(_ component: Component) -> UIView {
        // 检查是否可以扁平化
        if component.canFlatten {
            component.isFlattened = true
            
            // 创建临时容器收集子视图
            let tempContainer = UIView()
            tempContainer.isHidden = true
            
            for child in component.children {
                let childView = createViewTreeOnly(child)
                tempContainer.addSubview(childView)
            }
            
            return tempContainer
        }
        
        // 非扁平化：正常创建或复用视图
        let view: UIView
        if config.enableViewRecycle, let recycledView = viewRecyclePool.dequeueView(forType: component.type) {
            view = recycledView
            component.view = view
            // 复用视图时需要强制应用样式，避免旧样式残留
            if let baseComponent = component as? BaseComponent {
                baseComponent.forceApplyStyle = true
            }
        } else {
            view = component.createView()
        }
        
        // 标记组件类型
        view.componentType = component.type
        view.accessibilityIdentifier = component.id
        
        // 递归创建子视图
        for child in component.children {
            let result = createViewTreeOnly(child)
            
            // 检查是否是扁平化产生的临时容器
            if result.isHidden && result.componentType == nil {
                // 提取临时容器中的所有子视图
                for subview in result.subviews {
                    subview.removeFromSuperview()
                    view.addSubview(subview)
                }
            } else {
                view.addSubview(result)
            }
        }
        
        return view
    }
    
    // MARK: - Delete
    
    private func applyDelete(
        componentId: String,
        parentId: String,
        componentIndex: inout [String: Component],
        viewIndex: inout [String: UIView]
    ) {
        // 1. 找到组件
        guard let component = componentIndex[componentId] else {
            return
        }
        
        // 2. 找到父组件
        guard let parentComponent = componentIndex[parentId] else {
            return
        }
        
        // 3. 从组件树移除
        if let index = parentComponent.children.firstIndex(where: { $0.id == componentId }) {
            parentComponent.children.remove(at: index)
        }
        component.parent = nil
        
        // 4. 从索引移除
        removeFromIndex(component, componentIndex: &componentIndex)
        
        // 5. 处理视图
        if let view = component.view {
            if config.enableAnimation {
                UIView.animate(withDuration: config.animationDuration, animations: {
                    view.alpha = 0
                }) { _ in
                    self.recycleOrRemoveView(view, component: component)
                }
            } else {
                recycleOrRemoveView(view, component: component)
            }
        }
    }
    
    private func recycleOrRemoveView(_ view: UIView, component: Component) {
        view.removeFromSuperview()
        
        if config.enableViewRecycle {
            viewRecyclePool.recycleView(view, forType: component.type)
        }
    }
    
    // MARK: - Update
    
    private func applyUpdate(
        componentId: String,
        newComponent: Component,
        changes: PropertyChanges,
        componentIndex: inout [String: Component],
        viewIndex: inout [String: UIView],
        skipLayout: Bool = false
    ) {
        guard let component = componentIndex[componentId] else { return }
        
        // 1. 应用样式变化（统一的 style，包含布局和视觉属性）
        if let styleChanges = changes.styleChanges {
            // 合并样式变化到现有样式
            component.style = component.style.merging(styleChanges)
        }
        
        // 2. 应用绑定变化
        if let bindingChanges = changes.bindingChanges {
            for (key, value) in bindingChanges {
                // 跳过内部标记
                if key == "__componentNeedsUpdate" { continue }
                component.bindings[key] = value
            }
        }
        
        // 3. 应用组件特有属性变化
        // 从新组件复制特有属性到旧组件
        copyComponentSpecificProperties(from: newComponent, to: component)
        
        // 注意：布局在 apply() 最后统一处理，这里不单独计算
        // 视图更新也在 apply() 最后的 updateViewTree 中统一处理
    }
    
    /// 复制组件特有属性（如 TextComponent.text、ImageComponent.src 等）
    private func copyComponentSpecificProperties(from source: Component, to target: Component) {
        // TextComponent
        if let sourceText = source as? TextComponent,
           let targetText = target as? TextComponent {
            targetText.text = sourceText.text
            targetText.fontSize = sourceText.fontSize
            targetText.fontWeight = sourceText.fontWeight
            targetText.textColor = sourceText.textColor
            targetText.textAlignment = sourceText.textAlignment
            targetText.numberOfLines = sourceText.numberOfLines
            targetText.lineBreakMode = sourceText.lineBreakMode
            targetText.lineHeight = sourceText.lineHeight
            targetText.letterSpacing = sourceText.letterSpacing
            return
        }
        
        // ImageComponent
        if let sourceImage = source as? ImageComponent,
           let targetImage = target as? ImageComponent {
            targetImage.src = sourceImage.src
            targetImage.scaleType = sourceImage.scaleType
            targetImage.placeholder = sourceImage.placeholder
            targetImage.tintColor = sourceImage.tintColor
            return
        }
        
        // ButtonComponent
        if let sourceButton = source as? ButtonComponent,
           let targetButton = target as? ButtonComponent {
            targetButton.title = sourceButton.title
            targetButton.isDisabled = sourceButton.isDisabled
            targetButton.isLoading = sourceButton.isLoading
            targetButton.iconLeft = sourceButton.iconLeft
            targetButton.iconRight = sourceButton.iconRight
            return
        }
        
        // InputComponent
        if let sourceInput = source as? InputComponent,
           let targetInput = target as? InputComponent {
            targetInput.text = sourceInput.text
            targetInput.placeholder = sourceInput.placeholder
            targetInput.inputType = sourceInput.inputType
            targetInput.isDisabled = sourceInput.isDisabled
            targetInput.isReadOnly = sourceInput.isReadOnly
            return
        }
        
        // 其他组件类型可以继续添加...
    }
    
    // MARK: - Move
    
    private func applyMove(
        componentId: String,
        toIndex: Int,
        parentId: String,
        componentIndex: inout [String: Component],
        viewIndex: inout [String: UIView]
    ) {
        guard let component = componentIndex[componentId],
              let parentComponent = componentIndex[parentId] else {
            return
        }
        
        // 1. 从当前位置移除
        if let currentIndex = parentComponent.children.firstIndex(where: { $0.id == componentId }) {
            parentComponent.children.remove(at: currentIndex)
        }
        
        // 2. 插入到新位置
        let safeIndex = min(toIndex, parentComponent.children.count)
        parentComponent.children.insert(component, at: safeIndex)
        
        // 3. 移动视图
        if let view = component.view, let parentView = parentComponent.view {
            // 先移除
            view.removeFromSuperview()
            
            // 再插入到正确位置
            let viewSafeIndex = min(safeIndex, parentView.subviews.count)
            
            if config.enableAnimation {
                // 动画移动
                let originalFrame = view.frame
                parentView.insertSubview(view, at: viewSafeIndex)
                view.frame = originalFrame
                
                UIView.animate(withDuration: config.animationDuration) {
                    // frame 会在后续布局时更新
                }
            } else {
                parentView.insertSubview(view, at: viewSafeIndex)
            }
        }
    }
    
    // MARK: - Replace
    
    private func applyReplace(
        oldComponentId: String,
        newComponent: Component,
        parentId: String,
        componentIndex: inout [String: Component],
        viewIndex: inout [String: UIView]
    ) {
        guard componentIndex[oldComponentId] != nil,
              let parentComponent = componentIndex[parentId] else {
            return
        }
        
        // 找到旧组件的位置
        guard let index = parentComponent.children.firstIndex(where: { $0.id == oldComponentId }) else {
            return
        }
        
        // 1. 删除旧组件
        applyDelete(
            componentId: oldComponentId,
            parentId: parentId,
            componentIndex: &componentIndex,
            viewIndex: &viewIndex
        )
        
        // 2. 插入新组件
        applyInsert(
            component: newComponent,
            index: index,
            parentId: parentId,
            componentIndex: &componentIndex,
            viewIndex: &viewIndex
        )
        
        // 注意：布局在 apply() 最后统一处理
    }
    
    // MARK: - Private: 索引构建
    
    private func buildComponentIndex(_ root: Component) -> [String: Component] {
        var index: [String: Component] = [:]
        buildComponentIndexRecursive(root, index: &index)
        return index
    }
    
    private func buildComponentIndexRecursive(_ component: Component, index: inout [String: Component]) {
        index[component.id] = component
        for child in component.children {
            buildComponentIndexRecursive(child, index: &index)
        }
    }
    
    private func buildViewIndex(_ root: UIView) -> [String: UIView] {
        var index: [String: UIView] = [:]
        buildViewIndexRecursive(root, index: &index)
        return index
    }
    
    private func buildViewIndexRecursive(_ view: UIView, index: inout [String: UIView]) {
        if view.componentType != nil {
            // 使用视图的 tag 或 accessibilityIdentifier 作为 key
            let key = view.accessibilityIdentifier ?? "view_\(view.hash)"
            index[key] = view
        }
        for subview in view.subviews {
            buildViewIndexRecursive(subview, index: &index)
        }
    }
    
    private func addToIndex(_ component: Component, componentIndex: inout [String: Component]) {
        componentIndex[component.id] = component
        for child in component.children {
            addToIndex(child, componentIndex: &componentIndex)
        }
    }
    
    private func removeFromIndex(_ component: Component, componentIndex: inout [String: Component]) {
        componentIndex.removeValue(forKey: component.id)
        for child in component.children {
            removeFromIndex(child, componentIndex: &componentIndex)
        }
    }
    
    // MARK: - Private: 布局应用
    
    /// 应用布局结果到组件树（支持扁平化偏移累加）
    ///
    /// Yoga 返回的是相对于父节点的坐标。对于扁平化的父组件（没有创建 UIView），
    /// 其子组件的 view 实际上被添加到了更上层的祖先视图中，所以需要累加扁平化父组件的偏移。
    ///
    /// 注意：对于增量更新场景，isFlattened 已在首次渲染时设置，但为了保持一致性，
    /// 这里也使用 canFlatten 进行判断。
    ///
    /// - Parameters:
    ///   - results: Yoga 计算的布局结果（相对坐标）
    ///   - component: 目标组件
    ///   - parentOffset: 扁平化父组件的累计偏移
    private func applyLayoutResults(
        _ results: [String: LayoutResult],
        to component: Component,
        parentOffset: CGPoint = .zero
    ) {
        // 获取 Yoga 计算的相对坐标
        guard let result = results[component.id] else {
            // 如果没有布局结果，继续处理子组件
            for child in component.children {
                applyLayoutResults(results, to: child, parentOffset: parentOffset)
            }
            return
        }
        
        // 计算当前组件应该累加到子组件的偏移
        var offsetForChildren: CGPoint = .zero
        
        // 应用布局结果
        var adjustedResult = result
        
        // 使用 canFlatten 判断，保持与 RenderEngine 一致
        let shouldFlatten = component.canFlatten
        if shouldFlatten {
            component.isFlattened = true
            // 扁平化组件：不设置自己的 frame（因为没有 view）
            // 但需要把自己的位置偏移传递给子组件
            offsetForChildren = CGPoint(
                x: parentOffset.x + result.frame.origin.x,
                y: parentOffset.y + result.frame.origin.y
            )
            component.layoutResult = result  // 保留原始结果用于其他用途
        } else {
            component.isFlattened = false
            // 非扁平化组件：累加父偏移到自己的 frame
            if parentOffset != .zero {
                adjustedResult.frame.origin.x += parentOffset.x
                adjustedResult.frame.origin.y += parentOffset.y
            }
            component.layoutResult = adjustedResult
            // 非扁平化组件的子组件不需要额外偏移
            offsetForChildren = .zero
        }
        
        // 递归处理子组件
        for child in component.children {
            applyLayoutResults(results, to: child, parentOffset: offsetForChildren)
        }
    }
    
    private func updateViewTree(_ component: Component) {
        component.updateView()
        for child in component.children {
            updateViewTree(child)
        }
    }
}

// MARK: - 便捷扩展

extension DiffPatcher {
    
    /// 增量更新组件树
    /// - Parameters:
    ///   - oldComponent: 旧组件树
    ///   - newComponent: 新组件树
    ///   - rootView: 根视图
    ///   - containerSize: 容器尺寸
    /// - Returns: 应用的操作数量
    @discardableResult
    public func incrementalUpdate(
        from oldComponent: Component,
        to newComponent: Component,
        rootView: UIView,
        containerSize: CGSize
    ) -> Int {
        // 1. 计算 diff
        let diffResult = ViewDiffer.shared.diff(oldTree: oldComponent, newTree: newComponent)
        
        // 2. 应用 diff
        apply(diffResult, to: oldComponent, rootView: rootView, containerSize: containerSize)
        
        // 3. 返回操作数量
        return diffResult.operationCount
    }
}
