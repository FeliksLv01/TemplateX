import Foundation

// MARK: - 视图 Diff 算法

/// 视图树 Diff 算法
/// 基于 key 的高效 diff，借鉴 React 和 Vue 的算法思想
public final class ViewDiffer {
    
    // MARK: - 单例
    
    public static let shared = ViewDiffer()
    
    private init() {}
    
    // MARK: - 配置
    
    /// Diff 配置
    public struct Config {
        /// 是否启用 key 优化（列表场景）
        public var enableKeyOptimization: Bool = true
        
        /// 是否启用深度比较（检测属性变化）
        public var enableDeepCompare: Bool = true
        
        /// 最大 diff 深度（防止过深递归）
        public var maxDepth: Int = 50
        
        public init() {}
    }
    
    public var config = Config()
    
    // MARK: - Public API
    
    /// 比较两棵组件树，生成 Diff 结果
    /// - Parameters:
    ///   - oldTree: 旧组件树
    ///   - newTree: 新组件树
    /// - Returns: Diff 结果
    public func diff(oldTree: Component?, newTree: Component?) -> DiffResult {
        var result = DiffResult()
        
        // 根节点特殊处理
        switch (oldTree, newTree) {
        case (nil, nil):
            // 无变化
            break
            
        case (nil, let new?):
            // 新增整棵树
            result.addInsert(new, at: 0, parentId: "root")
            
        case (let old?, nil):
            // 删除整棵树
            result.addDelete(old.id, parentId: "root")
            
        case (let old?, let new?):
            // 比较两棵树
            diffNode(old: old, new: new, parentId: "root", index: 0, result: &result, depth: 0)
        }
        
        return result
    }
    
    /// 比较子节点列表
    /// - Parameters:
    ///   - oldChildren: 旧子节点列表
    ///   - newChildren: 新子节点列表
    ///   - parentId: 父节点 ID
    /// - Returns: Diff 结果
    public func diffChildren(
        oldChildren: [Component],
        newChildren: [Component],
        parentId: String
    ) -> DiffResult {
        var result = DiffResult()
        diffChildrenList(
            oldChildren: oldChildren,
            newChildren: newChildren,
            parentId: parentId,
            result: &result,
            depth: 0
        )
        return result
    }
    
    // MARK: - Private: 节点 Diff
    
    private func diffNode(
        old: Component,
        new: Component,
        parentId: String,
        index: Int,
        result: inout DiffResult,
        depth: Int
    ) {
        // 深度检查
        guard depth < config.maxDepth else {
            TXLogger.warning("ViewDiffer: Max depth exceeded at node: \(old.id)")
            return
        }
        
        // 1. 类型不同 -> 替换
        if old.type != new.type {
            result.addReplace(old: old.id, new: new, parentId: parentId)
            return
        }
        
        // 2. 检查属性变化
        if config.enableDeepCompare {
            let changes = detectPropertyChanges(old: old, new: new)
            if changes.hasChanges {
                result.addUpdate(old.id, newComponent: new, changes: changes)
            }
        }
        
        // 3. 递归比较子节点
        diffChildrenList(
            oldChildren: old.children,
            newChildren: new.children,
            parentId: old.id,
            result: &result,
            depth: depth + 1
        )
    }
    
    // MARK: - Private: 子节点列表 Diff
    
    /// 子节点列表 Diff 算法
    /// 使用双端比较 + key map 优化
    private func diffChildrenList(
        oldChildren: [Component],
        newChildren: [Component],
        parentId: String,
        result: inout DiffResult,
        depth: Int
    ) {
        // 空列表快速处理
        if oldChildren.isEmpty {
            for (index, child) in newChildren.enumerated() {
                result.addInsert(child, at: index, parentId: parentId)
            }
            return
        }
        
        if newChildren.isEmpty {
            for child in oldChildren {
                result.addDelete(child.id, parentId: parentId)
            }
            return
        }
        
        // 使用 key 优化的 diff
        if config.enableKeyOptimization {
            diffWithKeys(
                oldChildren: oldChildren,
                newChildren: newChildren,
                parentId: parentId,
                result: &result,
                depth: depth
            )
        } else {
            // 简单线性 diff
            diffLinear(
                oldChildren: oldChildren,
                newChildren: newChildren,
                parentId: parentId,
                result: &result,
                depth: depth
            )
        }
    }
    
    // MARK: - Key-based Diff (双端比较算法)
    
    /// 基于 key 的高效 diff 算法
    /// 算法步骤：
    /// 1. 头头比较：从头部开始匹配相同的节点
    /// 2. 尾尾比较：从尾部开始匹配相同的节点
    /// 3. 中间处理：使用 key map 处理剩余节点
    private func diffWithKeys(
        oldChildren: [Component],
        newChildren: [Component],
        parentId: String,
        result: inout DiffResult,
        depth: Int
    ) {
        var oldStart = 0
        var oldEnd = oldChildren.count - 1
        var newStart = 0
        var newEnd = newChildren.count - 1
        
        // 创建快照用于比较
        let oldSnapshots = oldChildren.map { ComponentSnapshot(from: $0) }
        let newSnapshots = newChildren.map { ComponentSnapshot(from: $0) }
        
        // 1. 头头比较
        while oldStart <= oldEnd && newStart <= newEnd {
            let oldSnap = oldSnapshots[oldStart]
            let newSnap = newSnapshots[newStart]
            
            if oldSnap.canMatch(newSnap) {
                // 匹配成功，检查内容是否变化
                if !oldSnap.contentEquals(newSnap) {
                    let changes = detectPropertyChanges(
                        old: oldChildren[oldStart],
                        new: newChildren[newStart]
                    )
                    if changes.hasChanges {
                        result.addUpdate(oldChildren[oldStart].id, newComponent: newChildren[newStart], changes: changes)
                    }
                }
                // 递归比较子节点
                diffChildrenList(
                    oldChildren: oldChildren[oldStart].children,
                    newChildren: newChildren[newStart].children,
                    parentId: oldChildren[oldStart].id,
                    result: &result,
                    depth: depth + 1
                )
                oldStart += 1
                newStart += 1
            } else {
                break
            }
        }
        
        // 2. 尾尾比较
        while oldStart <= oldEnd && newStart <= newEnd {
            let oldSnap = oldSnapshots[oldEnd]
            let newSnap = newSnapshots[newEnd]
            
            if oldSnap.canMatch(newSnap) {
                if !oldSnap.contentEquals(newSnap) {
                    let changes = detectPropertyChanges(
                        old: oldChildren[oldEnd],
                        new: newChildren[newEnd]
                    )
                    if changes.hasChanges {
                        result.addUpdate(oldChildren[oldEnd].id, newComponent: newChildren[newEnd], changes: changes)
                    }
                }
                diffChildrenList(
                    oldChildren: oldChildren[oldEnd].children,
                    newChildren: newChildren[newEnd].children,
                    parentId: oldChildren[oldEnd].id,
                    result: &result,
                    depth: depth + 1
                )
                oldEnd -= 1
                newEnd -= 1
            } else {
                break
            }
        }
        
        // 3. 处理剩余节点
        if oldStart > oldEnd && newStart <= newEnd {
            // 旧列表已处理完，剩余的新节点都是插入
            for i in newStart...newEnd {
                result.addInsert(newChildren[i], at: i, parentId: parentId)
            }
        } else if newStart > newEnd && oldStart <= oldEnd {
            // 新列表已处理完，剩余的旧节点都是删除
            for i in oldStart...oldEnd {
                result.addDelete(oldChildren[i].id, parentId: parentId)
            }
        } else if oldStart <= oldEnd && newStart <= newEnd {
            // 中间有复杂变化，使用 key map 处理
            processMiddleNodes(
                oldChildren: oldChildren,
                newChildren: newChildren,
                oldRange: oldStart...oldEnd,
                newRange: newStart...newEnd,
                parentId: parentId,
                result: &result,
                depth: depth
            )
        }
    }
    
    /// 处理中间节点（无法通过双端比较处理的节点）
    private func processMiddleNodes(
        oldChildren: [Component],
        newChildren: [Component],
        oldRange: ClosedRange<Int>,
        newRange: ClosedRange<Int>,
        parentId: String,
        result: inout DiffResult,
        depth: Int
    ) {
        // 建立旧节点的 key -> index 映射
        var oldKeyMap: [String: Int] = [:]
        var oldIdMap: [String: Int] = [:]
        
        for i in oldRange {
            let child = oldChildren[i]
            if let key = child.bindings["key"] as? String {
                oldKeyMap[key] = i
            }
            oldIdMap[child.id] = i
        }
        
        // 记录已匹配的旧节点
        var matchedOldIndices = Set<Int>()
        
        // 遍历新节点
        for newIndex in newRange {
            let newChild = newChildren[newIndex]
            let newKey = newChild.bindings["key"] as? String
            
            // 尝试找到匹配的旧节点
            var matchedOldIndex: Int?
            
            if let key = newKey, let oldIndex = oldKeyMap[key] {
                // 通过 key 匹配
                matchedOldIndex = oldIndex
            } else if let oldIndex = oldIdMap[newChild.id] {
                // 通过 id 匹配
                matchedOldIndex = oldIndex
            }
            
            if let oldIndex = matchedOldIndex,
               !matchedOldIndices.contains(oldIndex),
               oldChildren[oldIndex].type == newChild.type {
                // 找到匹配，检查是否需要移动
                matchedOldIndices.insert(oldIndex)
                
                // 检查内容变化
                let changes = detectPropertyChanges(
                    old: oldChildren[oldIndex],
                    new: newChild
                )
                if changes.hasChanges {
                    result.addUpdate(oldChildren[oldIndex].id, newComponent: newChild, changes: changes)
                }
                
                // 检查位置变化
                if oldIndex != newIndex {
                    result.addMove(
                        oldChildren[oldIndex].id,
                        from: oldIndex,
                        to: newIndex,
                        parentId: parentId
                    )
                }
                
                // 递归比较子节点
                diffChildrenList(
                    oldChildren: oldChildren[oldIndex].children,
                    newChildren: newChild.children,
                    parentId: oldChildren[oldIndex].id,
                    result: &result,
                    depth: depth + 1
                )
            } else {
                // 没有匹配，插入新节点
                result.addInsert(newChild, at: newIndex, parentId: parentId)
            }
        }
        
        // 删除未匹配的旧节点
        for i in oldRange {
            if !matchedOldIndices.contains(i) {
                result.addDelete(oldChildren[i].id, parentId: parentId)
            }
        }
    }
    
    // MARK: - 简单线性 Diff
    
    /// 简单的线性 diff（不使用 key 优化）
    private func diffLinear(
        oldChildren: [Component],
        newChildren: [Component],
        parentId: String,
        result: inout DiffResult,
        depth: Int
    ) {
        let maxLen = max(oldChildren.count, newChildren.count)
        
        for i in 0..<maxLen {
            let oldChild = i < oldChildren.count ? oldChildren[i] : nil
            let newChild = i < newChildren.count ? newChildren[i] : nil
            
            switch (oldChild, newChild) {
            case (nil, let new?):
                result.addInsert(new, at: i, parentId: parentId)
                
            case (let old?, nil):
                result.addDelete(old.id, parentId: parentId)
                
            case (let old?, let new?):
                diffNode(
                    old: old,
                    new: new,
                    parentId: parentId,
                    index: i,
                    result: &result,
                    depth: depth + 1
                )
                
            default:
                break
            }
        }
    }
    
    // MARK: - 属性变化检测
    
    /// 检测属性变化
    /// 除了比较 style 和 bindings，还会调用组件的 needsUpdate(with:) 方法
    /// 以检测组件特有属性的变化（如 TextComponent.text、ImageComponent.src 等）
    private func detectPropertyChanges(old: Component, new: Component) -> PropertyChanges {
        var changes = PropertyChanges()
        
        // 检查样式变化（包含布局、视觉、文本样式）
        if old.style != new.style {
            changes.styleChanges = new.style
        }
        
        // 检查绑定数据变化
        if !bindingsEqual(old.bindings, new.bindings) {
            changes.bindingChanges = new.bindings
        }
        
        // 检查组件特有属性变化（如 TextComponent.text、ImageComponent.src 等）
        // needsUpdate(with:) 会检查组件特有属性
        if old.needsUpdate(with: new) {
            // 如果 style 和 bindings 都没变，但 needsUpdate 返回 true，
            // 说明组件特有属性变了，需要标记为有变化
            if changes.styleChanges == nil && changes.bindingChanges == nil {
                // 用 bindings 传递新组件引用，让 DiffPatcher 可以获取新属性值
                changes.bindingChanges = ["__componentNeedsUpdate": true]
            }
        }
        
        return changes
    }
    
    /// 比较两个绑定字典是否相等
    private func bindingsEqual(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        guard a.count == b.count else { return false }
        
        for (key, valueA) in a {
            guard let valueB = b[key] else { return false }
            
            // 简单的字符串比较
            if String(describing: valueA) != String(describing: valueB) {
                return false
            }
        }
        
        return true
    }
}

// MARK: - 便捷扩展

extension ViewDiffer {
    
    /// 快速比较两个组件（不递归子节点）
    public func compareComponents(_ a: Component, _ b: Component) -> PropertyChanges {
        return detectPropertyChanges(old: a, new: b)
    }
    
    /// 判断两个组件是否相同（包括子节点）
    public func isEqual(_ a: Component, _ b: Component) -> Bool {
        let result = diff(oldTree: a, newTree: b)
        return !result.hasDiff
    }
}
