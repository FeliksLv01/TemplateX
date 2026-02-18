# TemplateX - iOS DSL 动态渲染引擎

## 项目概述

TemplateX 是一个高性能的 iOS DSL 动态化渲染框架，支持通过 JSON 模板驱动 UI 渲染，具备完整的 Flexbox 布局能力、数据绑定、增量更新（Diff）等特性。

### 核心特性

- **JSON → UIView 渲染**：声明式 UI，模板驱动
- **Flexbox 布局**：基于 Yoga C API，支持子线程布局计算
- **数据绑定**：`${expression}` 表达式求值
- **增量更新**：Diff + Patch 算法，最小化视图操作
- **组件化**：可扩展的组件注册机制
- **高性能**：视图复用池、布局缓存、异步渲染

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
│       │   │   └── AsyncRenderEngine.swift  # 异步渲染引擎
│       │   ├── Layout/
│       │   │   ├── YogaLayoutEngine.swift   # Yoga 布局引擎封装
│       │   │   ├── YogaCBridge.swift        # Yoga C API 桥接
│       │   │   ├── YogaNodePool.swift       # Yoga 节点池
│       │   │   ├── AsyncLayoutEngine.swift  # 异步布局引擎
│       │   │   └── LayoutTypes.swift        # 布局类型定义
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
│       │   │   ├── DiffPatcher.swift        # Patch 应用
│       │   │   └── ViewRecyclePool.swift    # 视图回收池
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

2. **视图复用池**
   - ViewRecyclePool 回收/复用视图
   - ComponentPool 组件复用
   - 按组件类型分类存储
   - **Input 组件池化**：UITextField/UITextView 复用

3. **视图预热**
   - `ViewRecyclePool.warmUp()` 预创建重型视图（UITextField/UITextView）
   - 消除首次渲染 Input 组件的延迟
   - 支持自定义预热配置

4. **移除不必要的锁**
   - ViewRecyclePool、ComponentPool、EventManager、GestureHandlerManager 只在主线程访问，无需锁
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
   - 预热内容：
     - ComponentRegistry、TemplateParser、YogaNodePool、RenderEngine
     - **ViewRecyclePool**（UITextField/UITextView 预创建）
   - 消除首次渲染的冷启动开销（从 6ms 降到 <1ms）

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
    - **影响范围**：YogaLayoutEngine、Component、ViewRecyclePool

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
    // 方式1: 默认预热（推荐）- 包含视图预热
    DispatchQueue.global(qos: .userInitiated).async {
        TemplateX.warmUp()  // 异步预热，消除首次渲染冷启动
    }
    
    // 方式2: 最小预热（不预热重型视图）
    TemplateX.warmUp(options: .minimal)
    
    // 方式3: 自定义预热配置
    var options = TemplateX.WarmUpOptions()
    options.yogaNodeCount = 128  // 更多 Yoga 节点
    options.viewWarmUpConfig = ViewRecyclePool.WarmUpConfig(viewCounts: [
        "input": 8,           // 更多 UITextField
        "input_multiline": 4  // 更多 UITextView
    ])
    TemplateX.warmUp(options: options)
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
5. ~~**视图预热**~~：✅ 已完成，`ViewRecyclePool.warmUp()` 预创建 UITextField/UITextView
6. ~~**Input 组件池化**~~：✅ 已完成，复用 TemplateXTextField/TemplateXTextView
7. ~~**异步渲染 API**~~：✅ 已完成，`AsyncRenderEngine` 支持任务取消
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

