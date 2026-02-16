# TemplateX Demo App

这是 TemplateX 的示例应用，展示框架的核心功能。

## 运行方式

### 使用 CocoaPods（推荐）

```bash
# 1. 进入 Example 目录
cd Example

# 2. 安装依赖
pod install

# 3. 打开工作空间
open TemplateXDemo.xcworkspace
```

然后在 Xcode 中选择模拟器或真机运行即可。

### 如果 pod install 报错

确保已安装 CocoaPods：
```bash
sudo gem install cocoapods
```

## Demo 内容

| Demo | 说明 |
|------|------|
| **基础渲染** | 演示基本的 JSON → 视图渲染流程 |
| **数据绑定** | 演示 `${expression}` 数据绑定和表达式求值 |
| **增量更新** | 演示 Diff + Patch 增量更新机制 |
| **布局系统** | 演示 Yoga Flexbox 布局能力 |
| **组件展示** | 展示所有内置组件 |
| **性能测试** | 渲染性能基准测试 |

## 文件结构

```
Example/
├── Podfile                     # CocoaPods 配置
├── TemplateXDemo.xcodeproj/    # Xcode 项目
├── Templates/                  # XML 模板示例
│   ├── home_card.xml
│   └── user_profile.xml
└── TemplateXDemo/
    ├── AppDelegate.swift       # App 入口
    ├── DemoListViewController.swift
    ├── Info.plist
    ├── Demos/                  # Demo 视图控制器
    │   ├── BasicRenderDemoViewController.swift
    │   ├── DataBindingDemoViewController.swift
    │   ├── IncrementalUpdateDemoViewController.swift
    │   ├── LayoutDemoViewController.swift
    │   ├── ComponentShowcaseViewController.swift
    │   └── PerformanceDemoViewController.swift
    └── Resources/
        └── home_card.json      # 示例 JSON 模板
```

## 快速开始代码

```swift
import TemplateX

// 1. 定义模板
let template: [String: Any] = [
    "type": "text",
    "id": "greeting",
    "props": [
        "text": "${message}",
        "fontSize": 16
    ]
]

// 2. 绑定数据
let data: [String: Any] = [
    "message": "Hello TemplateX!"
]

// 3. 渲染
let view = RenderEngine.shared.render(
    json: template,
    data: data,
    containerSize: CGSize(width: 375, height: 100)
)

// 4. 增量更新
RenderEngine.shared.update(
    view: view,
    data: ["message": "Updated!"],
    containerSize: CGSize(width: 375, height: 100)
)
```

## 依赖说明

TemplateX 通过 CocoaPods 自动引入以下依赖：

- **YogaKit** (~> 2.0) - Facebook 的 Flexbox 布局引擎
- **Antlr4** (~> 4.13) - 表达式解析器生成器

这些依赖会在 `pod install` 时自动下载和配置。
