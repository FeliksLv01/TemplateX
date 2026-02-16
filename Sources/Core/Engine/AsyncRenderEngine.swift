import UIKit

// MARK: - 异步渲染引擎

/// 完整异步渲染引擎
/// 在子线程执行：JSON 解析、组件树创建、布局计算
/// 在主线程执行：UIView 创建和更新
///
/// 特性：
/// - 支持任务取消（Cell 快速滑动场景）
/// - 使用 RenderTask 封装任务，支持通过 taskId 取消
/// - 在主线程 UI 操作前检查取消状态
public final class AsyncRenderEngine {
    
    // MARK: - Singleton
    
    public static let shared = AsyncRenderEngine()
    
    // MARK: - Configuration
    
    /// 异步渲染配置
    public struct Config {
        /// 是否启用视图复用
        public var enableViewReuse: Bool = true
        
        /// 是否启用性能监控
        public var enablePerformanceMonitor: Bool = false
        
        /// 预热节点数量
        public var warmUpNodeCount: Int = 64
        
        public init() {}
    }
    
    public var config = Config()
    
    // MARK: - Task Management
    
    /// 活跃的渲染任务（taskId -> RenderTask）
    private var activeTasks: [String: RenderTask] = [:]
    private let taskLock = UnfairLock()
    
    // MARK: - Dependencies
    
    private let asyncLayoutEngine = AsyncLayoutEngine.shared
    private let templateParser = TemplateParser.shared
    private let dataBindingManager = DataBindingManager.shared
    private let viewRecyclePool = ViewRecyclePool.shared
    
    // MARK: - Queues
    
    /// 解析和组件创建队列（并发，CPU 密集）
    private let parseQueue = DispatchQueue(
        label: "com.templatex.parse",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    /// 主线程队列（用于 UI 操作）
    private let mainQueue = DispatchQueue.main
    
    // MARK: - Render State Cache
    
    /// 已渲染的组件树缓存 (viewIdentifier -> Component)
    private var renderedComponents: [String: Component] = [:]
    private let cacheLock = UnfairLock()
    
    // MARK: - 任务取消统计（调试用）
    
    #if DEBUG
    private var cancelledTaskCount: Int = 0
    #endif
    
    // MARK: - Init
    
    private init() {
        // 预热布局引擎
        asyncLayoutEngine.warmUp(nodeCount: config.warmUpNodeCount)
    }
    
    // MARK: - 异步渲染 API
    
    /// 从 JSON 异步渲染视图
    /// - Parameters:
    ///   - json: JSON 字典
    ///   - data: 绑定数据
    ///   - containerSize: 容器尺寸
    ///   - taskId: 任务标识符（用于取消，可选）
    ///   - completion: 完成回调（主线程）
    /// - Returns: RenderTask 句柄，可用于取消
    @discardableResult
    public func renderAsync(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize,
        taskId: String? = nil,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) -> RenderTask {
        // 创建任务
        let task = RenderTask(id: taskId ?? UUID().uuidString)
        
        // 如果指定了 taskId，取消同 id 的旧任务
        if let taskId = taskId {
            cancelTask(id: taskId)
        }
        
        // 注册任务
        taskLock.lock()
        activeTasks[task.id] = task
        taskLock.unlock()
        
        // 子线程：解析 + 组件创建 + 数据绑定 + 布局
        parseQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查取消状态
            if task.isCancelled {
                self.removeTask(task)
                return
            }
            
            // 1. 解析 JSON -> Component
            guard let component = self.templateParser.parse(json: json) else {
                self.removeTask(task)
                self.mainQueue.async {
                    if !task.isCancelled {
                        completion(.failure(.parseError("Failed to parse JSON")))
                    }
                }
                return
            }
            
            // 检查取消状态
            if task.isCancelled {
                self.removeTask(task)
                return
            }
            
            // 2. 数据绑定（在子线程，只是数据处理）
            if let data = data {
                self.dataBindingManager.bind(data: data, to: component)
            }
            
            // 3. 异步布局
            self.asyncLayoutEngine.calculateLayoutAsync(
                for: component,
                containerSize: containerSize
            ) { [weak self] layoutResults in
                guard let self = self else { return }
                
                // 检查取消状态（在主线程 UI 操作前）
                if task.isCancelled {
                    self.removeTask(task)
                    #if DEBUG
                    self.taskLock.lock()
                    self.cancelledTaskCount += 1
                    let count = self.cancelledTaskCount
                    self.taskLock.unlock()
                    TXLogger.debug("AsyncRenderEngine: task cancelled before UI creation, total cancelled: \(count)")
                    #endif
                    return
                }
                
                // 主线程：应用布局 + 创建视图
                self.applyLayoutResults(layoutResults, to: component)
                let view = self.createViewTree(component)
                self.updateViewTree(component)
                
                // 缓存
                let viewId = self.generateViewIdentifier(view)
                self.cacheLock.lock()
                self.renderedComponents[viewId] = component
                self.cacheLock.unlock()
                
                // 移除任务
                self.removeTask(task)
                
                // 最终检查取消状态（防止在缓存期间被取消）
                if !task.isCancelled {
                    completion(.success(RenderOutput(view: view, component: component)))
                }
            }
        }
        
        return task
    }
    
    /// 从 JSON 异步渲染视图（简化版，无任务句柄）
    public func renderAsync(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) {
        _ = renderAsync(json: json, data: data, containerSize: containerSize, taskId: nil, completion: completion)
    }
    
    /// 从模板名称异步渲染
    @discardableResult
    public func renderAsync(
        templateName: String,
        data: [String: Any]? = nil,
        containerSize: CGSize,
        taskId: String? = nil,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) -> RenderTask {
        // 创建任务
        let task = RenderTask(id: taskId ?? UUID().uuidString)
        
        // 如果指定了 taskId，取消同 id 的旧任务
        if let taskId = taskId {
            cancelTask(id: taskId)
        }
        
        // 注册任务
        taskLock.lock()
        activeTasks[task.id] = task
        taskLock.unlock()
        
        parseQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查取消状态
            if task.isCancelled {
                self.removeTask(task)
                return
            }
            
            // 1. 加载模板
            guard let component = TemplateLoader.shared.loadFromBundle(name: templateName) else {
                self.removeTask(task)
                self.mainQueue.async {
                    if !task.isCancelled {
                        completion(.failure(.templateNotFound(templateName)))
                    }
                }
                return
            }
            
            // 检查取消状态
            if task.isCancelled {
                self.removeTask(task)
                return
            }
            
            // 2. 数据绑定
            if let data = data {
                self.dataBindingManager.bind(data: data, to: component)
            }
            
            // 3. 异步布局
            self.asyncLayoutEngine.calculateLayoutAsync(
                for: component,
                containerSize: containerSize
            ) { [weak self] layoutResults in
                guard let self = self else { return }
                
                // 检查取消状态
                if task.isCancelled {
                    self.removeTask(task)
                    return
                }
                
                self.applyLayoutResults(layoutResults, to: component)
                let view = self.createViewTree(component)
                self.updateViewTree(component)
                
                let viewId = self.generateViewIdentifier(view)
                self.cacheLock.lock()
                self.renderedComponents[viewId] = component
                self.cacheLock.unlock()
                
                // 移除任务
                self.removeTask(task)
                
                if !task.isCancelled {
                    completion(.success(RenderOutput(view: view, component: component)))
                }
            }
        }
        
        return task
    }
    
    /// 从模板名称异步渲染（简化版，无任务句柄）
    public func renderAsync(
        templateName: String,
        data: [String: Any]? = nil,
        containerSize: CGSize,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) {
        _ = renderAsync(templateName: templateName, data: data, containerSize: containerSize, taskId: nil, completion: completion)
    }
    
    /// 从 JSON 字符串异步渲染
    @discardableResult
    public func renderAsync(
        jsonString: String,
        data: [String: Any]? = nil,
        containerSize: CGSize,
        taskId: String? = nil,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) -> RenderTask {
        // 创建任务
        let task = RenderTask(id: taskId ?? UUID().uuidString)
        
        // 如果指定了 taskId，取消同 id 的旧任务
        if let taskId = taskId {
            cancelTask(id: taskId)
        }
        
        // 注册任务
        taskLock.lock()
        activeTasks[task.id] = task
        taskLock.unlock()
        
        parseQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查取消状态
            if task.isCancelled {
                self.removeTask(task)
                return
            }
            
            // 解析 JSON 字符串
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                self.removeTask(task)
                self.mainQueue.async {
                    if !task.isCancelled {
                        completion(.failure(.parseError("Invalid JSON string")))
                    }
                }
                return
            }
            
            // 继续渲染流程（主线程调用）
            self.mainQueue.async {
                // 使用同一个 task，不重新创建
                self.continueRenderAsync(json: json, data: data, containerSize: containerSize, task: task, completion: completion)
            }
        }
        
        return task
    }
    
    /// 从 JSON 字符串异步渲染（简化版）
    public func renderAsync(
        jsonString: String,
        data: [String: Any]? = nil,
        containerSize: CGSize,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) {
        _ = renderAsync(jsonString: jsonString, data: data, containerSize: containerSize, taskId: nil, completion: completion)
    }
    
    /// 继续渲染流程（内部方法，复用已有 task）
    private func continueRenderAsync(
        json: [String: Any],
        data: [String: Any]?,
        containerSize: CGSize,
        task: RenderTask,
        completion: @escaping (Result<RenderOutput, RenderError>) -> Void
    ) {
        // 检查取消状态
        if task.isCancelled {
            removeTask(task)
            return
        }
        
        parseQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查取消状态
            if task.isCancelled {
                self.removeTask(task)
                return
            }
            
            // 1. 解析 JSON -> Component
            guard let component = self.templateParser.parse(json: json) else {
                self.removeTask(task)
                self.mainQueue.async {
                    if !task.isCancelled {
                        completion(.failure(.parseError("Failed to parse JSON")))
                    }
                }
                return
            }
            
            // 2. 数据绑定
            if let data = data {
                self.dataBindingManager.bind(data: data, to: component)
            }
            
            // 3. 异步布局
            self.asyncLayoutEngine.calculateLayoutAsync(
                for: component,
                containerSize: containerSize
            ) { [weak self] layoutResults in
                guard let self = self else { return }
                
                // 检查取消状态
                if task.isCancelled {
                    self.removeTask(task)
                    return
                }
                
                self.applyLayoutResults(layoutResults, to: component)
                let view = self.createViewTree(component)
                self.updateViewTree(component)
                
                let viewId = self.generateViewIdentifier(view)
                self.cacheLock.lock()
                self.renderedComponents[viewId] = component
                self.cacheLock.unlock()
                
                // 移除任务
                self.removeTask(task)
                
                if !task.isCancelled {
                    completion(.success(RenderOutput(view: view, component: component)))
                }
            }
        }
    }
    
    // MARK: - 批量异步渲染
    
    /// 批量异步渲染多个模板
    public func renderBatchAsync(
        items: [(json: [String: Any], data: [String: Any]?, containerSize: CGSize)],
        completion: @escaping ([Result<RenderOutput, RenderError>]) -> Void
    ) {
        let group = DispatchGroup()
        var results: [Int: Result<RenderOutput, RenderError>] = [:]
        let resultsLock = UnfairLock()
        
        for (index, item) in items.enumerated() {
            group.enter()
            
            renderAsync(json: item.json, data: item.data, containerSize: item.containerSize) { result in
                resultsLock.lock()
                results[index] = result
                resultsLock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: mainQueue) {
            // 按顺序返回结果
            let sortedResults = (0..<items.count).map { index in
                results[index] ?? .failure(.unknown("Result not found"))
            }
            completion(sortedResults)
        }
    }
    
    // MARK: - 异步更新
    
    /// 异步增量更新
    public func updateAsync(
        view: UIView,
        data: [String: Any],
        containerSize: CGSize,
        completion: @escaping (Result<Int, RenderError>) -> Void
    ) {
        let viewId = generateViewIdentifier(view)
        
        cacheLock.lock()
        guard let oldComponent = renderedComponents[viewId] else {
            cacheLock.unlock()
            completion(.failure(.componentNotFound))
            return
        }
        cacheLock.unlock()
        
        parseQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. 克隆组件树并绑定新数据
            let newComponent = self.cloneComponentTree(oldComponent)
            self.dataBindingManager.bind(data: data, to: newComponent)
            
            // 2. 计算 Diff
            let diffResult = ViewDiffer.shared.diff(oldTree: oldComponent, newTree: newComponent)
            
            guard diffResult.hasDiff else {
                self.mainQueue.async {
                    completion(.success(0))
                }
                return
            }
            
            // 3. 异步计算新布局
            self.asyncLayoutEngine.calculateLayoutAsync(
                for: newComponent,
                containerSize: containerSize
            ) { [weak self] layoutResults in
                guard let self = self else { return }
                
                // 4. 应用 Diff（主线程）
                self.applyLayoutResults(layoutResults, to: newComponent)
                
                DiffPatcher.shared.apply(
                    diffResult,
                    to: oldComponent,
                    rootView: view,
                    containerSize: containerSize
                )
                
                completion(.success(diffResult.operationCount))
            }
        }
    }
    
    // MARK: - 组件管理
    
    /// 获取视图关联的组件
    public func getComponent(for view: UIView) -> Component? {
        let viewId = generateViewIdentifier(view)
        cacheLock.lock()
        let component = renderedComponents[viewId]
        cacheLock.unlock()
        return component
    }
    
    /// 清理视图关联的缓存
    public func cleanup(view: UIView) {
        let viewId = generateViewIdentifier(view)
        
        cacheLock.lock()
        if let component = renderedComponents.removeValue(forKey: viewId) {
            cacheLock.unlock()
            viewRecyclePool.recycleComponentTree(component)
        } else {
            cacheLock.unlock()
        }
    }
    
    /// 清理所有缓存
    public func clearAllCache() {
        cacheLock.lock()
        renderedComponents.removeAll()
        cacheLock.unlock()
        viewRecyclePool.clear()
    }
    
    // MARK: - 任务取消 API
    
    /// 取消指定 ID 的任务
    ///
    /// 常见使用场景：
    /// - Cell 复用时取消旧任务：`cancelTask(id: "cell_\(indexPath.section)_\(indexPath.item)")`
    /// - ViewController dismiss 时取消所有任务：`cancelAllTasks()`
    ///
    /// - Parameter id: 任务 ID
    public func cancelTask(id: String) {
        taskLock.lock()
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks.removeValue(forKey: id)
        }
        taskLock.unlock()
    }
    
    /// 取消所有活跃任务
    public func cancelAllTasks() {
        taskLock.lock()
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        taskLock.unlock()
        
        TXLogger.debug("AsyncRenderEngine: cancelled all tasks")
    }
    
    /// 获取当前活跃任务数量
    public var activeTaskCount: Int {
        taskLock.lock()
        let count = activeTasks.count
        taskLock.unlock()
        return count
    }
    
    // MARK: - Private: 任务管理
    
    /// 从活跃任务列表中移除
    private func removeTask(_ task: RenderTask) {
        taskLock.lock()
        activeTasks.removeValue(forKey: task.id)
        taskLock.unlock()
    }
    
    // MARK: - Private: 布局应用
    
    /// 应用布局结果到组件树（支持扁平化偏移累加）
    ///
    /// Yoga 返回的是相对于父节点的坐标。对于扁平化的父组件（没有创建 UIView），
    /// 其子组件的 view 实际上被添加到了更上层的祖先视图中，所以需要累加扁平化父组件的偏移。
    ///
    /// 注意：此方法在 createViewTree() 之前调用，所以需要使用 canFlatten 来判断
    /// 是否需要扁平化，并同时设置 isFlattened 标记。
    ///
    /// - Parameters:
    ///   - results: Yoga 计算的布局结果（相对坐标）
    ///   - component: 目标组件
    ///   - parentOffset: 扁平化父组件的累计偏移
    private func applyLayoutResults(
        _ results: [String: LayoutResult],
        to component: Component,
        parentOffset: CGPoint = .zero
    ) {
        // 获取 Yoga 计算的相对坐标
        guard let result = results[component.id] else {
            // 如果没有布局结果，继续处理子组件
            for child in component.children {
                applyLayoutResults(results, to: child, parentOffset: parentOffset)
            }
            return
        }
        
        // 计算当前组件应该累加到子组件的偏移
        var offsetForChildren: CGPoint = .zero
        
        // 应用布局结果
        var adjustedResult = result
        
        // 使用 canFlatten 判断（因为此方法在 createViewTree 之前调用，isFlattened 可能还未设置）
        // 同时设置 isFlattened 标记，供后续 createViewTree 使用
        let shouldFlatten = component.canFlatten
        if shouldFlatten {
            component.isFlattened = true
            // 扁平化组件：不设置自己的 frame（因为没有 view）
            // 但需要把自己的位置偏移传递给子组件
            offsetForChildren = CGPoint(
                x: parentOffset.x + result.frame.origin.x,
                y: parentOffset.y + result.frame.origin.y
            )
            component.layoutResult = result  // 保留原始结果用于其他用途
        } else {
            component.isFlattened = false
            // 非扁平化组件：累加父偏移到自己的 frame
            if parentOffset != .zero {
                adjustedResult.frame.origin.x += parentOffset.x
                adjustedResult.frame.origin.y += parentOffset.y
            }
            component.layoutResult = adjustedResult
            // 非扁平化组件的子组件不需要额外偏移
            offsetForChildren = .zero
        }
        
        // 递归处理子组件
        for child in component.children {
            applyLayoutResults(results, to: child, parentOffset: offsetForChildren)
        }
    }
    
    // MARK: - Private: 视图创建（必须主线程，支持扁平化）
    
    /// 创建视图树（支持视图扁平化）
    ///
    /// 扁平化原理：
    /// - 纯布局容器（无视觉效果、无事件）不创建真实 UIView
    /// - 子组件直接添加到最近的非扁平化祖先视图
    ///
    /// 注意：此方法只创建视图层级，不处理布局偏移。
    /// 布局偏移统一在 applyLayoutResults() 中处理。
    private func createViewTree(_ component: Component) -> UIView {
        assert(Thread.isMainThread, "createViewTree must be called on main thread")
        
        // 检查是否可以扁平化
        if component.canFlatten {
            component.isFlattened = true
            
            // 创建临时容器收集子视图
            let tempContainer = UIView()
            tempContainer.isHidden = true
            
            for child in component.children {
                let childView = createViewTree(child)
                tempContainer.addSubview(childView)
            }
            
            return tempContainer
        }
        
        // 非扁平化：正常创建视图
        let view: UIView
        if let existingView = component.view {
            view = existingView
        } else if config.enableViewReuse, let recycledView = viewRecyclePool.dequeueView(forType: component.type) {
            view = recycledView
            component.view = view
            // 复用视图时需要强制应用样式，避免旧样式残留
            if let baseComponent = component as? BaseComponent {
                baseComponent.forceApplyStyle = true
            }
        } else {
            view = component.createView()
        }
        
        view.componentType = component.type
        view.accessibilityIdentifier = component.id
        
        // 递归创建子视图
        for child in component.children {
            let result = createViewTree(child)
            
            // 检查是否是扁平化产生的临时容器
            if result.isHidden && result.componentType == nil {
                // 提取临时容器中的所有子视图
                for subview in result.subviews {
                    subview.removeFromSuperview()
                    view.addSubview(subview)
                }
            } else {
                if result.superview !== view {
                    view.addSubview(result)
                }
            }
        }
        
        return view
    }
    
    private func updateViewTree(_ component: Component) {
        assert(Thread.isMainThread, "updateViewTree must be called on main thread")
        
        component.updateView()
        
        for child in component.children {
            updateViewTree(child)
        }
    }
    
    // MARK: - Private: 组件克隆
    
    private func cloneComponentTree(_ component: Component) -> Component {
        let cloned = component.clone()
        
        for child in component.children {
            let clonedChild = cloneComponentTree(child)
            clonedChild.parent = cloned
            cloned.children.append(clonedChild)
        }
        
        return cloned
    }
    
    // MARK: - Private: 工具方法
    
    private func generateViewIdentifier(_ view: UIView) -> String {
        return "\(ObjectIdentifier(view))"
    }
}

// MARK: - 渲染输出

/// 异步渲染输出
public struct RenderOutput {
    /// 渲染的视图
    public let view: UIView
    
    /// 关联的组件树
    public let component: Component
}

// MARK: - 渲染错误

/// 渲染错误类型
public enum RenderError: Error, CustomStringConvertible {
    /// JSON 解析错误
    case parseError(String)
    
    /// 模板未找到
    case templateNotFound(String)
    
    /// 组件未找到
    case componentNotFound
    
    /// 布局计算错误
    case layoutError(String)
    
    /// 未知错误
    case unknown(String)
    
    public var description: String {
        switch self {
        case .parseError(let msg):
            return "Parse error: \(msg)"
        case .templateNotFound(let name):
            return "Template not found: \(name)"
        case .componentNotFound:
            return "Component not found in cache"
        case .layoutError(let msg):
            return "Layout error: \(msg)"
        case .unknown(let msg):
            return "Unknown error: \(msg)"
        }
    }
}

// MARK: - UnfairLock（高性能锁）

/// 基于 os_unfair_lock 的高性能锁
/// 比 NSLock 快约 10x
private final class UnfairLock {
    private var _lock = os_unfair_lock()
    
    func lock() {
        os_unfair_lock_lock(&_lock)
    }
    
    func unlock() {
        os_unfair_lock_unlock(&_lock)
    }
    
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Async/Await 支持 (iOS 13+)

@available(iOS 13.0, *)
extension AsyncRenderEngine {
    
    /// 使用 async/await 渲染 JSON
    public func render(
        json: [String: Any],
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) async throws -> RenderOutput {
        try await withCheckedThrowingContinuation { continuation in
            renderAsync(json: json, data: data, containerSize: containerSize) { result in
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 使用 async/await 渲染模板
    public func render(
        templateName: String,
        data: [String: Any]? = nil,
        containerSize: CGSize
    ) async throws -> RenderOutput {
        try await withCheckedThrowingContinuation { continuation in
            renderAsync(templateName: templateName, data: data, containerSize: containerSize) { result in
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 使用 async/await 更新
    public func update(
        view: UIView,
        data: [String: Any],
        containerSize: CGSize
    ) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            updateAsync(view: view, data: data, containerSize: containerSize) { result in
                switch result {
                case .success(let count):
                    continuation.resume(returning: count)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - RenderTask（渲染任务）

/// 异步渲染任务
///
/// 用于管理和取消异步渲染操作
/// Cell 快速滑动场景下，通过取消机制避免不必要的 UI 操作
///
/// 使用示例：
/// ```swift
/// // 方式1：使用 taskId 自动取消旧任务
/// AsyncRenderEngine.shared.renderAsync(
///     json: template,
///     data: itemData,
///     containerSize: cellSize,
///     taskId: "cell_\(indexPath.section)_\(indexPath.item)"
/// ) { result in
///     // ...
/// }
///
/// // 方式2：手动管理任务
/// let task = AsyncRenderEngine.shared.renderAsync(json: template, ...) { ... }
/// // 稍后取消
/// task.cancel()
/// ```
public final class RenderTask {
    
    /// 任务 ID
    public let id: String
    
    /// 创建时间
    public let createTime: CFAbsoluteTime
    
    /// 是否已取消（线程安全）
    public var isCancelled: Bool {
        os_unfair_lock_lock(&_lock)
        let cancelled = _isCancelled
        os_unfair_lock_unlock(&_lock)
        return cancelled
    }
    
    private var _isCancelled: Bool = false
    private var _lock = os_unfair_lock()
    
    init(id: String) {
        self.id = id
        self.createTime = CFAbsoluteTimeGetCurrent()
    }
    
    /// 取消任务
    ///
    /// 调用后：
    /// - 如果任务尚未开始，将不会执行
    /// - 如果任务正在执行，将在下一个检查点跳过后续步骤
    /// - 如果任务已完成，无任何效果
    public func cancel() {
        os_unfair_lock_lock(&_lock)
        _isCancelled = true
        os_unfair_lock_unlock(&_lock)
    }
}
