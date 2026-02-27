# TemplateX Flexbox 布局引擎

> 本文是 TemplateX 系列文章的第 3 篇，深入讲解基于 Yoga 的 Flexbox 布局引擎实现。

## 先看问题

我们有一个嵌套的组件树：

```json
{
  "type": "container",
  "style": { "flexDirection": "row", "padding": 16 },
  "children": [
    { "type": "image", "style": { "width": 60, "height": 60 } },
    { 
      "type": "container",
      "style": { "flexGrow": 1, "marginLeft": 12 },
      "children": [
        { "type": "text", "props": { "text": "标题" } },
        { "type": "text", "props": { "text": "副标题" } }
      ]
    }
  ]
}
```

**问题：如何计算每个组件的 frame？**

这就是布局引擎要解决的问题。

---

## 为什么选择 Yoga？

### 方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| **手动计算** | 简单、无依赖 | 复杂布局难以实现 |
| **AutoLayout** | iOS 原生 | 性能差、主线程 |
| **UIStackView** | 简单 | 功能有限 |
| **Yoga** | 完整 Flexbox、高性能 | 引入依赖 |

**选择 Yoga 的理由：**

1. **完整的 Flexbox 支持**：对齐 Web 标准
2. **高性能**：C 语言实现，~0.1ms 计算 50 个节点
3. **线程安全**：可在子线程计算布局
4. **跨平台**：Facebook 开源，React Native 验证

### Yoga 基础概念

```
┌─────────────────────────────────────────────────────────────┐
│                        Flexbox 术语                          │
└─────────────────────────────────────────────────────────────┘

  主轴 (Main Axis)
  ─────────────────────────────────────────▶
  ┌─────────────────────────────────────────┐
  │ ┌───────┐  ┌───────┐  ┌───────┐        │ ▲
  │ │ Item1 │  │ Item2 │  │ Item3 │        │ │ 交叉轴
  │ └───────┘  └───────┘  └───────┘        │ │ (Cross Axis)
  └─────────────────────────────────────────┘ ▼
  
  flexDirection: row      → 主轴水平
  flexDirection: column   → 主轴垂直
  
  justifyContent  → 主轴对齐
  alignItems      → 交叉轴对齐
```

---

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    YogaLayoutEngine                          │
│                    (布局引擎封装)                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
        ┌───────────┐ ┌───────────┐ ┌───────────┐
        │ YogaC     │ │ YogaNode  │ │ Component │
        │ Bridge    │ │   Pool    │ │   Style   │
        └───────────┘ └───────────┘ └───────────┘
              │             │             │
              ▼             ▼             ▼
        ┌─────────────────────────────────────┐
        │            Yoga C API               │
        │   (YGNodeNew, YGNodeCalculate...)   │
        └─────────────────────────────────────┘
```

### 为什么用 C API？

Yoga 有两套 API：

| API | 特点 |
|-----|------|
| **Yoga.swift** | Swift 封装，方便使用 |
| **Yoga C API** | 原生 C 函数，最高性能 |

**选择 C API 的理由：**

1. **子线程调用**：Swift 包装有 `@MainActor` 限制
2. **减少 Swift 开销**：无 ARC、无动态派发
3. **性能极致**：与 Yoga 原生性能一致

```swift
// C API - 可在任意线程调用
let node = YGNodeNew()
YGNodeStyleSetWidth(node, 100)
YGNodeStyleSetHeight(node, 50)
YGNodeCalculateLayout(node, Float.nan, Float.nan, .LTR)

// Swift 封装 - 可能有主线程限制
let node = YGNode()  // @MainActor
node.width = 100
```

---

## YogaCBridge：C API 桥接

### 设计目标

1. 提供类型安全的 Swift 接口
2. 封装常用操作，减少重复代码
3. 使用 `@inlinable` 确保零开销

### 核心实现

```swift
/// Yoga C API 的 Swift 封装
public final class YogaCBridge {
    public static let shared = YogaCBridge()
    
    // MARK: - 节点创建
    
    @inlinable
    public func createNode() -> YGNodeRef {
        return YGNodeNew()
    }
    
    @inlinable
    public func freeNode(_ node: YGNodeRef) {
        YGNodeFree(node)
    }
    
    // MARK: - 树结构
    
    @inlinable
    public func insertChild(_ child: YGNodeRef, into parent: YGNodeRef, at index: Int) {
        YGNodeInsertChild(parent, child, size_t(index))
    }
    
    @inlinable
    public func removeChild(_ child: YGNodeRef, from parent: YGNodeRef) {
        YGNodeRemoveChild(parent, child)
    }
    
    // MARK: - 布局计算
    
    @inlinable
    public func calculateLayout(
        _ node: YGNodeRef,
        width: Float,
        height: Float,
        direction: YGDirection = .LTR
    ) {
        YGNodeCalculateLayout(node, width, height, direction)
    }
    
    // MARK: - 布局结果
    
    @inlinable
    public func getLayoutFrame(_ node: YGNodeRef) -> CGRect {
        return CGRect(
            x: CGFloat(YGNodeLayoutGetLeft(node)),
            y: CGFloat(YGNodeLayoutGetTop(node)),
            width: CGFloat(YGNodeLayoutGetWidth(node)),
            height: CGFloat(YGNodeLayoutGetHeight(node))
        )
    }
}
```

### 样式应用

```swift
extension YogaCBridge {
    /// 从 ComponentStyle 应用所有布局属性
    public func applyStyle(_ style: ComponentStyle, to node: YGNodeRef) {
        // 尺寸
        applyDimension(style.width, setter: setWidth, percentSetter: setWidthPercent, 
                       autoSetter: setWidthAuto, to: node)
        applyDimension(style.height, setter: setHeight, percentSetter: setHeightPercent, 
                       autoSetter: setHeightAuto, to: node)
        
        // Flex 属性
        if let direction = style.flexDirection {
            YGNodeStyleSetFlexDirection(node, direction.toYoga())
        }
        if let wrap = style.flexWrap {
            YGNodeStyleSetFlexWrap(node, wrap.toYoga())
        }
        YGNodeStyleSetFlexGrow(node, Float(style.flexGrow))
        YGNodeStyleSetFlexShrink(node, Float(style.flexShrink))
        
        // 对齐
        if let justify = style.justifyContent {
            YGNodeStyleSetJustifyContent(node, justify.toYoga())
        }
        if let align = style.alignItems {
            YGNodeStyleSetAlignItems(node, align.toYoga())
        }
        
        // 边距
        applyEdgeInsets(style.margin, setter: YGNodeStyleSetMargin, to: node)
        applyEdgeInsets(style.padding, setter: YGNodeStyleSetPadding, to: node)
        
        // Display（重要：控制是否参与布局）
        YGNodeStyleSetDisplay(node, style.display == .none ? .none : .flex)
    }
}
```

---

## YogaNodePool：节点复用

### 为什么需要节点池？

每次布局都创建/销毁 YGNode 会产生内存分配开销：

```swift
// 无池化：每次布局都分配内存
for _ in 0..<100 {
    let node = YGNodeNew()    // 分配
    // ... 使用
    YGNodeFree(node)          // 释放
}

// 有池化：复用已有节点
for _ in 0..<100 {
    let node = pool.acquire() // 从池获取（可能复用）
    // ... 使用
    pool.release(node)        // 归还池
}
```

### 实现

```swift
public final class YogaNodePool {
    public static let shared = YogaNodePool()
    
    private var pool: [YGNodeRef] = []
    private let maxPoolSize: Int = 256
    private var unfairLock = os_unfair_lock()
    
    /// 获取节点
    public func acquire() -> YGNodeRef {
        os_unfair_lock_lock(&unfairLock)
        
        if let node = pool.popLast() {
            os_unfair_lock_unlock(&unfairLock)
            YGNodeReset(node)  // 重置状态
            return node
        }
        
        os_unfair_lock_unlock(&unfairLock)
        return YGNodeNew()  // 池空，创建新节点
    }
    
    /// 归还节点
    public func release(_ node: YGNodeRef) {
        // 从父节点移除
        if let owner = YGNodeGetOwner(node) {
            YGNodeRemoveChild(owner, node)
        }
        YGNodeRemoveAllChildren(node)
        
        os_unfair_lock_lock(&unfairLock)
        
        if pool.count < maxPoolSize {
            pool.append(node)
            os_unfair_lock_unlock(&unfairLock)
        } else {
            os_unfair_lock_unlock(&unfairLock)
            YGNodeFree(node)  // 池满，直接释放
        }
    }
    
    /// 批量获取（减少锁竞争）
    public func acquireBatch(count: Int) -> [YGNodeRef] {
        var result: [YGNodeRef] = []
        result.reserveCapacity(count)
        
        os_unfair_lock_lock(&unfairLock)
        let availableCount = min(count, pool.count)
        if availableCount > 0 {
            result.append(contentsOf: pool.suffix(availableCount))
            pool.removeLast(availableCount)
        }
        os_unfair_lock_unlock(&unfairLock)
        
        // 在锁外创建剩余节点
        for _ in 0..<(count - availableCount) {
            result.append(YGNodeNew())
        }
        
        return result
    }
}
```

### 为什么用 os_unfair_lock？

iOS 锁性能对比（加解锁一次）：

| 锁类型 | 耗时 | 倍数 |
|--------|------|------|
| **os_unfair_lock** | ~20ns | 1x |
| pthread_mutex | ~100ns | 5x |
| NSLock | ~150ns | 7.5x |
| DispatchQueue | ~200ns | 10x |

**os_unfair_lock 是 iOS 上最快的锁。**

---

## YogaLayoutEngine：布局引擎

### 布局流程

```
┌─────────────────────────────────────────────────────────────┐
│                      calculateLayout()                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  1. 构建 Yoga 树                                             │
│     ┌─────────────────────────────────────────────────────┐ │
│     │ Component Tree        →        YGNode Tree          │ │
│     │                                                     │ │
│     │   Container              YGNode (root)              │ │
│     │   ├─ Image       →       ├─ YGNode                  │ │
│     │   └─ Container           └─ YGNode                  │ │
│     │      ├─ Text                ├─ YGNode               │ │
│     │      └─ Text                └─ YGNode               │ │
│     └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 计算布局                                                 │
│     YGNodeCalculateLayout(root, containerWidth, NaN, LTR)   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  3. 收集结果                                                 │
│     遍历 YGNode 树，获取每个节点的 frame                     │
│     存入 [componentId: LayoutResult] 字典                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  4. 释放 Yoga 树（全量模式）                                 │
│     或保留给下次复用（增量模式）                             │
└─────────────────────────────────────────────────────────────┘
```

### 核心代码

```swift
public final class YogaLayoutEngine {
    public static let shared = YogaLayoutEngine()
    
    private let bridge = YogaCBridge.shared
    private let nodePool = YogaNodePool.shared
    
    /// 是否启用增量布局
    public var enableIncrementalLayout: Bool = true
    
    /// 计算布局
    public func calculateLayout(
        for component: Component,
        containerSize: CGSize
    ) -> [String: LayoutResult] {
        
        // 1. 构建 Yoga 树
        var nodeMap: [String: YGNodeRef] = [:]
        let rootNode: YGNodeRef
        
        if enableIncrementalLayout {
            rootNode = buildOrUpdateYogaTree(component: component, nodeMap: &nodeMap)
        } else {
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
        
        // 4. 释放（仅全量模式）
        if !enableIncrementalLayout {
            nodePool.releaseTree(rootNode)
        }
        
        return results
    }
    
    // 全量构建 Yoga 树
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
}
```

---

## 文本测量

### 问题

文本组件的尺寸取决于内容。Yoga 需要知道文本的实际大小：

```
┌────────────────────────────────────────┐
│  "Hello World"                          │  ← 文本内容
│                                         │
│  给定最大宽度 200pt                      │
│  计算出高度 = ?                          │
└────────────────────────────────────────┘
```

### Yoga 测量函数

```swift
/// 文本测量回调（C 函数）
private let textMeasureFunc: YGMeasureFunc = { node, width, widthMode, height, heightMode in
    // 1. 获取上下文
    guard let contextPtr = YGNodeGetContext(node) else {
        return YGSize(width: 0, height: 0)
    }
    let context = Unmanaged<TextMeasureContext>.fromOpaque(contextPtr).takeUnretainedValue()
    
    // 2. 创建字体
    let font = UIFont.systemFont(ofSize: context.fontSize, weight: context.fontWeight)
    
    // 3. 计算约束宽度
    let maxWidth: CGFloat
    switch widthMode {
    case .exactly, .atMost:
        maxWidth = CGFloat(width)
    default:
        maxWidth = .greatestFiniteMagnitude
    }
    
    // 4. 测量文本
    let constraintSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
    let rect = (context.text as NSString).boundingRect(
        with: constraintSize,
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font],
        context: nil
    )
    
    // 5. 返回尺寸
    return YGSize(
        width: Float(ceil(rect.width)),
        height: Float(ceil(rect.height))
    )
}
```

### 设置测量函数

```swift
private func setupTextMeasureFunc(node: YGNodeRef, textComponent: TextComponent) {
    // 创建上下文
    let context = TextMeasureContext(
        text: textComponent.text,
        fontSize: textComponent.fontSize ?? 14,
        fontWeight: parseFontWeight(textComponent.fontWeight),
        lineHeight: textComponent.lineHeight,
        numberOfLines: textComponent.numberOfLines
    )
    
    // 持有上下文（防止被释放）
    let contextPtr = Unmanaged.passRetained(context).toOpaque()
    YGNodeSetContext(node, contextPtr)
    
    // 设置测量函数
    YGNodeSetMeasureFunc(node, textMeasureFunc)
}
```

---

## 增量布局优化（Yoga 剪枝）

### 原理

Yoga 内部有脏检测机制：

1. 节点被修改后标记为 **dirty**
2. 计算布局时，只计算 dirty 节点
3. clean 节点直接复用上次结果

```
首次布局：
┌──────────────────────────────────────┐
│  Root (dirty)                        │
│  ├─ Item1 (dirty)   ← 全部计算       │
│  ├─ Item2 (dirty)                    │
│  └─ Item3 (dirty)                    │
└──────────────────────────────────────┘

二次布局（样式未变化）：
┌──────────────────────────────────────┐
│  Root (clean)                        │
│  ├─ Item1 (clean)   ← 全部跳过       │
│  ├─ Item2 (clean)                    │
│  └─ Item3 (clean)                    │
└──────────────────────────────────────┘

二次布局（Item2 样式变化）：
┌──────────────────────────────────────┐
│  Root (dirty)       ← 父节点也变脏   │
│  ├─ Item1 (clean)   ← 跳过           │
│  ├─ Item2 (dirty)   ← 只计算这个     │
│  └─ Item3 (clean)   ← 跳过           │
└──────────────────────────────────────┘
```

### 实现

```swift
/// 增量构建 Yoga 树
private func buildOrUpdateYogaTree(
    component: Component,
    nodeMap: inout [String: YGNodeRef]
) -> YGNodeRef {
    
    let node: YGNodeRef
    
    if let existingNode = component.yogaNode {
        // 已有节点：检查样式是否变化
        node = existingNode
        
        if let lastStyle = component.lastLayoutStyle {
            if lastStyle != component.style {
                // 样式变化：重新应用
                bridge.applyStyle(component.style, to: node)
                component.lastLayoutStyle = component.style
                
                // 叶子节点标记 dirty
                if component is TextComponent {
                    bridge.markDirty(node)
                }
            }
            // 样式未变化，节点保持 clean
        } else {
            // 首次应用
            bridge.applyStyle(component.style, to: node)
            component.lastLayoutStyle = component.style
        }
    } else {
        // 新节点
        node = nodePool.acquire()
        component.yogaNode = node
        bridge.applyStyle(component.style, to: node)
        component.lastLayoutStyle = component.style
    }
    
    nodeMap[component.id] = node
    
    // 递归处理子节点...
    
    return node
}
```

### 性能收益

| 场景 | 全量模式 | 增量模式 | 提升 |
|------|---------|---------|------|
| 首次布局 | 0.25ms | 0.25ms | - |
| 二次布局（无变化） | 0.25ms | ~0.01ms | **25x** |
| 二次布局（部分变化） | 0.25ms | 0.08ms | 3x |

---

## 样式支持

### ComponentStyle

TemplateX 使用统一的 `ComponentStyle` 存储所有样式：

```swift
public struct ComponentStyle: Equatable {
    // MARK: - 布局属性
    
    /// 尺寸
    public var width: Dimension?
    public var height: Dimension?
    public var minWidth: CGFloat?
    public var maxWidth: CGFloat?
    public var minHeight: CGFloat?
    public var maxHeight: CGFloat?
    
    /// Flexbox
    public var flexDirection: FlexDirection?
    public var flexWrap: FlexWrap?
    public var justifyContent: JustifyContent?
    public var alignItems: AlignItems?
    public var alignSelf: AlignSelf?
    public var flexGrow: CGFloat = 0
    public var flexShrink: CGFloat = 1
    public var flexBasis: Dimension?
    
    /// 边距
    public var margin: EdgeInsets = .zero
    public var padding: EdgeInsets = .zero
    
    /// 定位
    public var position: PositionType?
    public var top: CGFloat?
    public var left: CGFloat?
    public var right: CGFloat?
    public var bottom: CGFloat?
    
    /// 显示控制
    public var display: Display = .flex
    public var visibility: Visibility = .visible
    
    // MARK: - 视觉属性
    
    public var backgroundColor: UIColor?
    public var cornerRadius: CGFloat = 0
    public var borderWidth: CGFloat = 0
    public var borderColor: UIColor?
    // ...
}
```

### Dimension 类型

支持多种尺寸单位：

```swift
public enum Dimension: Equatable {
    case point(CGFloat)      // 固定值：100
    case percent(CGFloat)    // 百分比：50%
    case auto                // 自动
    
    /// 从字符串解析
    static func parse(_ value: Any?) -> Dimension? {
        if let str = value as? String {
            if str == "auto" { return .auto }
            if str.hasSuffix("%") {
                let numStr = String(str.dropLast())
                if let num = Double(numStr) {
                    return .percent(CGFloat(num))
                }
            }
        }
        if let num = value as? Double {
            return .point(CGFloat(num))
        }
        return nil
    }
}
```

---

## 使用示例

### 基础布局

```json
{
  "type": "container",
  "style": {
    "width": "100%",
    "flexDirection": "row",
    "justifyContent": "space-between",
    "alignItems": "center",
    "padding": 16
  },
  "children": [
    { "type": "text", "props": { "text": "左侧" } },
    { "type": "text", "props": { "text": "右侧" } }
  ]
}
```

### Flex 布局

```json
{
  "type": "container",
  "style": { "flexDirection": "row" },
  "children": [
    { 
      "type": "container",
      "style": { "width": 80, "height": 80 }
    },
    {
      "type": "container",
      "style": { "flexGrow": 1, "marginLeft": 12 }
    }
  ]
}
```

### 绝对定位

```json
{
  "type": "container",
  "style": { "width": "100%", "height": 200 },
  "children": [
    {
      "type": "container",
      "style": {
        "position": "absolute",
        "top": 10,
        "right": 10,
        "width": 40,
        "height": 40
      }
    }
  ]
}
```

---

## 下一篇预告

本文介绍了 TemplateX 的 Flexbox 布局引擎实现。下一篇我们将深入 **表达式引擎与数据绑定**，包括：

- `${expression}` 表达式语法
- ANTLR4 词法/语法分析
- 内置函数库
- 条件显示与动态样式

---

## 系列文章

1. [TemplateX 概述与架构设计](./01-TemplateX-Overview.md)
2. [模板解析与组件系统](./02-Template-Parser-Components.md)
3. **Flexbox 布局引擎**（本文）
4. 表达式引擎与数据绑定
5. Diff + Patch 增量更新
6. GapWorker 列表优化
7. 性能优化实战
