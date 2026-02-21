# TemplateX - iOS DSL 动态渲染引擎

## 项目概述

TemplateX 是一个高性能的 iOS DSL 动态化渲染框架，支持通过 JSON 模板驱动 UI 渲染，具备完整的 Flexbox 布局能力、数据绑定、增量更新（Diff）等特性。

### 核心特性

- **JSON → UIView 渲染**：声明式 UI，模板驱动
- **Flexbox 布局**：基于 Yoga C API，支持子线程布局计算
- **数据绑定**：`${expression}` 表达式求值
- **增量更新**：Diff + Patch 算法，最小化视图操作
- **组件化**：可扩展的组件注册机制
- **高性能**：组件树复用、布局缓存、异步渲染

---

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                    RenderEngine                         │
│                   (渲染引擎入口)                          │
└────────────────┬────────────────────────────────────────┘
                 │
    ┌────────────┼────────────┬──────────────┐
    │            │            │              │
    ▼            ▼            ▼              ▼
┌────────┐  ┌─────────┐  ┌─────────┐   ┌──────────┐
│Template│  │  Yoga   │  │  View   │   │   Diff   │
│ Parser │  │ Layout  │  │ Create  │   │  Patcher │
└────────┘  └─────────┘  └─────────┘   └──────────┘
    │            │            │              │
    ▼            ▼            ▼              ▼
┌────────┐  ┌─────────┐  ┌─────────┐   ┌──────────┐
│Component│ │YogaC API│  │Component│   │ViewDiffer│
│Registry │ │NodePool │  │  Pool   │   │  Result  │
└────────┘  └─────────┘  └─────────┘   └──────────┘
```

---

## 目录结构

```
TemplateX/                               # Git 仓库根目录
├── TemplateX/                           # 核心库
│   └── Sources/
│       ├── TemplateX.swift              # 入口 API
│       ├── Core/
│       │   ├── Engine/
│       │   │   ├── RenderEngine.swift       # 核心渲染引擎
│       │   │   └── ListPreloadManager.swift # 列表预加载管理
│       │   ├── Layout/
│       │   │   ├── YogaLayoutEngine.swift   # Yoga 布局引擎封装
│       │   │   ├── YogaCBridge.swift        # Yoga C API 桥接
│       │   │   ├── YogaNodePool.swift       # Yoga 节点池
│       │   │   └── LayoutTypes.swift        # 布局类型定义
│       │   ├── GapWorker/                   # 帧空闲时间任务调度（对标 Lynx）
│       │   │   ├── GapTask.swift            # 任务协议 + TaskBundle
│       │   │   ├── TemplateXGapWorker.swift # 核心调度器（CADisplayLink）
│       │   │   ├── PrefetchRegistry.swift   # 预取位置收集器
│       │   │   └── CellPrefetchTask.swift   # Cell 预取任务 + 缓存
│       │   ├── Template/
│       │   │   ├── TemplateParser.swift     # 模板解析器 + 缓存
│       │   │   ├── JSONWrapper.swift        # JSON 封装工具
│       │   │   └── StyleParser.swift        # 样式批量解析器（性能优化）
│       │   ├── Binding/
│       │   │   └── DataBindingManager.swift # 数据绑定管理
│       │   ├── Expression/
│       │   │   └── ExpressionEngine.swift   # 表达式引擎
│       │   ├── Diff/
│       │   │   ├── ViewDiffer.swift         # Diff 算法
│       │   │   └── DiffPatcher.swift        # Patch 应用
│       │   ├── Cache/
│       │   │   ├── ComponentPool.swift      # 组件池
│       │   │   └── LRUCache.swift           # LRU 缓存
│       │   ├── Event/
│       │   │   ├── EventManager.swift       # 事件管理
│       │   │   └── GestureHandler.swift     # 手势处理
│       │   └── Performance/
│       │       ├── PerformanceMonitor.swift # 性能监控
│       │       └── PreRenderOptimizer.swift # 预渲染优化
│       ├── Components/
│       │   ├── Component.swift              # 组件协议 + 基类 + 注册表
│       │   ├── Views/
│       │   │   ├── ViewComponent.swift      # 基础视图
│       │   │   ├── TextComponent.swift      # 文本
│       │   │   ├── ImageComponent.swift     # 图片
│       │   │   ├── ButtonComponent.swift    # 按钮
│       │   │   ├── InputComponent.swift     # 输入框
│       │   │   ├── ScrollComponent.swift    # 滚动视图
│       │   │   └── ListComponent.swift      # 列表
│       │   └── Layouts/
│       │       └── FlexLayoutComponent.swift # Flex 布局容器
│       └── Service/                         # Service 协议层
│           ├── ServiceRegistry.swift        # DI 容器
│           ├── ImageLoader/
│           │   └── TemplateXImageLoader.swift  # 图片加载协议
│           └── LogProvider/
│               ├── TemplateXLogProvider.swift  # 日志协议
│               ├── DefaultLogProvider.swift    # 默认实现（os.Logger）
│               └── TXLogger.swift              # 日志门面类
├── TemplateXService/                    # Service 实现层
│   ├── Image/
│   │   └── SDWebImageLoader.swift       # SDWebImage 实现
│   └── Log/
│       └── ConsoleLogProvider.swift     # Console 日志实现
├── Compiler/                            # XML 编译器（开发工具，不打包到库）
│   └── ...                              
├── Example/
│   └── TemplateXDemo/                   # 示例 App
├── Tests/
│   └── ...                              # 单元测试
├── TemplateX.podspec                    # 核心库 podspec
└── TemplateXService.podspec             # Service 实现 podspec
```

---

## 核心模块说明

### 1. RenderEngine (渲染引擎)

**文件**: `Sources/Core/Engine/RenderEngine.swift`

核心职责：
1. 解析模板 → 组件树
2. 计算布局
3. 创建/更新视图
4. 支持增量更新（Diff）

```swift
// 同步渲染
let view = RenderEngine.shared.render(
    json: template,
    data: data,
    containerSize: CGSize(width: 375, height: .nan)
)

// 增量更新
RenderEngine.shared.update(view: view, data: newData, containerSize: size)
```

### 2. YogaLayoutEngine (布局引擎)

**文件**: `Sources/Core/Layout/YogaLayoutEngine.swift`

基于 Yoga C API 的布局引擎：
- 支持子线程布局计算
- 使用 YogaNodePool 复用节点
- 从统一的 ComponentStyle 读取布局属性
- **支持增量布局（Yoga 剪枝）**：复用组件上的 YGNode，样式变化时标记 dirty

```swift
// 计算布局
let results = YogaLayoutEngine.shared.calculateLayout(
    for: component,
    containerSize: containerSize
)

// 开关增量布局（默认开启）
YogaLayoutEngine.shared.enableIncrementalLayout = true

// 组件回收时释放 Yoga 节点
component.releaseYogaNode()
```

### 3. ComponentStyle (统一样式)

**文件**: `Sources/Components/Component.swift`

统一的样式结构，包含：
- **布局属性**: width, height, margin, padding, flex*, position 等
- **视觉属性**: backgroundColor, cornerRadius, border, shadow, opacity 等
- **文本属性**: fontSize, fontWeight, textColor, textAlign, lineHeight 等
- **显示控制**: display (.flex/.none), visibility (.visible/.hidden)

### 4. Component (组件系统)

**文件**: `Sources/Components/Component.swift`

组件协议和基类：
```swift
public protocol Component: AnyObject {
    var id: String { get }
    var type: String { get }
    var style: ComponentStyle { get set }
    var children: [Component] { get set }
    var view: UIView? { get set }
    
    // Yoga 剪枝优化
    var yogaNode: YGNodeRef? { get set }
    var lastLayoutStyle: ComponentStyle? { get set }
    func releaseYogaNode()
    
    func createView() -> UIView
    func updateView()
    func clone() -> Component
}
```

内置组件：
- `view` - 基础视图
- `text` - 文本
- `image` - 图片
- `button` - 按钮
- `input` - 输入框
- `scroll` - 滚动视图
- `list` - 列表
- `flex` / `container` - Flex 布局容器

#### ListComponent 属性详解

`list` 组件支持以下 props：

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| direction | String | "vertical" | 滚动方向："horizontal" / "vertical" |
| columns | Int | 1 | 列数（垂直滚动时有效） |
| rows | Int | - | 行数（横向滚动 + rows > 1 时使用纵向优先布局） |
| rowSpacing | CGFloat | 0 | 行间距 |
| columnSpacing | CGFloat | 0 | 列间距 |
| showsIndicator | Bool | true | 是否显示滚动条 |
| bounces | Bool | true | 是否有弹性效果 |
| isPagingEnabled | Bool | false | 是否启用分页滚动 |
| itemWidth | CGFloat | - | 固定 item 宽度（横向滚动时优先使用） |
| itemHeight | CGFloat | - | 固定 item 高度 |
| estimatedItemHeight | CGFloat/String | - | 预估 item 高度，支持表达式（如 `"${itemWidth + 50}"`） |
| autoAdjustHeight | Bool | false | 自动调整列表高度（根据 Cell 最大高度） |
| items | String | - | 数据源绑定表达式（如 `"${section.items}"`） |
| itemTemplate | Object | - | Cell 模板 JSON |
| contentInsetLeft/Right/Top/Bottom | CGFloat | 0 | 内容边距 |

**autoAdjustHeight 使用场景**：

适用于横向滚动列表，Cell 高度不固定时自动调整列表容器高度。工作流程：
1. 遍历所有数据项，计算每个 Cell 的渲染高度
2. 取最大高度作为列表容器高度
3. 所有 Cell 使用统一的最大高度

```json
{
  "type": "list",
  "props": {
    "direction": "horizontal",
    "autoAdjustHeight": true,
    "estimatedItemHeight": 150,
    "items": "${section.items}",
    "itemTemplate": { ... }
  },
  "style": {
    "width": "100%"
  }
}
```

**estimatedItemHeight 表达式支持**：

`estimatedItemHeight` 支持表达式，可以在数据绑定阶段动态计算：

```json
{
  "type": "list",
  "props": {
    "direction": "horizontal",
    "itemWidth": 100,
    "estimatedItemHeight": "${itemWidth * 1.5 + 20}",
    "items": "${items}"
  }
}
```

**lineHeight 解析规则**：

文本组件的 `lineHeight` 属性采用智能解析：
- `lineHeight <= 4`：视为倍数（如 1.3 = 1.3 倍行高）
- `lineHeight > 4`：视为像素值（如 20 = 20pt 行高）

```json
{
  "type": "text",
  "props": { "text": "Hello" },
  "style": {
    "fontSize": 14,
    "lineHeight": 1.5
  }
}
```

### 5. 扩展机制

#### 自定义组件注册

**核心协议**：`ComponentFactory`（定义在 `Component.swift`）

```swift
/// 组件工厂协议
public protocol ComponentFactory: AnyObject {
    /// 组件类型标识，对应模板中的 "type" 字段
    static var typeIdentifier: String { get }
    
    /// 从 JSON 创建组件实例
    static func create(from json: JSONWrapper) -> Component
}
```

**注册方式**：

```swift
// 方式1: 通过 TemplateX 入口（推荐）
TemplateX.register(VideoComponent.self)

// 方式2: 直接调用 Registry
ComponentRegistry.shared.register(VideoComponent.self)
```

**自定义组件示例**：

```swift
public class VideoComponent: BaseComponent, ComponentFactory {
    public static var typeIdentifier: String { "video" }
    
    public static func create(from json: JSONWrapper) -> Component {
        let component = VideoComponent(id: json.string("id") ?? UUID().uuidString, type: typeIdentifier)
        component.parseBaseParams(from: json)  // 解析通用样式
        // 解析 video 特有的 props
        component.videoUrl = json.child("props")?.string("src")
        return component
    }
    
    var videoUrl: String?
    
    public override func createView() -> UIView { /* 返回播放器视图 */ }
    public override func updateView() { /* 更新播放器状态 */ }
    public override func clone() -> Component { /* 返回副本 */ }
}
```

#### 自定义表达式函数

**核心协议**：`ExpressionFunction`（定义在 `BuiltinFunctions.swift`）

```swift
public protocol ExpressionFunction {
    var name: String { get }
    func execute(_ args: [Any]) -> Any?
}
```

**注册方式**：

```swift
// 方式1: 简单函数（闭包）
ExpressionEngine.shared.registerFunction(name: "formatPrice") { args in
    guard let price = args.first as? Double else { return "¥0.00" }
    return String(format: "¥%.2f", price)
}

// 方式2: 协议实现
struct FormatCurrencyFunction: ExpressionFunction {
    let name = "formatCurrency"
    func execute(_ args: [Any]) -> Any? { /* 实现 */ }
}
ExpressionEngine.shared.registerFunction(FormatCurrencyFunction())

// 方式3: 批量注册
ExpressionEngine.shared.registerFunctions([func1, func2, func3])
```

**内置函数**（`BuiltinFunctions.swift`）：
- 数学：`abs`, `max`, `min`, `round`, `floor`, `ceil`, `sqrt`, `pow`
- 字符串：`length`, `uppercase`, `lowercase`, `trim`, `substring`, `contains`, `startsWith`, `endsWith`, `replace`, `split`, `join`
- 格式化：`formatNumber`, `formatDate`
- 条件：`ifEmpty`, `ifNull`
- 类型转换：`toString`, `toNumber`, `toBoolean`
- 数组：`first`, `last`, `indexOf`, `reverse`

### 6. Diff + Patch (增量更新)

**文件**: 
- `Sources/Core/Diff/ViewDiffer.swift`
- `Sources/Core/Diff/DiffPatcher.swift`

增量更新流程：
1. 克隆旧组件树，绑定新数据
2. Diff 算法比较新旧组件树
3. Patch 应用差异到视图

---

## 性能优化

### 已实现的优化

1. **Yoga C API + 子线程布局**
   - 直接调用 Yoga C API，避免 Swift 包装开销
   - 支持在子线程计算布局
   - YogaNodePool 节点复用 + 批量获取（`acquireBatch`）

2. **组件复用**
   - ComponentPool 组件复用
   - 按组件类型分类存储
   - 列表场景使用 UICollectionView 内置复用机制

3. **UIView 创建优化**
   - UIView 创建耗时极低（<0.1ms），无需独立视图池
   - 列表场景依赖 UICollectionView/UITableView 内置 Cell 复用

4. **移除不必要的锁**
   - ComponentPool、EventManager、GestureHandlerManager 只在主线程访问，无需锁
   - 真正需要锁的场景：PreRenderOptimizer（后台预渲染）、LRUCache（通用缓存）

5. **LRUCache.ObjectPool Bug 修复**
   - `let lock` → `var lock`（os_unfair_lock 必须是 var）
   - 移除 `var l = lock` 副本创建

6. **渲染时机优化**
   - 在 `viewDidLoad` 同步渲染，避免白屏
   - 渲染耗时 ~10ms，不影响 push 动画流畅度

7. **日志系统优化（TXLogger）**
   - iOS 14+ 使用 `os.Logger`（高性能，支持 Instruments）
   - iOS 14 以下使用 `print` fallback（带开关）
   - 统一接口 `TXLogger`，自动选择实现
   - 日志级别：error, warning, info, debug, trace, verbose
   - verbose 级别仅 DEBUG 模式输出

8. **引擎预热（warmUp）**
   - `TemplateX.warmUp()` 在 App 启动时异步调用
   - 预热内容：ComponentRegistry、TemplateParser、YogaNodePool、RenderEngine、ImageLoader
   - 消除首次渲染的冷启动开销（从 6ms 降到 <1ms）
   - **SDWebImage 预热**：触发 `SDWebImageManager`、`SDImageCache`、`SDWebImageDownloader` 单例初始化，避免首次加载图片时的 ~3ms 开销

9. **视图样式残留 Bug 修复**
   - **问题**：增量更新时，复用视图的样式属性可能残留（如背景色）
   - **原因**：`applyStyle()` 只在样式属性有值时设置，不会在属性为 nil 时重置
   - **修复**：改为无条件应用所有样式属性，确保视图状态与组件样式一致
   - **影响**：backgroundColor、cornerRadius、borderWidth、shadowOpacity 等属性现在每次都会被设置

10. **updateView 阶段优化**
    - **样式缓存**：`_lastAppliedStyle` 缓存上次应用的样式，样式未变化时跳过
    - **frame 缓存**：`_lastAppliedFrame` 缓存上次 frame，位置未变化时跳过
    - **UIFont 缓存**：`TextComponent` 中缓存 UIFont，只在字体参数变化时重建
    - **图片 URL 缓存**：`ImageComponent` 避免重复加载相同图片
    - **forceApplyStyle 标记**：视图复用时强制应用样式

11. **Parser 解析优化（StyleParser）**
    - **批量解析模式**：一次遍历 JSON 字典，根据 key 分发到对应属性
    - **StyleKey 枚举映射**：字符串 key → 枚举值，O(1) 哈希查找
    - **静态枚举映射表**：FlexDirection/JustifyContent 等枚举使用预构建的静态字典
    - **减少字典查找**：原逐属性查询 40+ 次 → 现一次遍历
    - **消除重复类型转换**：在分发时直接处理类型

12. **Yoga 剪枝优化（Incremental Layout）**
    - **原理**：复用组件上缓存的 YGNode，只在样式变化时重新计算布局
    - **效果**：二次布局计算跳过未变化的节点，Yoga 内部会 skip clean 节点
    - **开关**：`YogaLayoutEngine.shared.enableIncrementalLayout = true`（默认开启）
    - **实现方式**：
      - 组件协议新增 `yogaNode: YGNodeRef?` 和 `lastLayoutStyle: ComponentStyle?`
      - `buildOrUpdateYogaTree()` 复用已有 YGNode，样式变化时调用 `markDirty()`
      - 组件回收时调用 `releaseYogaNode()` 释放 YGNode 和文本测量上下文
    - **性能收益**：
      - 首次布局：与全量模式相当
      - 二次布局（样式不变）：Yoga 直接跳过计算，接近 O(1)
      - 二次布局（部分样式变化）：只计算 dirty 子树
    - **影响范围**：YogaLayoutEngine、Component

### 性能数据

典型渲染耗时（6 个 Flexbox Demo，预热后）：
```
总耗时: ~10ms
单模板: 0.2ms - 0.6ms
布局计算: 0.04ms - 0.16ms
视图创建: 0.02ms - 0.10ms
```

首次渲染（无预热）：
```
首模板 parse: 6.59ms（冷启动）
后续 parse: 0.06ms - 0.21ms
```

---

## 开发规范

### 代码规范

1. **Swift 文件头**：不写 "Created by OpenCode"，直接省略
2. **中文注释**：核心逻辑用中文注释说明
3. **锁的使用**：
   - 只在主线程访问的数据结构**不需要锁**
   - 真正多线程场景使用 `os_unfair_lock`，**禁止使用 NSLock**
   - `os_unfair_lock` 必须是 `var`，不能是 `let`

### 编译验证

```bash
# 不要自己编译，由用户手动触发
cd TemplateX/Example
pod install
open TemplateXDemo.xcworkspace
```

### 调试日志

**日志系统架构**：
```
TXLogger（统一入口）
    ├── iOS 14+ → TXLog（os.Logger）
    └── iOS 14-  → TXLogLegacy（print）
```

**日志级别**：
| 级别 | 方法 | 说明 |
|------|------|------|
| error | `TXLogger.error()` | 错误，始终输出 |
| warning | `TXLogger.warning()` | 警告 |
| info | `TXLogger.info()` | 信息 |
| debug | `TXLogger.debug()` | 调试信息 |
| trace | `TXLogger.trace()` | 性能追踪 |
| verbose | `TXLogger.verbose()` | 高频详细日志（仅 DEBUG） |

**启用性能监控**：
```swift
RenderEngine.shared.config.enablePerformanceMonitor = true
```

**日志输出示例**：
```
[TemplateX][Trace] render(json): total=3.39ms | parse=1.07ms | bind=0.00ms | render=2.32ms
YogaLayoutEngine.calculateLayout: total=0.25ms | build=0.13ms | calc=0.09ms
ViewCreation: count=4 | createView=0.03ms | addSubview=0.03ms
```

**预热使用**：
```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) {
    // 异步预热（推荐）
    DispatchQueue.global(qos: .userInitiated).async {
        TemplateX.warmUp()  // 异步预热，消除首次渲染冷启动
    }
}
```

---

## 依赖

```ruby
# Podfile
s.dependency 'Yoga', '~> 3.0'
s.dependency 'Antlr4', '~> 4.0'  # 表达式解析
```

---

## 后续优化方向

1. ~~**日志系统迁移**~~：✅ 已完成，使用 `os.Logger`
2. ~~**引擎预热机制**~~：✅ 已完成，`TemplateX.warmUp()`
3. ~~**模板预编译**~~：✅ 已完成，`renderWithCache()` 实现模板原型缓存
4. ~~**Cell 场景优化**~~：✅ 已完成，支持高度计算和批量并发
5. ~~**视图预热**~~：已移除（UIView 创建耗时极低，无需预热）
6. ~~**Input 组件池化**~~：已移除（依赖系统视图创建）
7. ~~**GapWorker 帧空闲调度**~~：✅ 已完成，对标 Lynx 的 Cell 预取机制
8. **Instruments 分析**：进一步定位瓶颈

---

## Cell 场景优化 API

### 概述

针对 UICollectionView/UITableView 场景优化，解决以下问题：
- 避免重复 parse 模板
- Cell 复用时快速更新数据
- 高度计算与缓存
- 批量并发高度预计算

### 核心 API

#### 1. renderWithCache - 缓存渲染

```swift
/// 使用模板缓存渲染（适用于 Cell 场景）
///
/// 流程：
/// 1. 检查 componentTemplateCache 是否存在该 templateId 的原型
/// 2. 命中：clone → bind → layout → createView
/// 3. 未命中：parse → cache 原型 → 继续上述流程
///
/// - Parameters:
///   - json: 模板 JSON
///   - templateId: 模板标识符（缓存 key）
///   - data: 绑定数据
///   - containerSize: 容器尺寸
/// - Returns: 渲染的视图
public func renderWithCache(
    json: [String: Any],
    templateId: String,
    data: [String: Any]? = nil,
    containerSize: CGSize
) -> UIView?
```

#### 2. calculateHeight - 高度计算

```swift
/// 计算模板高度（只计算布局，不创建视图）
///
/// 用于 UICollectionView/UITableView 的 sizeForItemAt 回调
/// 使用高度缓存避免重复计算，缓存 key 为 templateId + containerWidth + data["id"]
///
/// - Parameters:
///   - json: 模板 JSON
///   - templateId: 模板标识符
///   - data: 绑定数据（需要包含 "id" 字段用于缓存）
///   - containerWidth: 容器宽度
///   - useCache: 是否使用高度缓存（默认 true）
/// - Returns: 计算得到的高度
public func calculateHeight(
    json: [String: Any],
    templateId: String,
    data: [String: Any]? = nil,
    containerWidth: CGFloat,
    useCache: Bool = true
) -> CGFloat
```

#### 3. calculateHeightsBatch - 批量高度计算

```swift
/// 批量并发计算高度
///
/// 用于 UICollectionView prefetch 场景，子线程并发执行 parse + bind + layout
///
/// - Parameters:
///   - tasks: 高度计算任务列表
///   - completion: 完成回调（主线程）
public func calculateHeightsBatch(
    _ tasks: [HeightCalculationTask],
    completion: @escaping ([HeightCalculationResult]) -> Void
)

/// 同步版本（必须在主线程调用）
public func calculateHeightsBatchSync(
    _ tasks: [HeightCalculationTask]
) -> [HeightCalculationResult]
```

#### 4. 缓存管理

```swift
/// 清理模板原型缓存
public func clearTemplateCache(templateId: String? = nil)

/// 清理高度缓存
public func clearHeightCache(templateId: String? = nil)

/// 获取缓存数量
public var templateCacheCount: Int
public var heightCacheCount: Int
```

### TemplateXCell 使用示例

```swift
// ListDataSource.cellForItemAt
func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TemplateXCell.reuseIdentifier, for: indexPath) as! TemplateXCell
    
    let itemData = dataSource[indexPath.item]
    let cellSize = calculateCellSize(collectionView: collectionView)
    
    cell.configure(
        with: cellTemplate,
        templateId: "my_cell_template",
        data: itemData,
        index: indexPath.item,
        containerSize: cellSize
    )
    
    return cell
}

// ListDelegate.sizeForItemAt
func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let itemData = dataSource[indexPath.item]
    var context: [String: Any] = itemData as? [String: Any] ?? ["item": itemData]
    context["index"] = indexPath.item
    
    let height = RenderEngine.shared.calculateHeight(
        json: cellTemplate.rawDictionary,
        templateId: "my_cell_template",
        data: context,
        containerWidth: itemWidth,
        useCache: true
    )
    
    return CGSize(width: itemWidth, height: height)
}
```

### 高度缓存策略

- **缓存 Key**：`templateId_containerWidth_dataId`
- **dataId 来源**：优先使用 `data["id"]`，其次 `data["_id"]`
- **缓存容量**：500 条（LRU 策略）
- **失效策略**：调用 `clearHeightCache(templateId:)` 手动清理

### 性能预期

| 场景 | 优化前 | 优化后 |
|------|--------|--------|
| Cell 首次渲染 | parse + bind + layout + createView | (缓存命中) clone + bind + layout + createView |
| Cell 复用 | 重新 render | quickUpdate（只更新数据绑定） |
| sizeForItemAt | 固定高度 | 实际计算高度（带缓存） |
| prefetch 高度计算 | N/A | 批量并发计算 |

---

## GapWorker 帧空闲调度系统

### 概述

GapWorker 是对标 Lynx 的帧空闲时间任务调度系统，用于在每帧渲染完成后的空闲时间内执行 Cell 预取任务，避免影响主线程渲染性能。

### 核心组件

#### 1. TemplateXGapWorker（核心调度器）

**文件**: `Sources/Core/GapWorker/TemplateXGapWorker.swift`

基于 CADisplayLink 的帧空闲任务调度器：
- 自动检测屏幕刷新率（60fps/120fps ProMotion）
- 时间预算控制：60fps = 8ms，120fps = 4ms
- 支持任务优先级排序（按距离视口距离）

```swift
// 获取单例
let gapWorker = TemplateXGapWorker.shared

// 注册任务提供者
gapWorker.register(provider: listPreloadManager)

// 注销任务提供者
gapWorker.unregister(provider: listPreloadManager)

// 启动/停止调度
gapWorker.start()
gapWorker.stop()
```

#### 2. GapTask 协议

**文件**: `Sources/Core/GapWorker/GapTask.swift`

```swift
/// 帧空闲任务协议
protocol GapTask {
    /// 任务 ID
    var taskId: String { get }
    
    /// 预估执行时间（纳秒）
    var estimatedDuration: Int64 { get }
    
    /// 执行任务
    func execute()
}

/// 任务提供者协议
protocol GapTaskProvider: AnyObject {
    /// 收集当前需要执行的任务
    func collectTasks() -> GapTaskBundle?
}

/// 任务包（按优先级排序的任务集合）
struct GapTaskBundle {
    var tasks: [GapTask]
    
    mutating func sortByPriority()
}
```

#### 3. CellPrefetchTask（Cell 预取任务）

**文件**: `Sources/Core/GapWorker/CellPrefetchTask.swift`

```swift
/// Cell 预取任务
final class CellPrefetchTask: GapTask {
    let templateId: String
    let index: Int
    let data: [String: Any]
    let containerSize: CGSize
    
    // 执行：parse → bind → layout → createView → 缓存
    func execute()
}

/// 预取缓存
final class PrefetchCache {
    /// 获取预取的视图
    func getView(templateId: String, index: Int) -> UIView?
    
    /// 缓存预取的视图
    func setView(_ view: UIView, templateId: String, index: Int)
    
    /// 清理缓存
    func clear(templateId: String? = nil)
}
```

#### 4. PrefetchRegistry（预取位置收集器）

**文件**: `Sources/Core/GapWorker/PrefetchRegistry.swift`

```swift
/// 预取位置收集器（对标 Lynx LayoutPrefetchRegistry）
final class PrefetchRegistry {
    /// 收集需要预取的位置
    func collectPrefetchPositions(
        visibleRange: Range<Int>,
        velocity: CGFloat,
        direction: ScrollDirection
    ) -> [Int]
}

/// 线性布局预取辅助（对标 Lynx LinearLayoutPrefetchHelper）
struct LinearLayoutPrefetchHelper {
    /// 计算预取位置
    static func calculatePrefetchPositions(
        currentPosition: Int,
        velocity: CGFloat,
        itemCount: Int,
        prefetchCount: Int
    ) -> [Int]
}
```

### 时间预算计算

对标 Lynx 的时间预算公式：

```swift
// Lynx: max_estimate_duration_ = 1.0E9F / refresh_rate / 2
// 60fps: 1000000000 / 60 / 2 = 8.33ms
// 120fps: 1000000000 / 120 / 2 = 4.17ms

let timeBudgetNs: Int64 = Int64(1_000_000_000.0 / refreshRate / 2.0)
```

### 平均绑定时间计算

对标 Lynx `list_adapter.cc:17` 的加权平均算法：

```swift
// old_average * 3/4 + new_value * 1/4
func updateAverageBindTime(templateId: String, newValue: Int64) {
    let oldAverage = averageBindTimes[templateId] ?? newValue
    averageBindTimes[templateId] = (oldAverage * 3 / 4) + (newValue / 4)
}
```

### 与 ListPreloadManager 集成

```swift
// ListPreloadManager 实现 GapTaskProvider 协议
extension ListPreloadManager: GapTaskProvider {
    func collectTasks() -> GapTaskBundle? {
        // 1. 收集需要预取的位置
        let positions = prefetchRegistry.collectPrefetchPositions(...)
        
        // 2. 创建预取任务
        var tasks: [GapTask] = positions.map { index in
            CellPrefetchTask(
                templateId: templateId,
                index: index,
                data: dataSource[index],
                containerSize: cellSize
            )
        }
        
        // 3. 返回任务包
        return GapTaskBundle(tasks: tasks)
    }
}
```

### 使用示例

```swift
// 在 ListComponent 或 UICollectionView 中启用 GapWorker
class MyListViewController: UIViewController {
    let preloadManager = ListPreloadManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 配置预加载管理器
        preloadManager.configure(
            templateId: "cell_template",
            template: cellTemplate,
            dataSource: items,
            containerSize: cellSize
        )
        
        // 启用 GapWorker
        preloadManager.enableGapWorker = true
        preloadManager.registerToGapWorker()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        preloadManager.unregisterFromGapWorker()
    }
    
    // 在 cellForItemAt 中使用预取的视图
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // 尝试获取预取的视图
        if let prefetchedView = preloadManager.dequeuePreloadedView(at: indexPath.item) {
            cell.contentView.addSubview(prefetchedView)
            return cell
        }
        
        // 降级到同步渲染
        // ...
    }
}
```

### 性能收益

| 场景 | 无 GapWorker | 有 GapWorker |
|------|-------------|--------------|
| 快速滚动 | 掉帧（Cell 同步创建） | 流畅（Cell 已预取） |
| 首次显示 | 冷启动延迟 | 预热 + 预取 |
| 内存占用 | 按需创建 | 预取缓存（可配置 maxLimit） |