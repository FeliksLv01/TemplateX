# TemplateX：Diff + Patch 增量更新

> 本文是 TemplateX 系列文章的第 5 篇，深入解析增量更新机制的设计与实现。

## 先看效果

假设用户点赞后，只有 `likeCount` 变化：

```swift
// 旧数据
let oldData = ["user": ["name": "张三", "likeCount": 100]]

// 新数据
let newData = ["user": ["name": "张三", "likeCount": 101]]

// 增量更新
TemplateX.update(view: cardView, data: newData)
```

**Diff 结果：**

```
DiffStats(insert: 0, delete: 0, update: 1, move: 0, replace: 0)
```

只更新了 1 个组件（显示点赞数的 Text），而不是重建整个卡片！

**Question**: 如何高效地检测组件树的变化，并只更新需要更新的部分？

---

## 为什么需要增量更新？

### 全量渲染的问题

```
┌─────────────────────────────────────────────────────────────┐
│                      全量渲染                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  数据变化 → 销毁旧视图 → 解析模板 → 创建新视图               │
│                                                              │
│  问题：                                                      │
│  1. 频繁创建/销毁 UIView，产生大量临时对象                   │
│  2. 丢失视图状态（输入框焦点、滚动位置等）                   │
│  3. 可能触发布局抖动（闪烁）                                 │
│  4. 性能差，尤其是复杂卡片                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 增量更新的优势

```
┌─────────────────────────────────────────────────────────────┐
│                      增量更新                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  数据变化 → Diff 对比 → 只更新变化的组件                     │
│                                                              │
│  优势：                                                      │
│  1. 最小化视图操作，减少对象创建                             │
│  2. 保留视图状态（输入框焦点、滚动位置等）                   │
│  3. 无布局抖动，更新平滑                                     │
│  4. 性能好，尤其是小范围更新                                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 整体设计

### 增量更新流程

```
┌─────────────────────────────────────────────────────────────┐
│                     增量更新流程                              │
└─────────────────────────────────────────────────────────────┘

    新数据
      │
      ▼
  ┌──────────┐
  │  Clone   │  ← 克隆旧组件树（保留结构）
  │ Old Tree │
  └────┬─────┘
       │ 新组件树
       ▼
  ┌──────────┐
  │   Bind   │  ← 绑定新数据
  │   Data   │
  └────┬─────┘
       │ 绑定后的新组件树
       ▼
  ┌──────────┐     ┌──────────┐
  │   Diff   │◀────│ Old Tree │  ← 比较新旧组件树
  │          │     │(original)│
  └────┬─────┘     └──────────┘
       │ DiffResult
       ▼
  ┌──────────┐
  │  Patch   │  ← 应用差异到视图
  │          │
  └──────────┘
```

### 核心模块

| 模块 | 职责 | 文件 |
|------|------|------|
| **ViewDiffer** | Diff 算法，比较组件树 | `ViewDiffer.swift` |
| **DiffResult** | 差异结果，记录操作列表 | `DiffResult.swift` |
| **DiffPatcher** | Patch 应用，更新视图 | `DiffPatcher.swift` |

---

## Step 1: Diff 操作类型

### DiffOperation 枚举

```swift
/// Diff 操作类型
public enum DiffOperation {
    /// 插入新组件
    case insert(component: Component, index: Int, parentId: String)
    
    /// 删除组件
    case delete(componentId: String, parentId: String)
    
    /// 更新组件（属性变化）
    case update(componentId: String, newComponent: Component, changes: PropertyChanges)
    
    /// 移动组件（位置变化）
    case move(componentId: String, fromIndex: Int, toIndex: Int, parentId: String)
    
    /// 替换组件（类型变化）
    case replace(oldComponentId: String, newComponent: Component, parentId: String)
}
```

### 操作类型说明

```
┌─────────────────────────────────────────────────────────────┐
│                      Diff 操作类型                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  INSERT:  新增组件                                           │
│  ┌───┐          ┌───┐                                       │
│  │ A │    →     │ A │  ← 新增了 B                            │
│  └───┘          │ B │                                       │
│                 └───┘                                       │
│                                                              │
│  DELETE:  删除组件                                           │
│  ┌───┐          ┌───┐                                       │
│  │ A │    →     │ A │  ← 删除了 B                            │
│  │ B │          └───┘                                       │
│  └───┘                                                       │
│                                                              │
│  UPDATE:  更新属性（同一组件）                               │
│  ┌─────────┐    ┌─────────┐                                 │
│  │ text=A  │ →  │ text=B  │  ← 只是文本变了                  │
│  └─────────┘    └─────────┘                                 │
│                                                              │
│  MOVE:    移动位置（列表场景）                               │
│  ┌───┐          ┌───┐                                       │
│  │ A │          │ B │  ← A 和 B 交换了位置                   │
│  │ B │    →     │ A │                                       │
│  └───┘          └───┘                                       │
│                                                              │
│  REPLACE: 替换组件（类型变了）                               │
│  ┌──────┐       ┌───────┐                                   │
│  │ Text │  →    │ Image │  ← 组件类型变了，必须替换          │
│  └──────┘       └───────┘                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### PropertyChanges 属性变化

```swift
/// 属性变化集合
public struct PropertyChanges {
    /// 样式变化（包含布局、视觉、文本样式）
    public var styleChanges: ComponentStyle?
    
    /// 绑定数据变化
    public var bindingChanges: [String: Any]?
    
    /// 是否有变化
    public var hasChanges: Bool {
        return styleChanges != nil || bindingChanges != nil
    }
    
    /// 是否需要重新布局
    public var needsRelayout: Bool {
        return styleChanges != nil
    }
}
```

---

## Step 2: ViewDiffer 算法

### 核心思想

ViewDiffer 借鉴了 React 和 Vue 的 Diff 算法：

1. **同层比较**：只比较同一层级的节点，不跨层
2. **类型优先**：类型不同直接替换，不深入比较
3. **Key 优化**：列表场景使用 key 匹配，减少不必要的 DOM 操作
4. **双端比较**：从头尾两端同时比较，快速处理常见场景

### 算法流程

```
┌─────────────────────────────────────────────────────────────┐
│                    ViewDiffer 算法流程                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 1: 根节点比较                                          │
│  ┌─────────────────────────────────────────────────┐        │
│  │  old == nil && new != nil  →  INSERT           │        │
│  │  old != nil && new == nil  →  DELETE           │        │
│  │  old.type != new.type      →  REPLACE          │        │
│  │  old.type == new.type      →  继续比较         │        │
│  └─────────────────────────────────────────────────┘        │
│                                                              │
│  Step 2: 属性比较                                            │
│  ┌─────────────────────────────────────────────────┐        │
│  │  比较 style（布局 + 视觉 + 文本样式）           │        │
│  │  比较 bindings（绑定数据）                       │        │
│  │  比较组件特有属性（text, src 等）               │        │
│  │  有变化 → UPDATE                                │        │
│  └─────────────────────────────────────────────────┘        │
│                                                              │
│  Step 3: 子节点比较（递归）                                  │
│  ┌─────────────────────────────────────────────────┐        │
│  │  使用双端比较 + Key Map 算法                    │        │
│  │  生成 INSERT / DELETE / MOVE 操作               │        │
│  └─────────────────────────────────────────────────┘        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 代码实现

```swift
public final class ViewDiffer {
    
    public static let shared = ViewDiffer()
    
    /// Diff 配置
    public struct Config {
        /// 是否启用 key 优化（列表场景）
        public var enableKeyOptimization: Bool = true
        
        /// 是否启用深度比较（检测属性变化）
        public var enableDeepCompare: Bool = true
        
        /// 最大 diff 深度（防止过深递归）
        public var maxDepth: Int = 50
    }
    
    public var config = Config()
    
    /// 比较两棵组件树
    public func diff(oldTree: Component?, newTree: Component?) -> DiffResult {
        var result = DiffResult()
        
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
            diffNode(old: old, new: new, parentId: "root", 
                     index: 0, result: &result, depth: 0)
        }
        
        return result
    }
}
```

### 节点比较

```swift
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
    
    // 1. 类型不同 → 替换
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
```

### 属性变化检测

```swift
private func detectPropertyChanges(old: Component, new: Component) -> PropertyChanges {
    var changes = PropertyChanges()
    
    // 1. 检查样式变化
    if old.style != new.style {
        changes.styleChanges = new.style
    }
    
    // 2. 检查绑定数据变化
    if !bindingsEqual(old.bindings, new.bindings) {
        changes.bindingChanges = new.bindings
    }
    
    // 3. 检查组件特有属性变化（TextComponent.text 等）
    if old.needsUpdate(with: new) {
        if changes.styleChanges == nil && changes.bindingChanges == nil {
            // 标记需要更新
            changes.bindingChanges = ["__componentNeedsUpdate": true]
        }
    }
    
    return changes
}
```

---

## Step 3: 双端比较算法

### 算法原理

双端比较是 Vue 2.x 使用的 Diff 算法，TemplateX 参考实现：

```
┌─────────────────────────────────────────────────────────────┐
│                    双端比较算法                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  旧列表: [A, B, C, D]                                        │
│  新列表: [A, B, E, D]                                        │
│                                                              │
│  Step 1: 头头比较                                            │
│  ┌───┬───┬───┬───┐     ┌───┬───┬───┬───┐                   │
│  │ A │ B │ C │ D │     │ A │ B │ E │ D │                   │
│  └───┴───┴───┴───┘     └───┴───┴───┴───┘                   │
│    ↑                     ↑                                  │
│    A == A ✓              匹配成功，继续                      │
│                                                              │
│  ┌───┬───┬───┬───┐     ┌───┬───┬───┬───┐                   │
│  │ A │ B │ C │ D │     │ A │ B │ E │ D │                   │
│  └───┴───┴───┴───┘     └───┴───┴───┴───┘                   │
│        ↑                     ↑                              │
│        B == B ✓              匹配成功，继续                  │
│                                                              │
│  ┌───┬───┬───┬───┐     ┌───┬───┬───┬───┐                   │
│  │ A │ B │ C │ D │     │ A │ B │ E │ D │                   │
│  └───┴───┴───┴───┘     └───┴───┴───┴───┘                   │
│            ↑                     ↑                          │
│            C != E ✗              头头不匹配，尝试尾尾        │
│                                                              │
│  Step 2: 尾尾比较                                            │
│  ┌───┬───┬───┬───┐     ┌───┬───┬───┬───┐                   │
│  │ A │ B │ C │ D │     │ A │ B │ E │ D │                   │
│  └───┴───┴───┴───┘     └───┴───┴───┴───┘                   │
│                    ↑                     ↑                  │
│                    D == D ✓              匹配成功           │
│                                                              │
│  Step 3: 中间处理                                            │
│  旧: [C]  新: [E]                                            │
│  C 未匹配 → DELETE(C)                                        │
│  E 未匹配 → INSERT(E)                                        │
│                                                              │
│  最终结果:                                                   │
│  - DELETE(C)                                                │
│  - INSERT(E, at: 2)                                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 代码实现

```swift
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
                    result.addUpdate(oldChildren[oldStart].id, 
                                     newComponent: newChildren[newStart], 
                                     changes: changes)
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
            break  // 不匹配，跳出头头比较
        }
    }
    
    // 2. 尾尾比较
    while oldStart <= oldEnd && newStart <= newEnd {
        let oldSnap = oldSnapshots[oldEnd]
        let newSnap = newSnapshots[newEnd]
        
        if oldSnap.canMatch(newSnap) {
            // 同上处理...
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
        processMiddleNodes(...)
    }
}
```

### Key Map 处理中间节点

```swift
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
            oldKeyMap[key] = i  // 用户指定的 key
        }
        oldIdMap[child.id] = i  // 组件 ID
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
            matchedOldIndex = oldIndex  // 通过 key 匹配
        } else if let oldIndex = oldIdMap[newChild.id] {
            matchedOldIndex = oldIndex  // 通过 id 匹配
        }
        
        if let oldIndex = matchedOldIndex,
           !matchedOldIndices.contains(oldIndex),
           oldChildren[oldIndex].type == newChild.type {
            
            matchedOldIndices.insert(oldIndex)
            
            // 检查内容变化
            let changes = detectPropertyChanges(
                old: oldChildren[oldIndex],
                new: newChild
            )
            if changes.hasChanges {
                result.addUpdate(oldChildren[oldIndex].id, 
                                 newComponent: newChild, 
                                 changes: changes)
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
```

---

## Step 4: ComponentSnapshot 快照

### 为什么需要快照？

直接比较组件对象有两个问题：
1. 组件是引用类型，比较时需要遍历所有属性
2. 比较结果无法缓存

快照是轻量级值类型，预计算 hash 值，比较更快。

### 实现

```swift
/// 组件快照，用于 Diff 比较
public struct ComponentSnapshot: Hashable {
    public let id: String
    public let type: String
    public let key: String?  // 用户指定的 key
    
    // 预计算的 hash 值
    public let styleHash: Int
    public let bindingsHash: Int
    public let componentPropsHash: Int  // TextComponent.text 等
    
    public init(from component: Component) {
        self.id = component.id
        self.type = component.type
        self.key = component.bindings["key"] as? String
        
        self.styleHash = Self.hashStyle(component.style)
        self.bindingsHash = Self.hashBindings(component.bindings)
        self.componentPropsHash = Self.hashComponentProps(component)
    }
    
    /// 判断是否可能是同一个组件（用于匹配）
    public func canMatch(_ other: ComponentSnapshot) -> Bool {
        // 优先使用 key 匹配
        if let key1 = key, let key2 = other.key {
            return key1 == key2 && type == other.type
        }
        // 否则使用 id 匹配
        return id == other.id && type == other.type
    }
    
    /// 判断内容是否相同
    public func contentEquals(_ other: ComponentSnapshot) -> Bool {
        return styleHash == other.styleHash &&
               bindingsHash == other.bindingsHash &&
               componentPropsHash == other.componentPropsHash
    }
}
```

### Hash 计算示例

```swift
private static func hashComponentProps(_ component: Component) -> Int {
    var hasher = Hasher()
    
    // TextComponent 特有属性
    if let textComponent = component as? TextComponent {
        hasher.combine(textComponent.text)
        hasher.combine(textComponent.fontSize)
        hasher.combine(textComponent.fontWeight)
        hasher.combine(String(describing: textComponent.textColor))
        hasher.combine(textComponent.numberOfLines)
        return hasher.finalize()
    }
    
    // ImageComponent 特有属性
    if let imageComponent = component as? ImageComponent {
        hasher.combine(imageComponent.src)
        hasher.combine(imageComponent.scaleType)
        return hasher.finalize()
    }
    
    // 其他组件
    return 0
}
```

---

## Step 5: DiffPatcher 应用

### Patch 流程

```
┌─────────────────────────────────────────────────────────────┐
│                    DiffPatcher 流程                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  DiffResult                                                  │
│      │                                                       │
│      ▼                                                       │
│  ┌──────────────┐                                           │
│  │ 操作分类     │  ← 分离删除操作（需要最后执行）            │
│  │ - 非删除操作 │                                           │
│  │ - 删除操作   │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ 执行非删除   │  ← INSERT / UPDATE / MOVE / REPLACE       │
│  │ 操作         │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ 执行删除操作 │  ← DELETE（从后向前）                      │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ 重新布局     │  ← 统一计算整棵树的布局                    │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ 更新视图树   │  ← 递归调用 component.updateView()        │
│  └──────────────┘                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 核心实现

```swift
public final class DiffPatcher {
    
    public static let shared = DiffPatcher()
    
    private let layoutEngine = YogaLayoutEngine.shared
    
    public struct Config {
        public var enableAnimation: Bool = false
        public var animationDuration: TimeInterval = 0.25
    }
    
    public var config = Config()
    
    /// 应用 Diff 结果
    public func apply(
        _ diffResult: DiffResult,
        to rootComponent: Component,
        rootView: UIView,
        containerSize: CGSize
    ) {
        guard diffResult.hasDiff else { return }
        
        // 1. 建立组件和视图索引
        var componentIndex = buildComponentIndex(rootComponent)
        var viewIndex = buildViewIndex(rootView)
        
        // 2. 分离操作
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
        
        // 3. 先执行非删除操作
        for operation in otherOperations {
            applyOperation(operation, 
                           componentIndex: &componentIndex,
                           viewIndex: &viewIndex,
                           skipLayout: true)
        }
        
        // 4. 最后执行删除操作（从后向前）
        for operation in deleteOperations.reversed() {
            applyOperation(operation,
                           componentIndex: &componentIndex,
                           viewIndex: &viewIndex,
                           skipLayout: true)
        }
        
        // 5. 统一重新布局
        let layoutResults = layoutEngine.calculateLayout(
            for: rootComponent, 
            containerSize: containerSize
        )
        applyLayoutResults(layoutResults, to: rootComponent)
        
        // 6. 更新视图树
        updateViewTree(rootComponent)
    }
}
```

### INSERT 操作

```swift
private func applyInsert(
    component: Component,
    index: Int,
    parentId: String,
    componentIndex: inout [String: Component],
    viewIndex: inout [String: UIView]
) {
    // 1. 找到父组件
    guard let parentComponent = componentIndex[parentId] else { return }
    
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
    let newView = createViewTreeOnly(component)
    
    // 5. 添加到父视图
    if let parentView = parentComponent.view ?? viewIndex[parentId] {
        let viewSafeIndex = min(safeIndex, parentView.subviews.count)
        parentView.insertSubview(newView, at: viewSafeIndex)
    }
    
    // 6. 动画（可选）
    if config.enableAnimation {
        newView.alpha = 0
        UIView.animate(withDuration: config.animationDuration) {
            newView.alpha = 1
        }
    }
}
```

### UPDATE 操作

```swift
private func applyUpdate(
    componentId: String,
    newComponent: Component,
    changes: PropertyChanges,
    componentIndex: inout [String: Component],
    viewIndex: inout [String: UIView],
    skipLayout: Bool = false
) {
    guard let component = componentIndex[componentId] else { return }
    
    // 1. 应用样式变化
    if let styleChanges = changes.styleChanges {
        component.style = component.style.merging(styleChanges)
    }
    
    // 2. 应用绑定变化
    if let bindingChanges = changes.bindingChanges {
        for (key, value) in bindingChanges {
            if key == "__componentNeedsUpdate" { continue }
            component.bindings[key] = value
        }
    }
    
    // 3. 应用组件特有属性变化
    component.copyProps(from: newComponent)
    
    // 注意：布局和视图更新在 apply() 最后统一处理
}
```

### DELETE 操作

```swift
private func applyDelete(
    componentId: String,
    parentId: String,
    componentIndex: inout [String: Component],
    viewIndex: inout [String: UIView]
) {
    guard let component = componentIndex[componentId],
          let parentComponent = componentIndex[parentId] else { return }
    
    // 1. 从组件树移除
    if let index = parentComponent.children.firstIndex(where: { $0.id == componentId }) {
        parentComponent.children.remove(at: index)
    }
    component.parent = nil
    
    // 2. 从索引移除
    removeFromIndex(component, componentIndex: &componentIndex)
    
    // 3. 处理视图
    if let view = component.view {
        if config.enableAnimation {
            UIView.animate(withDuration: config.animationDuration, animations: {
                view.alpha = 0
            }) { _ in
                view.removeFromSuperview()
            }
        } else {
            view.removeFromSuperview()
        }
    }
}
```

---

## Step 6: RenderEngine 集成

### update 方法

```swift
extension RenderEngine {
    
    /// 增量更新视图
    public func update(
        view: UIView,
        data: [String: Any],
        containerSize: CGSize
    ) {
        guard let component = viewComponentMap[view] else {
            TXLogger.warning("RenderEngine.update: Component not found for view")
            return
        }
        
        // 1. 克隆组件树
        let newComponent = component.clone()
        
        // 2. 绑定新数据
        DataBindingManager.shared.bind(data: data, to: newComponent)
        
        // 3. Diff
        let diffResult = ViewDiffer.shared.diff(oldTree: component, newTree: newComponent)
        
        TXLogger.trace("""
            RenderEngine.update: \(diffResult.statistics.description)
            """)
        
        // 4. Patch
        DiffPatcher.shared.apply(
            diffResult,
            to: component,
            rootView: view,
            containerSize: containerSize
        )
    }
}
```

### 快速更新（只更新数据）

```swift
/// 快速更新：只更新数据绑定，不改变结构
public func quickUpdate(
    data: [String: Any],
    to component: Component,
    containerSize: CGSize
) {
    // 1. 更新绑定
    DataBindingManager.shared.bind(data: data, to: component)
    
    // 2. 重新计算布局
    let layoutResults = layoutEngine.calculateLayout(
        for: component, 
        containerSize: containerSize
    )
    applyLayoutResults(layoutResults, to: component)
    
    // 3. 更新视图
    updateViewTree(component)
}
```

**Tips**: 如果你确定结构不会变化，只是数据更新，使用 `quickUpdate` 比完整 Diff 更快。

---

## 性能优化

### 1. 快照预计算

```swift
// 创建快照时预计算 hash
let snapshot = ComponentSnapshot(from: component)

// 比较时直接比较 hash
if snapshot.styleHash == other.styleHash { ... }
```

### 2. 短路比较

```swift
func canMatch(_ other: ComponentSnapshot) -> Bool {
    // 类型不同直接返回 false
    if type != other.type { return false }
    
    // 有 key 时优先使用 key
    if let key1 = key, let key2 = other.key {
        return key1 == key2
    }
    
    return id == other.id
}
```

### 3. 批量布局

```swift
// 所有操作完成后，统一重新计算布局
// 而不是每个操作后都计算
let layoutResults = layoutEngine.calculateLayout(
    for: rootComponent, 
    containerSize: containerSize
)
```

### 4. 删除操作后执行

```swift
// 分离删除操作，最后执行
// 避免索引失效问题
for operation in deleteOperations.reversed() {
    applyOperation(operation, ...)
}
```

### 性能数据

| 场景 | 全量渲染 | 增量更新 | 节省 |
|------|---------|---------|------|
| 单属性变化（1 个组件） | 3ms | 0.5ms | 83% |
| 列表新增 1 项（20 项列表） | 15ms | 2ms | 87% |
| 列表删除 1 项（20 项列表） | 15ms | 1.5ms | 90% |
| 列表交换顺序（20 项列表） | 15ms | 3ms | 80% |
| 无变化 | 3ms | 0.1ms | 97% |

---

## 使用示例

### 基础用法

```swift
// 初次渲染
let data: [String: Any] = [
    "user": ["name": "张三", "likeCount": 100]
]
let view = TemplateX.render(json: template, data: data)!
containerView.addSubview(view)

// 数据更新 → 增量更新
let newData: [String: Any] = [
    "user": ["name": "张三", "likeCount": 101]  // 只有 likeCount 变了
]
TemplateX.update(view: view, data: newData)
```

### 列表场景（使用 key）

```json
{
  "type": "list",
  "props": {
    "items": "${items}",
    "itemTemplate": {
      "type": "container",
      "bindings": {
        "key": "${item.id}"
      },
      "children": [
        { "type": "text", "props": { "text": "${item.title}" } }
      ]
    }
  }
}
```

**Tips**: 列表场景一定要指定 `key`，否则可能导致不必要的删除/插入操作。

### 动画效果

```swift
// 开启 Patch 动画
DiffPatcher.shared.config.enableAnimation = true
DiffPatcher.shared.config.animationDuration = 0.3

// 更新时会自动添加淡入淡出动画
TemplateX.update(view: view, data: newData)
```

---

## 小结

本文介绍了 TemplateX 增量更新的完整设计与实现：

| 模块 | 技术要点 |
|------|---------|
| **DiffOperation** | 5 种操作类型：INSERT, DELETE, UPDATE, MOVE, REPLACE |
| **ViewDiffer** | 双端比较 + Key Map 算法，借鉴 React/Vue |
| **ComponentSnapshot** | 轻量级快照，预计算 hash |
| **DiffPatcher** | 分离删除操作，批量布局，支持动画 |

**核心优化**：
- 同层比较（O(n) 复杂度）
- 双端比较（快速处理头尾不变场景）
- Key 优化（列表场景精准匹配）
- 批量布局（减少重复计算）
- 快照 hash（O(1) 属性比较）

---

## 下一篇预告

下一篇我们将深入 **GapWorker 列表优化**，包括：

- 帧空闲时间利用原理
- Cell 预取任务调度
- 与 UICollectionView 集成
- 性能对比分析

---

## 系列文章

1. TemplateX 概述与架构设计
2. 模板解析与组件系统
3. Flexbox 布局引擎
4. 表达式引擎与数据绑定
5. **Diff + Patch 增量更新**（本文）
6. GapWorker 列表优化
7. 性能优化实战

---

## 参考资料

- [React Reconciliation](https://reactjs.org/docs/reconciliation.html) - React Diff 算法
- [Vue 2 Virtual DOM Diff](https://github.com/vuejs/vue/blob/dev/src/core/vdom/patch.js) - Vue 双端比较
- [Inferno Diff Algorithm](https://github.com/infernojs/inferno) - 最快的 Virtual DOM 库
