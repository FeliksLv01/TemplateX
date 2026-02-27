# TemplateX 模板解析与组件系统

> 本文是 TemplateX 系列文章的第 2 篇，深入讲解模板解析流程和组件系统设计。

## 先看问题

上一篇我们了解了 TemplateX 的整体架构。现在来看一个具体问题：

**一段 JSON 是如何变成 UIView 的？**

```json
{
  "type": "container",
  "style": { "flexDirection": "row", "padding": 16 },
  "children": [
    { "type": "text", "props": { "text": "Hello" } },
    { "type": "image", "props": { "src": "avatar.png" } }
  ]
}
```

变成：

```
UIView (container)
├── UILabel (text: "Hello")
└── UIImageView (image: avatar.png)
```

这中间经历了什么？

---

## 解析流程概览

模板解析分为 3 个阶段：

```
┌─────────────────────────────────────────────────────────────┐
│                       解析流程                               │
└─────────────────────────────────────────────────────────────┘

  JSON String/Data          JSON Dictionary
        │                         │
        │ JSONSerialization       │
        ▼                         ▼
  ┌───────────┐             ┌───────────┐
  │   Parse   │────────────▶│JSONWrapper│  ← 阶段1: JSON 包装
  └───────────┘             └─────┬─────┘
                                  │
                                  ▼
  ┌───────────────────────────────────────────────────────┐
  │                    parseNode()                         │
  │  ┌──────────────────────────────────────────────────┐ │
  │  │ 1. 读取 type 字段                                 │ │
  │  │ 2. ComponentRegistry.createComponent()           │ │  ← 阶段2: 组件创建
  │  │ 3. 递归解析 children                             │ │
  │  └──────────────────────────────────────────────────┘ │
  └───────────────────────────┬───────────────────────────┘
                              │
                              ▼
                        Component Tree
                              │
                              ▼
                  ┌───────────────────────┐
                  │   createView() 递归    │  ← 阶段3: 视图创建
                  └───────────────────────┘
                              │
                              ▼
                          UIView Tree
```

---

## 阶段 1：JSON 包装

### 为什么不直接用 Dictionary？

传统方式：

```swift
// 每次访问都要类型转换
let type = json["type"] as? String
let style = json["style"] as? [String: Any]
let padding = style?["padding"] as? Int

// 访问嵌套对象更痛苦
let children = json["children"] as? [[String: Any]] ?? []
for child in children {
    let childType = child["type"] as? String
    // ...
}
```

问题：
1. 大量 `as?` 类型转换
2. 嵌套访问代码冗长
3. 重复解析相同字段

### JSONWrapper 的设计

`JSONWrapper` 是对 `[String: Any]` 的轻量包装：

```swift
@dynamicMemberLookup
public final class JSONWrapper {
    private let json: [String: Any]
    private var childCache: [String: JSONWrapper] = [:]
    
    // 动态成员查找
    public subscript(dynamicMember key: String) -> JSONWrapper? {
        return child(key)
    }
    
    // 获取子对象（带缓存）
    public func child(_ key: String) -> JSONWrapper? {
        if let cached = childCache[key] {
            return cached
        }
        guard let value = json[key] as? [String: Any] else {
            return nil
        }
        let wrapper = JSONWrapper(value)
        childCache[key] = wrapper
        return wrapper
    }
    
    // 类型安全的取值方法
    public func string(_ key: String) -> String? { json[key] as? String }
    public func int(_ key: String) -> Int? { ... }
    public func cgFloat(_ key: String) -> CGFloat? { ... }
    public func bool(_ key: String) -> Bool? { ... }
}
```

**使用对比：**

```swift
// 传统方式
let padding = (json["style"] as? [String: Any])?["padding"] as? Int ?? 0

// JSONWrapper
let padding = wrapper.style?.int("padding") ?? 0

// 动态成员查找
let padding = wrapper.style?.padding  // 返回 JSONWrapper?
```

### 关键设计点

| 设计 | 说明 |
|------|------|
| **延迟解析** | 只在访问时创建子 JSONWrapper |
| **结果缓存** | 避免重复创建相同字段的 wrapper |
| **类型安全** | 提供 `string()`, `int()` 等类型安全方法 |
| **动态成员** | `@dynamicMemberLookup` 支持点语法 |

---

## 阶段 2：组件创建

### TemplateParser

`TemplateParser` 是模板解析的入口：

```swift
public final class TemplateParser {
    public static let shared = TemplateParser()
    
    // 从 JSON 字典解析
    public func parse(json: [String: Any]) -> Component? {
        let wrapper = JSONWrapper(json)
        return parse(wrapper: wrapper)
    }
    
    // 从 JSONWrapper 解析
    public func parse(wrapper: JSONWrapper) -> Component? {
        if let root = wrapper.child("root") {
            return parseNode(root)
        }
        return parseNode(wrapper)
    }
    
    // 递归解析节点
    private func parseNode(_ json: JSONWrapper) -> Component? {
        // 1. 获取组件类型
        guard let type = json.type else {
            return nil
        }
        
        // 2. 通过 Registry 创建组件
        guard let component = ComponentRegistry.shared.createComponent(
            type: type, 
            from: json
        ) else {
            return nil
        }
        
        // 3. 递归解析子节点
        for childJson in json.children {
            if let child = parseNode(childJson) {
                component.children.append(child)
                child.parent = component
            }
        }
        
        return component
    }
}
```

**解析流程：**

```
parseNode({ type: "container", children: [...] })
    │
    ├── ComponentRegistry.createComponent("container", json)
    │       └── ContainerComponent.create(from: json)
    │
    └── for child in json.children
            └── parseNode(child)  // 递归
```

### ComponentRegistry

`ComponentRegistry` 是组件的注册中心，使用**工厂模式**：

```swift
public final class ComponentRegistry {
    public static let shared = ComponentRegistry()
    
    // 已注册的组件工厂
    private var factories: [String: ComponentFactory.Type] = [:]
    
    init() {
        // 注册内置组件
        registerBuiltinComponents()
    }
    
    // 注册组件
    public func register(_ factory: ComponentFactory.Type) {
        factories[factory.typeIdentifier] = factory
    }
    
    // 创建组件
    public func createComponent(type: String, from json: JSONWrapper) -> Component? {
        guard let factory = factories[type] else {
            TXLogger.error("Unknown component type: \(type)")
            return nil
        }
        return factory.create(from: json)
    }
    
    // 注册内置组件
    private func registerBuiltinComponents() {
        register(ContainerComponent.self)
        register(TextComponent.self)
        register(ImageComponent.self)
        register(ButtonComponent.self)
        register(InputComponent.self)
        register(ScrollComponent.self)
        register(ListComponent.self)
    }
}
```

**设计模式：工厂模式**

```
┌──────────────────────────────────────────────────────────┐
│                   ComponentRegistry                       │
│                                                          │
│  factories: [String: ComponentFactory.Type]              │
│  ┌──────────────────────────────────────────────────┐   │
│  │ "container" → ContainerComponent.self            │   │
│  │ "text"      → TextComponent.self                 │   │
│  │ "image"     → ImageComponent.self                │   │
│  │ "button"    → ButtonComponent.self               │   │
│  │ ...                                               │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  createComponent("text", json)                           │
│      └── TextComponent.create(from: json)                │
│              └── return TextComponent(...)               │
└──────────────────────────────────────────────────────────┘
```

---

## 组件系统设计

### Component 协议

所有组件都遵循 `Component` 协议：

```swift
public protocol Component: AnyObject {
    // 基本属性
    var id: String { get }
    var type: String { get }
    var style: ComponentStyle { get set }
    var children: [Component] { get set }
    var parent: Component? { get set }
    var view: UIView? { get set }
    
    // 布局
    var layoutResult: LayoutResult { get set }
    
    // 绑定和事件
    var bindings: [String: Any] { get set }
    var events: [String: Any] { get set }
    
    // 视图生命周期
    func createView() -> UIView
    func updateView()
    func applyLayout()
    func applyStyle()
    
    // Diff 支持
    func needsUpdate(with other: Component) -> Bool
    func clone() -> Component
}
```

**核心职责划分：**

| 方法 | 职责 |
|------|------|
| `createView()` | 创建并返回 UIView 实例 |
| `updateView()` | 更新视图内容（文本、图片等） |
| `applyLayout()` | 应用 frame 到视图 |
| `applyStyle()` | 应用样式（背景、圆角等） |
| `clone()` | 深拷贝组件（用于 Diff） |

### BaseComponent 基类

`BaseComponent` 提供通用实现：

```swift
open class BaseComponent: Component {
    public let id: String
    public let type: String
    public var style: ComponentStyle
    public var children: [Component] = []
    public weak var parent: Component?
    public var view: UIView?
    public var layoutResult = LayoutResult()
    public var bindings: [String: Any] = [:]
    public var events: [String: Any] = [:]
    
    // 通用样式解析
    public func parseBaseParams(from json: JSONWrapper) {
        if let styleSource = json.child("style") {
            style = Self.parseStyle(from: styleSource)
        }
        if let eventsJson = json.events {
            events = eventsJson.rawDictionary
        }
        if let bindingsJson = json.bindings {
            bindings = bindingsJson.rawDictionary
        }
    }
    
    // 默认视图创建
    open func createView() -> UIView {
        let view = UIView()
        self.view = view
        return view
    }
    
    // 应用样式
    open func applyStyle() {
        guard let view = view else { return }
        view.backgroundColor = style.backgroundColor ?? .clear
        view.layer.cornerRadius = style.cornerRadius
        view.layer.borderWidth = style.borderWidth
        view.layer.borderColor = style.borderColor?.cgColor
        // ... 更多样式
    }
}
```

### TemplateXComponent 泛型基类

为了简化组件开发，TemplateX 提供了泛型基类：

```swift
/// DSL 组件泛型基类
/// - V: 关联的 UIView 子类
/// - P: 组件属性结构体（遵循 ComponentProps）
open class TemplateXComponent<V: UIView, P: ComponentProps>: BaseComponent, ComponentFactory {
    
    /// 组件特有属性
    var props: P = P()
    
    /// 组件类型标识（子类必须重写）
    open class var typeIdentifier: String {
        fatalError("子类必须重写 typeIdentifier")
    }
    
    /// 工厂方法
    public static func create(from json: JSONWrapper) -> Component? {
        let id = json.id ?? UUID().uuidString
        let component = Self.init(id: id, type: typeIdentifier)
        component.parseBaseParams(from: json)
        component.props = parseProps(from: json.props)
        return component
    }
    
    /// 使用 Codable 自动解析 Props
    class func parseProps(from json: JSONWrapper?) -> P {
        guard let json = json else { return P() }
        let data = try? JSONSerialization.data(withJSONObject: json.rawDictionary)
        return (try? JSONDecoder().decode(P.self, from: data!)) ?? P()
    }
    
    /// 配置视图（子类重写）
    open func configureView(_ view: V) {
        // 子类实现
    }
}
```

**使用示例：**

```swift
// 定义 Text 组件
final class TextComponent: TemplateXComponent<UILabel, TextComponent.Props> {
    
    // Props 使用 Codable 自动解析
    struct Props: ComponentProps {
        var text: String = ""
        var fontSize: CGFloat?
        var fontWeight: String?
        var textColor: String?
    }
    
    override class var typeIdentifier: String { "text" }
    
    override func createView() -> UIView {
        let label = UILabel()
        self.view = label
        return label
    }
    
    override func configureView(_ view: UILabel) {
        view.text = props.text
        view.font = makeFont()
        view.textColor = parseColor(props.textColor) ?? .black
    }
}
```

**Props 自动解析流程：**

```
JSON props:
{
  "text": "Hello",
  "fontSize": 16,
  "fontWeight": "bold"
}
    │
    ▼
JSONSerialization.data(withJSONObject:)
    │
    ▼
JSONDecoder().decode(Props.self, from:)
    │
    ▼
Props(text: "Hello", fontSize: 16, fontWeight: "bold")
```

---

## 内置组件

TemplateX 提供以下内置组件：

### 容器组件

| 类型 | 说明 | UIKit 对应 |
|------|------|-----------|
| `container` | Flex 容器 | UIView |
| `scroll` | 滚动容器 | UIScrollView |
| `list` | 列表 | UICollectionView |

### 基础组件

| 类型 | 说明 | UIKit 对应 |
|------|------|-----------|
| `text` | 文本 | UILabel |
| `image` | 图片 | UIImageView |
| `button` | 按钮 | UIButton |
| `input` | 输入框 | UITextField |

### 组件 Props 示例

**TextComponent.Props：**

```swift
struct Props: ComponentProps {
    var text: String = ""
    var fontSize: CGFloat?
    var fontWeight: String?        // "normal", "bold", "500"
    var textColor: String?         // "#333333"
    var textAlign: String?         // "left", "center", "right"
    var numberOfLines: Int?        // 0 = 无限制
    var lineHeight: CGFloat?
    var letterSpacing: CGFloat?
}
```

**ImageComponent.Props：**

```swift
struct Props: ComponentProps {
    var src: String = ""           // 图片 URL 或本地名称
    var contentMode: String?       // "cover", "contain", "fill"
    var placeholder: String?       // 占位图名称
}
```

**ButtonComponent.Props：**

```swift
struct Props: ComponentProps {
    var title: String = ""
    @Default<False> var disabled: Bool
}
```

---

## 自定义组件

### 步骤 1：定义 Props

```swift
struct VideoProps: ComponentProps {
    var src: String = ""
    var autoplay: Bool = false
    var controls: Bool = true
    var poster: String?
}
```

### 步骤 2：实现组件

```swift
final class VideoComponent: TemplateXComponent<UIView, VideoProps> {
    
    override class var typeIdentifier: String { "video" }
    
    private var playerView: AVPlayerView?
    
    override func createView() -> UIView {
        let container = UIView()
        let player = AVPlayerView()
        container.addSubview(player)
        playerView = player
        self.view = container
        return container
    }
    
    override func configureView(_ view: UIView) {
        playerView?.loadVideo(url: props.src)
        playerView?.autoplay = props.autoplay
        playerView?.showControls = props.controls
        if let poster = props.poster {
            playerView?.setPoster(poster)
        }
    }
    
    override func clone() -> Component {
        let cloned = VideoComponent(id: id)
        cloned.style = style
        cloned.props = props
        return cloned
    }
}
```

### 步骤 3：注册组件

```swift
// AppDelegate.swift
func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    
    // 注册自定义组件
    TemplateX.register(VideoComponent.self)
    
    return true
}
```

### 步骤 4：使用组件

```json
{
  "type": "video",
  "props": {
    "src": "https://example.com/video.mp4",
    "autoplay": true,
    "controls": true,
    "poster": "video_poster"
  },
  "style": {
    "width": "100%",
    "aspectRatio": 1.78
  }
}
```

---

## 模板缓存

### TemplateCache

对于频繁使用的模板，TemplateX 提供 LRU 缓存：

```swift
public final class TemplateCache {
    public static let shared = TemplateCache()
    
    private var cache: [String: CacheEntry] = [:]
    private var accessOrder: [String] = []
    private let capacity: Int
    
    // 获取缓存
    public func get(_ key: String) -> Component? {
        guard let entry = cache[key] else { return nil }
        
        // 更新访问顺序（LRU）
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }
        
        return entry.component
    }
    
    // 存入缓存
    public func set(_ key: String, component: Component) {
        // 容量检查（LRU 淘汰）
        while cache.count >= capacity && !accessOrder.isEmpty {
            let oldest = accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        
        cache[key] = CacheEntry(component: component, timestamp: Date())
        accessOrder.append(key)
    }
}
```

**使用场景：**

```swift
// 首次渲染：parse + 缓存
let component = TemplateParser.shared.parse(json: template)
TemplateCache.shared.set("home_card", component: component!)

// 后续渲染：直接使用缓存
if let cached = TemplateCache.shared.get("home_card") {
    let cloned = cached.clone()  // 克隆后使用
    // ...
}
```

---

## 性能优化

### 1. JSONWrapper 缓存

```swift
// 子对象只解析一次
private var childCache: [String: JSONWrapper] = [:]

public func child(_ key: String) -> JSONWrapper? {
    if let cached = childCache[key] { return cached }
    // 解析并缓存...
}
```

### 2. StyleParser 批量解析

传统方式每个属性单独查找：

```swift
// 40+ 次字典查找
style.width = json["width"]
style.height = json["height"]
style.padding = json["padding"]
// ...
```

TemplateX 使用一次遍历：

```swift
// 一次遍历，switch 分发
for (key, value) in json {
    switch StyleKey(rawValue: key) {
    case .width: style.width = parseSize(value)
    case .height: style.height = parseSize(value)
    // ...
    }
}
```

### 3. Props 解析优化

使用 `Codable` 自动解析，避免手动取值：

```swift
// 自动解析
let props = try JSONDecoder().decode(Props.self, from: data)

// vs 手动解析
let text = json["text"] as? String ?? ""
let fontSize = json["fontSize"] as? CGFloat
let fontWeight = json["fontWeight"] as? String
// ...
```

---

## 下一篇预告

本文介绍了模板解析和组件系统的设计。下一篇我们将深入 **Flexbox 布局引擎**，包括：

- Yoga 布局引擎集成
- Yoga C API vs Swift 包装
- 布局计算流程
- 增量布局优化（Yoga 剪枝）

---

## 系列文章

1. [TemplateX 概述与架构设计](./01-TemplateX-Overview.md)
2. **模板解析与组件系统**（本文）
3. Flexbox 布局引擎
4. 表达式引擎与数据绑定
5. Diff + Patch 增量更新
6. GapWorker 列表优化
7. 性能优化实战
