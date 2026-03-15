# TemplateX - iOS DSL 动态渲染引擎

## 项目概述

TemplateX 是一个高性能的 iOS DSL 动态化渲染框架，支持通过 JSON 模板驱动 UI 渲染，具备完整的 Flexbox 布局能力、数据绑定、增量更新（Diff）等特性。

### 核心特性

- **JSON → UIView 渲染**：声明式 UI，模板驱动
- **Flexbox 布局**：基于 Yoga C API，支持子线程布局计算
- **数据绑定**：`${expression}` 表达式求值（ANTLR4 解析）
- **增量更新**：Diff + Patch 算法，最小化视图操作
- **组件化**：泛型组件基类 `TemplateXComponent<V,P>`，Codable Props 自动解析
- **Pipeline 渲染**：后台 parse+bind+layout，SyncFlush 同步刷新避免白屏
- **视图拍平**：ViewFlattener 剪枝纯布局容器，减少 UIView 层级
- **TemplateXView**：类似 Lynx LynxView 的容器视图，Builder 模式 + 布局尺寸模式
- **高性能**：组件树复用、布局缓存、GapWorker 帧空闲预取

---

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│              TemplateXEnv / TemplateXConfig              │
│             (全局环境配置 / 渲染参数)                      │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│               TemplateXView (容器视图)                    │
│    Builder 模式 | SyncFlush | 布局尺寸模式                │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│              RenderPipeline (渲染管道)                    │
│     后台 parse+bind+layout → UIOperationQueue → Flush   │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│            TemplateXRenderEngine (渲染引擎)               │
└────────────────┬────────────────────────────────────────┘
                 │
    ┌────────────┼────────────┬───────────────┐
    │            │            │               │
    ▼            ▼            ▼               ▼
┌────────┐  ┌─────────┐  ┌──────────┐   ┌──────────┐
│Template│  │  Yoga   │  │  View    │   │   Diff   │
│ Parser │  │ Layout  │  │ Flatten  │   │  Patcher │
└────────┘  └─────────┘  └──────────┘   └──────────┘
    │            │            │               │
    ▼            ▼            ▼               ▼
┌────────┐  ┌─────────┐  ┌──────────┐   ┌──────────┐
│Component│ │YogaC API│  │  View    │   │ViewDiffer│
│Registry │ │NodePool │  │Flattener │   │  Result  │
└────────┘  └─────────┘  └──────────┘   └──────────┘
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
│       │   │   ├── RenderEngine.swift       # 核心渲染引擎（TemplateXRenderEngine）
│       │   │   ├── RenderPipeline.swift     # Lynx 式渲染管道（后台 parse+bind+layout → SyncFlush）
│       │   │   ├── UIOperationQueue.swift   # UI 操作批处理队列（条件变量同步）
│       │   │   ├── ViewFlattener.swift      # 视图拍平/剪枝（减少 UIView 层级）
│       │   │   └── ListPreloadManager.swift # 列表预加载管理
│       │   ├── Config/
│       │   │   ├── TemplateXConfig.swift     # 配置对象（Pipeline/SyncFlush/线程策略/预设）
│       │   │   ├── TemplateXEnv.swift        # 全局环境单例（类似 Lynx LynxEnv）
│       │   │   └── TemplateXProvider.swift   # 模板提供者协议 + BundleTemplateProvider
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
│       │   │   ├── TXJSONNode.swift          # JSON 节点封装工具
│       │   │   └── StyleParser.swift        # 样式批量解析器（性能优化）
│       │   ├── Binding/
│       │   │   └── DataBindingManager.swift # 数据绑定管理
│       │   ├── Expression/
│       │   │   ├── ExpressionEngine.swift       # 表达式引擎
│       │   │   ├── ExpressionEvaluator.swift    # 表达式树求值器
│       │   │   ├── BuiltinFunctions.swift       # 内置函数
│       │   │   ├── Generated/                   # ANTLR4 自动生成
│       │   │   │   ├── TemplateXExprLexer.swift
│       │   │   │   ├── TemplateXExprParser.swift
│       │   │   │   ├── TemplateXExprVisitor.swift
│       │   │   │   └── TemplateXExprBaseVisitor.swift
│       │   │   └── Grammar/
│       │   │       └── TemplateXExpr.g4         # ANTLR4 语法文件
│       │   ├── Diff/
│       │   │   ├── ViewDiffer.swift         # Diff 算法
│       │   │   ├── DiffPatcher.swift        # Patch 应用
│       │   │   └── DiffResult.swift         # Diff 操作类型 + 属性变化
│       │   ├── Cache/
│       │   │   └── LRUCache.swift           # LRU 缓存
│       │   ├── Event/
│       │   │   ├── EventManager.swift       # 事件管理
│       │   │   └── GestureHandler.swift     # 手势处理
│       │   └── Performance/
│       │       └── PerformanceMonitor.swift # 性能监控
│       ├── Components/
│       │   ├── Component.swift              # 组件协议 + ComponentFlags + 注册表
│       │   ├── TemplateXComponent.swift      # 泛型组件基类 + ComponentProps + @Default
│       │   ├── StyleValues.swift             # 强类型值包装（ColorValue, FontWeightValue 等）
│       │   ├── Views/
│       │   │   ├── TemplateXView.swift          # 容器视图（类似 LynxView）
│       │   │   ├── TemplateXViewBuilder.swift   # Builder 模式 + TemplateXViewSizeMode
│       │   │   ├── TextComponent.swift          # 文本
│       │   │   ├── ImageComponent.swift         # 图片
│       │   │   ├── ButtonComponent.swift        # 按钮
│       │   │   ├── InputComponent.swift         # 输入框
│       │   │   ├── ScrollComponent.swift        # 滚动视图
│       │   │   ├── ListComponent.swift          # 列表 + GridComponent
│       │   │   └── VerticalGridFlowLayout.swift # 纵向优先网格布局
│       │   └── Layouts/
│       │       └── ContainerComponent.swift     # Flexbox 容器（type: "container"）
│       └── Service/                         # Service 协议层
│           ├── ServiceRegistry.swift        # DI 容器
│           ├── ActionHandler/
│           │   └── TemplateXActionHandler.swift # 事件动作处理协议
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
├── Example/
│   └── TemplateXDemo/                   # 示例 App
├── Tests/
│   └── ...                              # 单元测试
├── TemplateX.podspec                    # 核心库 podspec
└── TemplateXService.podspec             # Service 实现 podspec
```

---

## 核心模块说明

### 1. TemplateXRenderEngine (渲染引擎)

**文件**: `Sources/Core/Engine/RenderEngine.swift`（类名 `TemplateXRenderEngine`）

核心职责：
1. 解析模板 → 组件树
2. 计算布局
3. 创建/更新视图
4. 支持增量更新（Diff）
5. 模板缓存渲染（Cell 场景）
6. 高度计算与批量并发

```swift
// 同步渲染
let view = TemplateXRenderEngine.shared.render(
    json: template,
    data: data,
    containerSize: CGSize(width: 375, height: .nan)
)

// 增量更新
TemplateXRenderEngine.shared.update(view: view, data: newData, containerSize: size)

// Cell 缓存渲染
let cellView = TemplateXRenderEngine.shared.renderWithCache(
    json: template,
    templateId: "my_cell",
    data: itemData,
    containerSize: cellSize
)
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

组件协议：
```swift
public protocol Component: AnyObject {
    var id: String { get }
    var type: String { get }
    var style: ComponentStyle { get set }
    var children: [Component] { get set }
    var parent: Component? { get set }
    var view: UIView? { get set }
    var layoutResult: LayoutResult { get set }
    var bindings: [String: Any] { get set }
    var events: [String: Any] { get set }
    
    // Yoga 剪枝优化
    var yogaNode: YGNodeRef? { get set }
    var lastLayoutStyle: ComponentStyle? { get set }
    func releaseYogaNode()
    
    // 引擎内部使用
    var parseError: Error? { get set }
    var templateJSON: TXJSONNode? { get set }
    var componentFlags: ComponentFlags { get set }
    var forceApplyStyle: Bool { get set }
    var isPruned: Bool { get set }
    
    // 生命周期
    func createView() -> UIView
    func updateView()
    func needsUpdate(with other: Component) -> Bool
    func addChild(_ child: Component)
    func removeChild(_ child: Component)
    func clone() -> Component
    func copyProps(from other: Component)
    func reloadProps(from resolved: [String: Any])
}
```

内置组件（`ComponentRegistry.registerBuiltinComponents()`）：
- `container` - Flexbox 布局容器（`ContainerComponent`）
- `text` - 文本（`TextComponent`）
- `image` - 图片（`ImageComponent`）
- `scroll` - 滚动视图（`ScrollComponent`）
- `list` - 列表（`ListComponent`）
- `grid` - 网格列表（`GridComponent`，定义在 ListComponent.swift）
- `button` - 按钮（`ButtonComponent`）
- `input` - 输入框（`InputComponent`）

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
    static func create(from json: TXJSONNode) -> Component
}
```

**注册方式**：

```swift
// 方式1: 通过 TemplateX 入口（推荐）
TemplateX.register(VideoComponent.self)

// 方式2: 直接调用 Registry
ComponentRegistry.shared.register(VideoComponent.self)
```

**自定义组件示例**（使用泛型基类 `TemplateXComponent<V,P>`）：

```swift
// 1. 定义 Props（遵循 ComponentProps = Codable + Equatable）
struct VideoProps: ComponentProps {
    var src: String = ""
    @Default<False> var autoPlay: Bool
    @Default<True> var showControls: Bool
}

// 2. 继承泛型基类
final class VideoComponent: TemplateXComponent<VideoPlayerView, VideoProps> {
    override class var typeIdentifier: String { "video" }
    
    // 工厂方法由基类自动提供（create(from:) → 自动 decode props）
    // 如需自定义解析，可重写 didParseProps()
    
    override func createView() -> UIView {
        let player = VideoPlayerView()
        return player
    }
    
    override func configureView(_ view: VideoPlayerView) {
        // @dynamicMemberLookup 自动转发 props 属性
        view.load(url: src)       // 等同于 props.src
        view.showControls = showControls  // 等同于 props.showControls
        if autoPlay { view.play() }
    }
    
    override func clone() -> Component {
        let cloned = VideoComponent(id: id, type: type)
        cloned.style = style
        cloned.bindings = bindings
        cloned.events = events
        cloned.props = props
        return cloned
    }
}

// 3. 注册
TemplateX.register(VideoComponent.self)
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
- `Sources/Core/Diff/ViewDiffer.swift` — Diff 算法
- `Sources/Core/Diff/DiffPatcher.swift` — Patch 应用
- `Sources/Core/Diff/DiffResult.swift` — Diff 操作类型 + 属性变化

增量更新流程：
1. 克隆旧组件树，绑定新数据
2. Diff 算法比较新旧组件树
3. Patch 应用差异到视图

**DiffOperation 类型**：
- `insert` — 插入新组件
- `delete` — 删除组件
- `update` — 更新组件（属性变化，附带 `PropertyChanges`）
- `move` — 移动组件（位置变化）
- `replace` — 替换组件（类型变化）

**PropertyChanges**：记录样式变化（`styleChanges`）和绑定数据变化（`bindingChanges`），支持判断是否需要重新布局（`needsRelayout`）。

### 7. TemplateXView (容器视图)

**文件**: 
- `Sources/Components/Views/TemplateXView.swift` — 容器视图（类似 Lynx LynxView）
- `Sources/Components/Views/TemplateXViewBuilder.swift` — Builder 模式 + TemplateXViewSizeMode

类似 Lynx 的 LynxView，作为 TemplateX 渲染的顶层容器视图。

核心特性：
- **Builder 模式**：通过 `TemplateXViewBuilder` 配置（config、screenSize、providers 等）
- **布局尺寸模式**：`TemplateXViewSizeMode`（`.exact` / `.atMost` / `.wrapContent`）
- **SyncFlush**：在 `layoutSubviews` 时同步等待后台 Pipeline 完成
- **异步模板加载**：`loadTemplate(url:data:)` 通过 TemplateProvider 加载
- **布局属性**：`layoutWidthMode`、`layoutHeightMode`、`preferredLayoutWidth`、`preferredLayoutHeight`

```swift
// 使用 Builder 模式创建
let templateView = TemplateXView { builder in
    builder.config = TemplateXConfig { config in
        config.enablePerformanceMonitor = true
    }
    builder.screenSize = view.bounds.size
    builder.templateProvider = MyTemplateProvider()
}

// 设置布局模式
templateView.layoutWidthMode = .exact
templateView.layoutHeightMode = .atMost
templateView.preferredLayoutWidth = 375
templateView.preferredLayoutHeight = .nan

// 加载模板
templateView.loadTemplate(url: "home_card", data: data)
```

### 8. RenderPipeline (渲染管道)

**文件**: 
- `Sources/Core/Engine/RenderPipeline.swift` — Lynx 式渲染管道
- `Sources/Core/Engine/UIOperationQueue.swift` — UI 操作批处理队列

借鉴 Lynx 架构的渲染管道，后台线程执行 parse + bind + layout，通过 SyncFlush 同步刷新避免白屏。

**管道状态**：`idle` → `preparing` → `ready` → `flushing` → `completed`

**核心流程**：
1. `start(json:data:containerSize:)` — 后台线程启动 parse + bind + layout
2. UI 操作封装为闭包入队 `UIOperationQueue`
3. `syncFlush()` — 主线程 `layoutSubviews` 时调用，NSCondition 等待后台完成
4. 批量执行 UI 操作闭包

**UIOperationQueue**：
- UI 操作闭包入队，SyncFlush 时批量执行
- `NSCondition` 条件变量同步
- 支持高优先级操作队列（错误处理）
- 超时保护（默认 100ms）

**RenderPipelinePool**：管道实例池，管理和复用 `RenderPipeline` 实例。

```swift
let pipeline = RenderPipeline()

// 1. 后台启动渲染
pipeline.start(json: template, data: data, containerSize: size)

// 2. layoutSubviews 时同步刷新
pipeline.syncFlush()

// 3. 获取结果
if let view = pipeline.renderedView {
    addSubview(view)
}
```

### 9. ViewFlattener (视图拍平)

**文件**: `Sources/Core/Engine/ViewFlattener.swift`

优化 UIView 层级：识别纯布局容器（无视觉属性、无事件的 container），跳过创建 UIView，将子节点提升到最近非剪枝祖先上。

**三棵树**：
- **Component 树**：保持不变（数据绑定需要）
- **Yoga 树**：保持不变（布局计算需要）
- **UIView 树**：拍平（减少层级）

**可剪枝条件**（必须全部满足）：
1. 组件类型为 `container`
2. 无事件绑定
3. 无背景色（或透明）、无渐变、无边框、无圆角、无阴影
4. 透明度为 1.0
5. 不裁剪子视图
6. display 不是 none，visibility 不是 hidden
7. 不需要强制应用样式（`forceApplyStyle == false`）

**坐标转换**：在 `YogaLayoutEngine.collectLayoutResults()` 中一次遍历完成——被剪枝容器的 Yoga 相对坐标累加到 `accumulatedOffset`，非剪枝组件的 `layoutResult.frame` 直接加上累积偏移，输出的 frame 已经是相对于最近非剪枝祖先的正确坐标。ViewFlattener 本身不做坐标计算，只负责剪枝判断（`isPrunable()`）和视图树构建。

**所有渲染路径已集成**：RenderEngine（同步）、RenderPipeline（异步）、DiffPatcher（增量更新）、TemplateXView 均已统一使用单次遍历拍平。

### 10. Config / Env (配置系统)

**文件**:
- `Sources/Core/Config/TemplateXConfig.swift` — 配置对象
- `Sources/Core/Config/TemplateXEnv.swift` — 全局环境单例
- `Sources/Core/Config/TemplateXProvider.swift` — 模板提供者协议

#### TemplateXConfig

渲染行为配置对象，支持 Builder 闭包初始化：

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| enablePipelineRendering | Bool | true | 是否启用 Pipeline 渲染 |
| enableSyncFlush | Bool | true | 是否启用 SyncFlush |
| syncFlushTimeoutMs | Int | 100 | SyncFlush 超时时间（ms） |
| enableIncrementalLayout | Bool | true | 是否启用增量布局 |
| enableLayoutCache | Bool | true | 是否启用布局缓存 |
| enablePerformanceMonitor | Bool | false | 是否启用性能监控 |
| enableVerboseLogging | Bool | false | 高频详细日志（⚠️影响性能） |
| threadStrategy | ThreadStrategy | .layoutOnBackground | 渲染线程策略 |

**预设配置**：
- `.default` — 默认配置
- `.highPerformance` — 高性能（更短超时、后台布局）
- `.debug` — 调试（性能监控、详细日志、UI 线程）
- `.simple` — 最简（无 Pipeline、无 SyncFlush、UI 线程）

**线程策略**（`ThreadStrategy`）：
- `.allOnUI` — 所有操作 UI 线程（最安全）
- `.layoutOnBackground` — 布局后台，UI 操作主线程（推荐）
- `.multiThread` — 多线程并发（最高性能）

#### TemplateXEnv

全局环境单例（类似 Lynx LynxEnv），多个 TemplateXView 共享配置：

```swift
// App 启动时配置
TemplateXEnv.shared.config = TemplateXConfig { config in
    config.enablePerformanceMonitor = true
    config.enableSyncFlush = true
}

TemplateXEnv.shared.templateProvider = MyTemplateProvider()
TemplateXEnv.shared.imageLoader = MyImageLoader()
```

#### TemplateXProvider

- `TemplateXTemplateProvider` 协议 — 模板加载（`loadTemplate(url:completion:)`）
- `BundleTemplateProvider` — 内置实现，从 App Bundle 加载 JSON 模板
- `TemplateXResourceProvider` 协议 — 通用资源提供者

### 11. TemplateXComponent 泛型基类

**文件**: 
- `Sources/Components/TemplateXComponent.swift` — 泛型组件基类
- `Sources/Components/StyleValues.swift` — 强类型值包装

#### TemplateXComponent<V: UIView, P: ComponentProps>

所有内置组件的泛型基类，提供：

- **`@dynamicMemberLookup`**：`component.text` 自动转发到 `component.props.text`
- **自动 JSON 解析**：`create(from:)` 自动 decode props（Codable）
- **自动 Diff 比较**：props 遵循 Equatable
- **样式缓存**：`_previousStyle` / `_previousFrame` 跳过未变化的样式/frame
- **手势处理**：自动绑定 `GestureHandler`

```swift
// 简单组件（无特有属性）
final class ContainerComponent: TemplateXComponent<UIView, EmptyProps> {
    override class var typeIdentifier: String { "container" }
}

// 复杂组件
final class TextComponent: TemplateXComponent<UILabel, TextComponent.Props> {
    struct Props: ComponentProps {
        var text: String = ""
        @Default<Empty> var textColor: String
        @Default<ZeroFloat> var fontSize: CGFloat
    }
    override class var typeIdentifier: String { "text" }
    override func configureView(_ view: UILabel) {
        view.text = props.text
    }
}
```

#### ComponentProps 协议

```swift
public protocol ComponentProps: Codable, Equatable {
    init()  // 创建默认属性
}
```

#### @Default<Provider> Property Wrapper

在 Codable 解码时，字段缺失或为 null 使用默认值：

```swift
struct Props: ComponentProps {
    @Default<False> var disabled: Bool      // 默认 false
    @Default<True> var enabled: Bool        // 默认 true
    @Default<Empty> var text: String        // 默认 ""
    @Default<TextInput> var inputType: String // 默认 "text"
    @Default<Zero> var count: Int           // 默认 0
    @Default<ZeroFloat> var offset: CGFloat // 默认 0
}
```

#### StyleValues.swift

强类型值包装，用于样式属性的类型安全解析：
- `ColorValue` — 颜色值解析（hex、named）
- `FontWeightValue` — 字重值解析
- `TextAlignValue` — 文本对齐解析
- 等其他样式值包装类型

### 12. 事件系统 (Event System)

**文件**:
- `Sources/Core/Event/EventManager.swift` — 事件注册、分发、动作执行
- `Sources/Core/Event/GestureHandler.swift` — 手势识别（UITapGestureRecognizer 等）
- `Sources/Service/ActionHandler/TemplateXActionHandler.swift` — 动作处理协议

#### 架构

事件从手势识别 → EventManager 分发 → ActionHandler 处理：

```
UITapGestureRecognizer (GestureHandler)
        │
        ▼
EventManager.dispatch(context)
        │
        ├── handleEventAtTarget → executeAction
        │       │
        │       ├── .url(url, params) → executeURLAction()
        │       │       │
        │       │       ├── 1. 从 component.bindings 获取数据上下文
        │       │       ├── 2. ExpressionEngine 求值 URL 和 params 中的 ${...}
        │       │       └── 3. ServiceRegistry.actionHandler.handleAction(url:params:context:)
        │       │
        │       └── .custom(callback) → callback(context)
        │
        ├── 冒泡（可选）
        └── 全局监听器通知
```

#### EventAction 类型

只有两种动作类型：

| 类型 | 用途 | 说明 |
|------|------|------|
| `.url(String, params:)` | JSON 模板事件 | URL + 参数传递给 ActionHandler |
| `.custom(EventCallback)` | Swift 原生代码 | 闭包回调（如 ButtonComponent.onClick） |

#### JSON 模板事件格式

支持两种写法：

```json
// 简写：直接传 URL 字符串
{
  "type": "container",
  "onTap": "app://detail?id=123"
}

// 完整配置：URL + params + 控制参数
{
  "type": "container",
  "onTap": {
    "url": "app://follow",
    "params": {
      "userId": "${user.id}",
      "userName": "${user.name}"
    },
    "stopPropagation": true,
    "throttle": 300
  }
}
```

**注意**：事件 key 为 `onTap`（不是 `onClick`）。模板中 `onClick` 和 `onTap` 均映射为 `"tap"` 事件，保持向后兼容。

#### 表达式求值

事件触发时（dispatch 阶段），URL 和 params 中的 `${...}` 表达式会被自动求值：
- 数据上下文来自 `component.bindings`（DataBindingManager 在渲染时绑定的数据）
- URL 中的表达式：`"app://detail?id=${post.id}"` → `"app://detail?id=42"`
- params 中的表达式：`{ "userId": "${user.id}" }` → `{ "userId": "u_123" }`
- 使用 `ExpressionEngine.resolveBindings()` 递归处理嵌套字典/数组

#### ActionHandler 注册

接入方实现 `TemplateXActionHandler` 协议处理事件：

```swift
class AppActionHandler: TemplateXActionHandler {
    func handleAction(url: String, params: [String: Any], context: EventContext) {
        guard let url = URL(string: url) else { return }
        switch url.host {
        case "follow":
            let userId = params["userId"] as? String ?? ""
            UserService.follow(userId: userId)
        default:
            Router.open(url, params: params)
        }
    }
}

// App 启动时注册
TemplateX.registerActionHandler(AppActionHandler())
```

如果没有注册 ActionHandler，事件触发时会输出警告日志：`"ActionHandler not registered. Call TemplateX.registerActionHandler(...) to handle events."`

---

## 性能优化

### 已实现的优化

1. **Yoga C API + 子线程布局**
   - 直接调用 Yoga C API，避免 Swift 包装开销
   - 支持在子线程计算布局
   - YogaNodePool 节点复用 + 批量获取（`acquireBatch`）

2. **UIView 创建优化**
   - UIView 创建耗时极低（<0.1ms），无需独立视图池
   - 列表场景依赖 UICollectionView/UITableView 内置 Cell 复用

 3. **移除不必要的锁**
    - EventManager、GestureHandlerManager 只在主线程访问，无需锁
    - 真正需要锁的场景：LRUCache（通用缓存）

  4. **LRUCache.ObjectPool Bug 修复**
   - `let lock` → `var lock`（os_unfair_lock 必须是 var）
   - 移除 `var l = lock` 副本创建

 5. **渲染时机优化**
    - 在 `viewDidLoad` 同步渲染，避免白屏
    - 渲染耗时 ~10ms，不影响 push 动画流畅度
 
 6. **日志系统优化（TXLogger）**
   - iOS 14+ 使用 `os.Logger`（高性能，支持 Instruments）
   - iOS 14 以下使用 `print` fallback（带开关）
   - 统一接口 `TXLogger`，自动选择实现
   - 日志级别：error, warning, info, debug, trace, verbose
   - verbose 级别仅 DEBUG 模式输出

 7. **引擎预热（warmUp）**
    - `TemplateX.warmUp()` 在 App 启动时异步调用
    - 预热内容：ComponentRegistry、TemplateParser、YogaNodePool、RenderEngine、ImageLoader
    - 消除首次渲染的冷启动开销（从 6ms 降到 <1ms）
    - **SDWebImage 预热**：触发 `SDWebImageManager`、`SDImageCache`、`SDWebImageDownloader` 单例初始化，避免首次加载图片时的 ~3ms 开销
 
 8. **视图样式残留 Bug 修复**
   - **问题**：增量更新时，复用视图的样式属性可能残留（如背景色）
   - **原因**：`applyStyle()` 只在样式属性有值时设置，不会在属性为 nil 时重置
   - **修复**：改为无条件应用所有样式属性，确保视图状态与组件样式一致
   - **影响**：backgroundColor、cornerRadius、borderWidth、shadowOpacity 等属性现在每次都会被设置

 9. **updateView 阶段优化**
     - **样式缓存**：`_lastAppliedStyle` 缓存上次应用的样式，样式未变化时跳过
     - **frame 缓存**：`_lastAppliedFrame` 缓存上次 frame，位置未变化时跳过
     - **UIFont 缓存**：`TextComponent` 中缓存 UIFont，只在字体参数变化时重建
     - **图片 URL 缓存**：`ImageComponent` 避免重复加载相同图片
     - **forceApplyStyle 标记**：视图复用时强制应用样式
 
 10. **Parser 解析优化（StyleParser）**
    - **批量解析模式**：一次遍历 JSON 字典，根据 key 分发到对应属性
    - **StyleKey 枚举映射**：字符串 key → 枚举值，O(1) 哈希查找
    - **静态枚举映射表**：FlexDirection/JustifyContent 等枚举使用预构建的静态字典
    - **减少字典查找**：原逐属性查询 40+ 次 → 现一次遍历
    - **消除重复类型转换**：在分发时直接处理类型

 11. **Yoga 剪枝优化（Incremental Layout）**
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

 12. **视图拍平优化（ViewFlattener + YogaLayoutEngine 单次遍历）**
    - 识别纯布局容器（无视觉属性、无事件的 container）
    - 跳过创建 UIView，子节点提升到最近非剪枝祖先
    - 坐标偏移在 `YogaLayoutEngine.collectLayoutResults()` 中一次遍历完成（对标 Litho `collectResults()` 模型）
    - 三棵树：Component 树不变、Yoga 树不变、UIView 树拍平
    - 所有渲染路径已统一：RenderEngine、RenderPipeline、DiffPatcher、TemplateXView

 13. **Pipeline 渲染（RenderPipeline）**
    - 后台线程执行 parse + bind + layout
    - UIOperationQueue 封装 UI 操作入队
    - SyncFlush：layoutSubviews 时 NSCondition 等待后台完成
    - 超时保护（默认 100ms）

 14. **UIOperationQueue 批处理**
    - UI 操作闭包入队，SyncFlush 时批量执行
    - NSCondition 条件变量同步
    - 高优先级操作队列（错误处理）

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
TemplateXRenderEngine.shared.config.enablePerformanceMonitor = true
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
9. ~~**ViewFlattener 集成到 TemplateXView**~~：✅ 已完成，所有渲染路径统一使用 `collectLayoutResults()` 单次遍历拍平

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
    
    let height = TemplateXRenderEngine.shared.calculateHeight(
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