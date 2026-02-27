# TemplateX：打造高性能 iOS DSL 动态渲染引擎

> 本文是 TemplateX 系列文章的第 1 篇，介绍 TemplateX 的设计背景、核心架构和快速入门。

## 先看效果

在深入技术细节之前，先来看看 TemplateX 能做什么：

```swift
// 3 行代码，从 JSON 渲染一个卡片
let view = TemplateX.render(json: cardTemplate, data: userData)
containerView.addSubview(view!)
```

**渲染效果：**

```
┌──────────────────────────────────────┐
│  张三                     [VIP]      │
│  年龄: 28 岁                         │
│                                      │
│    1.2k        386        52         │
│    粉丝        关注       动态        │
└──────────────────────────────────────┘
```

这个卡片的布局、样式、数据绑定，全部通过 JSON 模板描述：

```json
{
  "type": "container",
  "style": {
    "flexDirection": "column",
    "padding": 16
  },
  "children": [
    {
      "type": "text",
      "props": { "text": "${user.name}" },
      "style": { "fontSize": 20, "fontWeight": "bold" }
    }
  ]
}
```

**核心能力：**
- 完整的 Flexbox 布局
- `${expression}` 数据绑定
- 增量更新（Diff + Patch）
- 列表优化（GapWorker 预渲染）
- 渲染性能 ~10ms（预热后）

---

## 为什么需要 DSL 动态化？

### 传统开发模式的痛点

假设你在开发一个内容类 App，首页有 10 种不同的卡片样式：

```
┌─────────────────────────────────────────────────────┐
│  传统方式：每种卡片都是一个 UIView 子类              │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ArticleCardView.swift      ← 图文卡片               │
│  VideoCardView.swift        ← 视频卡片               │
│  ProductCardView.swift      ← 商品卡片               │
│  UserCardView.swift         ← 用户卡片               │
│  BannerCardView.swift       ← 轮播图                 │
│  ... x 10                                            │
│                                                      │
│  问题：                                              │
│  1. 新增卡片 = 发版                                  │
│  2. 修改布局 = 发版                                  │
│  3. A/B 测试 = 发版 + 代码分支                       │
│                                                      │
└─────────────────────────────────────────────────────┘
```

每次产品要新增或修改卡片，都需要：
1. 开发写代码
2. 提测、灰度、发版
3. 等待用户更新

**这个周期通常是 1-2 周。**

### DSL 动态化的解法

```
┌─────────────────────────────────────────────────────┐
│  DSL 方式：卡片 = JSON 模板 + 数据                   │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Server 下发：                                       │
│  {                                                   │
│    "template": { "type": "container", ... },         │
│    "data": { "title": "...", "image": "..." }        │
│  }                                                   │
│                                                      │
│  Client 渲染：                                       │
│  TemplateX.render(json: template, data: data)        │
│                                                      │
│  优势：                                              │
│  1. 新增卡片 = 下发新模板（秒级生效）                │
│  2. 修改布局 = 更新模板（无需发版）                  │
│  3. A/B 测试 = 下发不同模板（服务端控制）            │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**这就是 TemplateX 要解决的问题：**
- 用 JSON 描述 UI（声明式）
- 在客户端实时渲染（高性能）
- 支持数据绑定和交互（动态化）

---

## 业界方案对比

在开始设计 TemplateX 之前，我们调研了业界的主流方案：

| 方案 | 原理 | 优点 | 缺点 |
|------|------|------|------|
| **React Native** | JS 引擎 + Bridge | 生态好、跨平台 | 包体积大、Bridge 性能 |
| **Flutter** | Dart + Skia 自绘 | 性能好、跨平台 | 独立渲染栈、包体积 |
| **Weex** | JS 引擎 + Native 组件 | 动态化强 | 已停止维护 |
| **Lynx** | 自研引擎 + Native 组件 | 高性能、轻量 | 学习成本 |
| **Tangram** | JSON + Native 组件 | 简单易用 | 布局能力弱 |

**TemplateX 的定位：**

借鉴 Lynx 的核心设计，但更轻量：
- 不引入 JS 引擎（使用原生表达式引擎）
- 使用 Yoga 做布局（成熟稳定）
- 复用 UIKit 组件（减少学习成本）
- 专注 iOS 平台（深度优化）

```
┌─────────────────────────────────────────────────────┐
│                复杂度 vs 灵活度                       │
├─────────────────────────────────────────────────────┤
│                                                      │
│  灵活度                                              │
│    ↑                                                 │
│    │                        React Native             │
│    │                    ↗                            │
│    │              Flutter                            │
│    │            ↗                                    │
│    │      Lynx ← TemplateX（目标位置）               │
│    │    ↗                                            │
│    │  Tangram                                        │
│    └────────────────────────────────→ 复杂度         │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## 架构设计

### 整体架构

TemplateX 的架构分为 4 层：

```
┌─────────────────────────────────────────────────────┐
│                     API Layer                        │
│                    TemplateX                         │
│            (render / update / config)                │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────┐
│                   Engine Layer                       │
├──────────────┬──────────────┬───────────────────────┤
│ RenderEngine │ LayoutEngine │    ExpressionEngine   │
│   (渲染)     │   (布局)     │       (表达式)         │
└──────────────┴──────────────┴───────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────┐
│                  Component Layer                     │
├──────────────┬──────────────┬───────────────────────┤
│     View     │    Text      │   Image / Button ...  │
│   (容器)     │   (文本)     │      (组件)           │
└──────────────┴──────────────┴───────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────┐
│                  Service Layer                       │
├──────────────┬──────────────┬───────────────────────┤
│ ImageLoader  │ LogProvider  │      (扩展...)        │
│ (图片加载)   │  (日志)      │                       │
└──────────────┴──────────────┴───────────────────────┘
```

### 渲染流程

一个模板从 JSON 到 UIView 的完整流程：

```
┌──────────────────────────────────────────────────────────────┐
│                       渲染流程                                │
└──────────────────────────────────────────────────────────────┘

  JSON Template                 Data
       │                          │
       ▼                          │
  ┌─────────┐                     │
  │  Parse  │  ← 解析 JSON        │
  └────┬────┘                     │
       │ Component Tree           │
       ▼                          ▼
  ┌─────────┐              ┌──────────┐
  │  Bind   │◀─────────────│   Data   │  ← 绑定数据
  └────┬────┘              └──────────┘
       │ Bound Component Tree
       ▼
  ┌─────────┐
  │ Layout  │  ← Yoga 计算布局
  └────┬────┘
       │ Layout Results
       ▼
  ┌─────────┐
  │ Create  │  ← 创建 UIView
  │  View   │
  └────┬────┘
       │
       ▼
    UIView
```

**各阶段耗时（典型值，预热后）：**

| 阶段 | 耗时 | 说明 |
|------|------|------|
| Parse | 0.1-0.3ms | JSON → Component Tree |
| Bind | <0.1ms | 数据绑定、表达式求值 |
| Layout | 0.1-0.2ms | Yoga 布局计算 |
| CreateView | 0.1-0.2ms | UIView 创建 |
| **Total** | **~1ms** | 单个卡片渲染 |

### 核心模块

| 模块 | 职责 | 文件位置 |
|------|------|---------|
| **RenderEngine** | 渲染流程编排 | `Core/Engine/RenderEngine.swift` |
| **TemplateParser** | JSON 解析 | `Core/Template/TemplateParser.swift` |
| **YogaLayoutEngine** | Flexbox 布局 | `Core/Layout/YogaLayoutEngine.swift` |
| **ExpressionEngine** | 表达式求值 | `Core/Expression/ExpressionEngine.swift` |
| **DataBindingManager** | 数据绑定 | `Core/Binding/DataBindingManager.swift` |
| **ViewDiffer** | Diff 算法 | `Core/Diff/ViewDiffer.swift` |
| **DiffPatcher** | Patch 应用 | `Core/Diff/DiffPatcher.swift` |
| **ComponentRegistry** | 组件注册 | `Components/Component.swift` |

---

## Quick Start

### 1. 集成

```ruby
# Podfile
pod 'TemplateX'
pod 'TemplateXService'  # 图片加载等 Service 实现
```

### 2. 初始化

```swift
// AppDelegate.swift
import TemplateX
import TemplateXService

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    
    // 1. 注册图片加载器
    TemplateX.registerImageLoader(SDWebImageLoader())
    
    // 2. 预热引擎（异步，避免阻塞启动）
    DispatchQueue.global(qos: .userInitiated).async {
        TemplateX.warmUp()
    }
    
    return true
}
```

### 3. 渲染模板

**方式一：简单 API**

```swift
// 从 JSON 字典渲染
let template: [String: Any] = [
    "type": "container",
    "style": [
        "width": "100%",
        "height": 100,
        "backgroundColor": "#FF6B6B",
        "cornerRadius": 12,
        "padding": 16
    ],
    "children": [
        [
            "type": "text",
            "props": ["text": "Hello TemplateX!"],
            "style": ["fontSize": 18, "textColor": "#FFFFFF"]
        ]
    ]
]

if let view = TemplateX.render(json: template) {
    containerView.addSubview(view)
}
```

**方式二：使用 TemplateXView**

```swift
// 创建 TemplateXView（推荐方式）
let templateView = TemplateXView { builder in
    builder.config = TemplateXConfig { config in
        config.enablePerformanceMonitor = true
    }
}

// 加载模板
templateView.loadTemplate(json: template, data: userData)

// 更新数据
templateView.updateData(newUserData)
```

**方式三：从 Bundle 加载**

```swift
// 加载 Bundle 中的 user_card.json
let view = TemplateX.render("user_card", data: [
    "user": ["name": "张三", "age": 28, "isVip": true],
    "stats": ["followers": "1.2k", "following": 386, "posts": 52]
])
```

### 4. 模板语法

**基础结构：**

```json
{
  "type": "container",          // 组件类型
  "id": "card",                 // 组件 ID（可选）
  "style": {                    // 样式
    "width": "100%",
    "flexDirection": "row",
    "backgroundColor": "#FFFFFF"
  },
  "props": {                    // 组件属性
    "text": "Hello"
  },
  "children": []                // 子组件
}
```

**数据绑定：**

```json
{
  "type": "text",
  "props": {
    "text": "${user.name}"                    // 简单绑定
  }
},
{
  "type": "text", 
  "props": {
    "text": "${'年龄: ' + user.age + ' 岁'}"  // 表达式拼接
  }
},
{
  "type": "container",
  "bindings": {
    "display": "${user.isVip}"                // 条件显示
  }
}
```

**支持的组件：**

| 组件类型 | 说明 | 对应 UIKit |
|---------|------|-----------|
| `container` | 容器 | UIView |
| `text` | 文本 | UILabel |
| `image` | 图片 | UIImageView |
| `button` | 按钮 | UIButton |
| `input` | 输入框 | UITextField |
| `scroll` | 滚动视图 | UIScrollView |
| `list` | 列表 | UICollectionView |

---

## 性能数据

### 渲染性能

测试环境：iPhone 14 Pro，iOS 17，Release 模式

| 场景 | 首次渲染 | 预热后 |
|------|---------|-------|
| 简单卡片（5 个组件） | 3ms | <1ms |
| 复杂卡片（20 个组件） | 8ms | 2ms |
| 列表页（50 个 Cell） | 15ms | 5ms |

### 与 Native 对比

| 指标 | Native UIKit | TemplateX | 差距 |
|------|-------------|-----------|------|
| 首屏渲染 | 5ms | 8ms | +60% |
| 滚动帧率 | 60fps | 60fps | 持平 |
| 内存占用 | 基准 | +5% | 略高 |
| 包体积 | - | +500KB | Yoga 库 |

**结论：TemplateX 的性能开销在可接受范围内，换取了动态化能力。**

---

## 下一篇预告

本文介绍了 TemplateX 的设计背景和整体架构。下一篇我们将深入 **模板解析与组件系统**，包括：

- TemplateParser 如何解析 JSON
- Component 协议设计
- ComponentRegistry 注册机制
- 如何扩展自定义组件

---

## 系列文章

1. **TemplateX 概述与架构设计**（本文）
2. 模板解析与组件系统
3. Flexbox 布局引擎
4. 表达式引擎与数据绑定
5. Diff + Patch 增量更新
6. GapWorker 列表优化
7. 性能优化实战

---

## 参考资料

- [Yoga Layout](https://yogalayout.dev/) - Facebook 的 Flexbox 实现
- [Lynx](https://lynx.dev/) - 字节跳动的跨端框架
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Apple 的声明式 UI 框架
