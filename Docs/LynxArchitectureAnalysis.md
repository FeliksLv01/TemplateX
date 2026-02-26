# Lynx 渲染架构分析

> 基于 Lynx 源码分析，用于指导 TemplateX 的性能优化

## 1. 整体架构

Lynx 采用 **多线程 Actor 架构**，核心设计理念是将渲染流程拆分到多个独立线程，通过消息队列通信，避免共享状态和同步阻塞。

```
┌─────────────────────────────────────────────────────────────────┐
│                         LynxView                                │
│                    (iOS UIView 容器)                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LynxTemplateRender                         │
│                    (模板渲染协调器)                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        LynxShell                                │
│                    (C++ 渲染引擎核心)                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ UI Actor │  │TASM Actor│  │Layout    │  │ JS Actor │        │
│  │ (主线程) │  │(模板组装)│  │Actor     │  │(JS执行)  │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
│       │             │             │             │               │
│       └─────────────┴─────────────┴─────────────┘               │
│                           │                                     │
│                           ▼                                     │
│               ┌───────────────────────┐                         │
│               │  UIOperationQueue     │                         │
│               │  (UI 操作队列)        │                         │
│               └───────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

### 关键文件

| 文件 | 路径 | 说明 |
|------|------|------|
| LynxShell | `core/shell/lynx_shell.h/cc` | 渲染引擎核心 |
| LynxEngine | `core/shell/lynx_engine.h/cc` | 引擎实例 |
| TasmMediator | `core/shell/tasm_mediator.h/cc` | TASM 线程中介 |
| LayoutMediator | `core/shell/layout_mediator.h/cc` | Layout 线程中介 |
| LynxView | `platform/darwin/ios/lynx/LynxView.mm` | iOS 视图容器 |
| LynxTemplateRender | `platform/darwin/ios/lynx/LynxTemplateRender.mm` | iOS 渲染协调 |

---

## 2. 多线程模型

### 2.1 四种线程策略

定义在 `core/base/threading/task_runner_manufactor.h`:

```cpp
enum ThreadStrategyForRendering {
  ALL_ON_UI = 0,      // 所有操作在 UI 线程（同步模式）
  MOST_ON_TASM = 1,   // 大部分操作在 TASM 线程
  PART_ON_LAYOUT = 2, // 部分操作在 Layout 线程
  MULTI_THREADS = 3,  // 完全多线程模式
};
```

### 2.2 线程职责

| 线程 | 职责 | 说明 |
|------|------|------|
| **UI Thread** | 视图创建/更新、事件处理 | iOS 主线程，UIKit 操作必须在此执行 |
| **TASM Thread** | 模板解析、数据绑定、组件树构建 | Template Assembly，核心计算线程 |
| **Layout Thread** | Flexbox 布局计算 | 可选，高负载时分离布局计算 |
| **JS Thread** | JavaScript 执行 | 可选，执行业务逻辑 |

### 2.3 线程通信

通过 **消息队列 + 条件变量** 实现线程同步：

```cpp
// 核心数据结构
class LynxUIOperationAsyncQueue {
    std::mutex tasm_mutex_;
    std::condition_variable tasm_cv_;
    std::atomic<bool> tasm_finish_;
    
    std::mutex layout_mutex_;
    std::condition_variable layout_cv_;
    std::atomic<bool> layout_finish_;
    
    base::ConcurrentQueue<UIOperation> pending_operations_;
    base::ConcurrentQueue<UIOperation> operations_;
};
```

---

## 3. UIOperationQueue 机制

这是 Lynx 避免白屏的**核心机制**。

### 3.1 设计思想

**所有 UI 操作都被封装成闭包，入队后在合适的时机批量执行。**

```cpp
// UI 操作定义
using UIOperation = std::function<void()>;

// 入队操作
void EnqueueUIOperation(UIOperation operation) {
    pending_operations_.Push(std::move(operation));
}
```

### 3.2 UI 操作类型

从 `core/renderer/ui_wrapper/painting/ios/painting_context_darwin.mm` 可以看到：

```cpp
// 创建视图
void CreateView(LynxUI* ui) {
    EnqueueUIOperation([ui]() {
        [ui createView];
    });
}

// 添加子视图
void AddChild(LynxUI* parent, LynxUI* child, int index) {
    EnqueueUIOperation([parent, child, index]() {
        [parent insertChild:child atIndex:index];
    });
}

// 设置 Frame
void SetFrame(LynxUI* ui, CGRect frame) {
    EnqueueUIOperation([ui, frame]() {
        ui.view.frame = frame;
    });
}

// 更新属性
void UpdateProps(LynxUI* ui, NSDictionary* props) {
    EnqueueUIOperation([ui, props]() {
        [ui updateWithProps:props];
    });
}
```

### 3.3 Flush 机制

**同步模式** (`LynxUIOperationQueue`):

```cpp
void LynxUIOperationQueue::Flush() {
    // 直接在当前线程执行所有操作
    for (auto& op : operations_) {
        op();
    }
    operations_.clear();
}
```

**异步模式** (`LynxUIOperationAsyncQueue`):

```cpp
void LynxUIOperationAsyncQueue::FlushOnUIThread() {
    // 1. 等待 TASM 线程完成（超时 100ms）
    {
        std::unique_lock<std::mutex> lock(tasm_mutex_);
        tasm_cv_.wait_for(lock, 100ms, [this] { 
            return tasm_finish_.load(); 
        });
    }
    
    // 2. 执行中间刷新（TASM 产生的 UI 操作）
    FlushInterval();
    
    // 3. 等待 Layout 线程完成（超时 100ms）
    {
        std::unique_lock<std::mutex> lock(layout_mutex_);
        layout_cv_.wait_for(lock, 100ms, [this] { 
            return layout_finish_.load(); 
        });
    }
    
    // 4. 执行最终刷新（Layout 产生的 UI 操作）
    FlushInterval();
}

void LynxUIOperationAsyncQueue::FlushInterval() {
    auto operations = operations_.PopAll();
    for (auto& op : operations) {
        op();  // 在 UI 线程执行
    }
}
```

---

## 4. SyncFlush 避免白屏

### 4.1 触发时机

在 `LynxView.mm` 的 `layoutSubviews` 中：

```objc
- (void)layoutSubviews {
    if (_enableAutoLayout) {
        [_templateRender updateFrame:frame];
    }
    
    // 关键：在首次布局时同步刷新
    if (_enableSyncFlush && [self.subviews count] > 0) {
        [self syncFlush];
    }
    
    [super layoutSubviews];
}

- (void)syncFlush {
    [_templateRender syncFlush];
}
```

### 4.2 SyncFlush 流程

```
loadTemplate() 调用
    ↓
[TASM 线程] parse → bind → 生成 UI 操作 → 入队
    ↓                                    ↓
[Layout 线程] calculateLayout → 生成 UI 操作 → 入队
    ↓
UIOperationQueue 积累了所有 UI 操作
    ↓
layoutSubviews() 触发
    ↓
syncFlush() 调用
    ↓
FlushOnUIThread():
    ├── 等待 TASM 完成（100ms 超时）
    ├── FlushInterval()  ← 执行 TASM 产生的 UI 操作
    ├── 等待 Layout 完成（100ms 超时）
    └── FlushInterval()  ← 执行 Layout 产生的 UI 操作
    ↓
所有视图已创建并添加到视图树
    ↓
首帧渲染完成，无白屏
```

### 4.3 为什么不会白屏？

1. **UI 操作延迟执行**：createView、addSubview 等操作入队但不立即执行
2. **layoutSubviews 同步点**：在视图即将显示时，同步等待所有操作完成
3. **批量执行**：所有 UI 操作一次性执行，减少上下文切换
4. **超时保护**：最多等待 200ms（100ms TASM + 100ms Layout），不会无限阻塞

---

## 5. LynxEnginePool 引擎复用

### 5.1 设计思想

对于相同模板，复用整个 LynxEngine 实例，避免重复初始化。

### 5.2 实现

定义在 `platform/darwin/ios/lynx/LynxEnginePool.mm`:

```objc
@implementation LynxEnginePool {
    NSMutableDictionary<NSString*, NSMutableArray<LynxEngine*>*>* _pool;
}

// 注册可复用的引擎
- (void)registerReuseEngine:(LynxEngine*)engine 
              templateBundle:(NSString*)templateBundle {
    engine.state = LynxEngineStateReadyToBeReused;
    
    NSMutableArray* engines = _pool[templateBundle];
    if (!engines) {
        engines = [NSMutableArray array];
        _pool[templateBundle] = engines;
    }
    [engines addObject:engine];
}

// 获取可复用的引擎
- (LynxEngine*)pollEngineWithRender:(LynxTemplateRender*)render 
                      templateBundle:(NSString*)templateBundle {
    NSMutableArray* engines = _pool[templateBundle];
    if (engines.count == 0) {
        return nil;  // 池中没有，需要新建
    }
    
    LynxEngine* engine = engines.lastObject;
    [engines removeLastObject];
    
    engine.state = LynxEngineStateOnReusing;
    [engine attachToRender:render];
    
    return engine;
}
```

### 5.3 引擎状态机

```
┌──────────────┐
│   Unloaded   │ ← 初始状态
└──────┬───────┘
       │ loadTemplate()
       ▼
┌──────────────┐
│   Running    │ ← 正常运行
└──────┬───────┘
       │ detach()
       ▼
┌──────────────────────┐
│  ReadyToBeReused     │ ← 可复用，在池中等待
└──────┬───────────────┘
       │ pollEngine()
       ▼
┌──────────────┐
│  OnReusing   │ ← 正在复用
└──────┬───────┘
       │ attach() 完成
       ▼
┌──────────────┐
│   Running    │ ← 再次运行
└──────────────┘
```

---

## 6. 其他优化策略

### 6.1 异步视图创建

部分视图可以在并发队列创建：

```objc
// painting_context_darwin.mm
if (enable_create_ui_async_ && [ui canCreateAsync]) {
    dispatch_async(concurrent_queue_, ^{
        UIView* view = [ui createViewAsync];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [ui attachView:view];
        });
    });
} else {
    [ui createView];  // 主线程创建
}
```

### 6.2 SSR Hydration

支持服务端渲染数据预加载：

```objc
// 1. 先加载 SSR 数据，快速渲染静态内容
[lynxView loadSSRData:ssrData];

// 2. 后续异步加载 JS 逻辑
[lynxView loadTemplate:templateData];
```

### 6.3 预加载组件

```objc
// 预加载动态组件
[lynxView preloadDynamicComponents:@[@"card", @"banner"]];

// 预加载 JS 脚本
[lynxView preloadJSPaths:@[@"common.js", @"utils.js"]];
```

### 6.4 列表优化

```objc
// 列表预加载缓冲区
@property (nonatomic) NSInteger preloadBufferCount;

// 列表项复用
- (LynxUI*)dequeueReusableItemWithIdentifier:(NSString*)identifier;
```

---

## 7. 与 TemplateX 的对比

| 特性 | Lynx | TemplateX | 差距 |
|------|------|-----------|------|
| **线程模型** | 4 线程 Actor | 单线程为主 | Lynx 并行度更高 |
| **UI 操作** | 队列批处理 | 直接执行 | Lynx 减少上下文切换 |
| **首帧渲染** | SyncFlush 同步点 | 同步渲染 | 相似，但 Lynx 并行准备 |
| **引擎复用** | LynxEnginePool | 模板缓存 | Lynx 复用粒度更大 |
| **视图复用** | dequeueReusable | ViewRecyclePool | 相似 |
| **预加载** | 组件/JS 预加载 | warmUp 预热 | TemplateX 较简单 |

---

## 8. 可借鉴的优化方向

### 8.1 UIOperationQueue（高优先级）

将 UI 操作封装成闭包入队，在合适时机批量执行：

```swift
class UIOperationQueue {
    private var operations: [() -> Void] = []
    
    func enqueue(_ operation: @escaping () -> Void) {
        operations.append(operation)
    }
    
    func flush() {
        for op in operations {
            op()
        }
        operations.removeAll()
    }
}
```

### 8.2 异步流水线 + SyncFlush（高优先级）

```swift
// 1. loadTemplate 启动异步流水线
func loadTemplate(json: [String: Any], data: [String: Any]?) {
    DispatchQueue.global(qos: .userInitiated).async {
        // [后台线程] parse + bind + layout
        let component = self.parse(json)
        self.bind(data, to: component)
        let layoutResults = self.calculateLayout(component)
        
        // 生成 UI 操作
        self.generateUIOperations(component, layoutResults)
        
        // 标记完成
        self.markReady()
    }
}

// 2. layoutSubviews 时 SyncFlush
override func layoutSubviews() {
    super.layoutSubviews()
    syncFlush(timeout: 0.1)  // 100ms
}
```

### 8.3 RenderContextPool（中优先级）

类似 LynxEnginePool，复用整个渲染上下文：

```swift
class RenderContextPool {
    private var pool: [String: [RenderContext]] = [:]
    
    func register(_ context: RenderContext, templateId: String)
    func poll(templateId: String) -> RenderContext?
}
```

### 8.4 并行视图创建（低优先级）

对于不依赖主线程的视图属性，可以并行准备：

```swift
// 并发准备视图属性
DispatchQueue.concurrentPerform(iterations: components.count) { i in
    let component = components[i]
    component.prepareViewProperties()  // 计算颜色、字体等
}

// 主线程创建和添加视图
DispatchQueue.main.async {
    for component in components {
        let view = component.createView()
        parent.addSubview(view)
    }
}
```

---

## 9. 总结

Lynx 的高性能渲染核心在于：

1. **多线程并行**：TASM/Layout 在后台线程执行，不阻塞 UI
2. **UI 操作队列**：所有 UI 操作入队批处理，减少上下文切换
3. **SyncFlush 同步点**：在 layoutSubviews 时同步等待，确保首帧完整
4. **引擎复用**：LynxEnginePool 复用整个引擎实例
5. **超时保护**：最多等待 200ms，不会无限阻塞

TemplateX 可以借鉴这些策略，特别是 **UIOperationQueue + SyncFlush** 机制，这是避免白屏的关键。
