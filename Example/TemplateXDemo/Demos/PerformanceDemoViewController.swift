import UIKit
import TemplateX

/// 性能测试
class PerformanceDemoViewController: UIViewController {
    
    private var resultLabel: UILabel!
    private var progressView: UIProgressView!
    private var logTextView: UITextView!
    
    private var isRunning = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupUI()
    }
    
    private func setupUI() {
        // 结果标签
        resultLabel = UILabel()
        resultLabel.text = "点击按钮开始性能测试"
        resultLabel.textAlignment = .center
        resultLabel.font = .systemFont(ofSize: 16)
        resultLabel.numberOfLines = 0
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultLabel)
        
        // 进度条
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        view.addSubview(progressView)
        
        // 测试按钮
        let testButtons = [
            ("基础渲染 x100", #selector(runBasicRenderTest)),
            ("复杂布局 x50", #selector(runComplexLayoutTest)),
            ("数据绑定 x100", #selector(runDataBindingTest)),
            ("增量更新 x100", #selector(runIncrementalUpdateTest))
        ]
        
        let buttonStack = UIStackView()
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)
        
        for (title, selector) in testButtons {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 8
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            button.addTarget(self, action: selector, for: .touchUpInside)
            buttonStack.addArrangedSubview(button)
        }
        
        // 日志视图
        logTextView = UITextView()
        logTextView.isEditable = false
        logTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.backgroundColor = .secondarySystemBackground
        logTextView.layer.cornerRadius = 8
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            resultLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            progressView.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            buttonStack.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            logTextView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 20),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Tests
    
    @objc private func runBasicRenderTest() {
        runTest(name: "基础渲染", iterations: 100) { [weak self] in
            self?.performBasicRender()
        }
    }
    
    @objc private func runComplexLayoutTest() {
        runTest(name: "复杂布局", iterations: 50) { [weak self] in
            self?.performComplexLayoutRender()
        }
    }
    
    @objc private func runDataBindingTest() {
        runTest(name: "数据绑定", iterations: 100) { [weak self] in
            self?.performDataBindingRender()
        }
    }
    
    @objc private func runIncrementalUpdateTest() {
        runTest(name: "增量更新", iterations: 100) { [weak self] in
            self?.performIncrementalUpdate()
        }
    }
    
    private func runTest(name: String, iterations: Int, operation: @escaping () -> Void) {
        guard !isRunning else { return }
        isRunning = true
        
        progressView.isHidden = false
        progressView.progress = 0
        resultLabel.text = "正在运行 \(name) 测试..."
        logTextView.text = ""
        
        // 所有渲染操作必须在主线程执行
        var durations: [Double] = []
        var currentIteration = 0
        
        func runNextIteration() {
            guard currentIteration < iterations else {
                // 测试完成，计算统计
                finishTest(name: name, iterations: iterations, durations: durations)
                return
            }
            
            let start = CFAbsoluteTimeGetCurrent()
            operation()
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            durations.append(duration)
            
            currentIteration += 1
            progressView.progress = Float(currentIteration) / Float(iterations)
            
            // 使用 DispatchQueue.main.async 让 UI 有机会更新
            DispatchQueue.main.async {
                runNextIteration()
            }
        }
        
        // 开始测试
        DispatchQueue.main.async {
            runNextIteration()
        }
    }
    
    private func finishTest(name: String, iterations: Int, durations: [Double]) {
        isRunning = false
        progressView.isHidden = true
        
        // 计算统计
        let total = durations.reduce(0, +)
        let avg = total / Double(iterations)
        let sorted = durations.sorted()
        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        let p50 = sorted[iterations / 2]
        let p95 = sorted[Int(Double(iterations) * 0.95)]
        let p99 = sorted[Int(Double(iterations) * 0.99)]
        
        let result = """
        \(name) 测试完成 (\(iterations) 次)
        
        平均: \(String(format: "%.2f", avg)) ms
        最小: \(String(format: "%.2f", min)) ms
        最大: \(String(format: "%.2f", max)) ms
        P50: \(String(format: "%.2f", p50)) ms
        P95: \(String(format: "%.2f", p95)) ms
        P99: \(String(format: "%.2f", p99)) ms
        
        总耗时: \(String(format: "%.2f", total)) ms
        帧预算占用: \(String(format: "%.1f", avg / 16.67 * 100))% (基于 60fps)
        """
        
        resultLabel.text = "\(name): 平均 \(String(format: "%.2f", avg)) ms"
        logTextView.text = result
    }
    
    // MARK: - Test Operations
    
    private func performBasicRender() {
        // 统一 style 格式
        let template: [String: Any] = [
            "type": "view",
            "id": "basic",
            "style": ["width": 200, "height": 100, "backgroundColor": "#007AFF", "cornerRadius": 8]
        ]
        
        _ = RenderEngine.shared.render(
            json: template,
            containerSize: CGSize(width: 375, height: 200)
        )
    }
    
    private func performComplexLayoutRender() {
        // 模拟复杂的嵌套布局（3 层嵌套，每层 5 个子元素）
        func makeChildren(depth: Int) -> [[String: Any]] {
            guard depth > 0 else { return [] }
            
            return (0..<5).map { i in
                var child: [String: Any] = [
                    "type": "flex",
                    "id": "node_\(depth)_\(i)",
                    "style": [
                        "width": "100%",
                        "height": "auto",
                        "flexDirection": depth % 2 == 0 ? "row" : "column",
                        "padding": 4,
                        "backgroundColor": "#E0E0E0"
                    ]
                ]
                
                if depth > 1 {
                    child["children"] = makeChildren(depth: depth - 1)
                } else {
                    child["children"] = [
                        [
                            "type": "text",
                            "id": "text_\(depth)_\(i)",
                            "style": ["width": "auto", "height": "auto", "fontSize": 12],
                            "props": ["text": "Item \(i)"]
                        ]
                    ]
                }
                
                return child
            }
        }
        
        let template: [String: Any] = [
            "type": "flex",
            "id": "complex_root",
            "style": ["width": "100%", "height": "auto", "flexDirection": "column"],
            "children": makeChildren(depth: 3)
        ]
        
        _ = RenderEngine.shared.render(
            json: template,
            containerSize: CGSize(width: 375, height: 800)
        )
    }
    
    private func performDataBindingRender() {
        let template: [String: Any] = [
            "type": "flex",
            "id": "binding_root",
            "style": ["width": "100%", "height": "auto", "flexDirection": "column"],
            "children": (0..<10).map { i in
                [
                    "type": "text",
                    "id": "item_\(i)",
                    "style": ["width": "100%", "height": 30],
                    "props": [
                        "text": "${'Item ' + items[\(i)].name + ' - $' + items[\(i)].price}"
                    ]
                ] as [String: Any]
            }
        ]
        
        let data: [String: Any] = [
            "items": (0..<10).map { i in
                ["name": "Product \(i)", "price": Double.random(in: 10...100)]
            }
        ]
        
        _ = RenderEngine.shared.render(
            json: template,
            data: data,
            containerSize: CGSize(width: 375, height: 400)
        )
    }
    
    private var cachedView: UIView?
    private var updateCounter = 0
    
    private func performIncrementalUpdate() {
        let template: [String: Any] = [
            "type": "flex",
            "id": "update_root",
            "style": ["width": "100%", "height": 100, "flexDirection": "column"],
            "children": [
                [
                    "type": "text",
                    "id": "counter_text",
                    "style": ["width": "100%", "height": "auto", "fontSize": 24],
                    "props": ["text": "${count}"]
                ],
                [
                    "type": "text",
                    "id": "time_text",
                    "style": ["width": "100%", "height": "auto", "fontSize": 12],
                    "props": ["text": "${timestamp}"]
                ]
            ]
        ]
        
        let containerSize = CGSize(width: 375, height: 100)
        
        // 首次渲染或获取缓存
        if cachedView == nil {
            cachedView = RenderEngine.shared.render(
                json: template,
                data: ["count": 0, "timestamp": ""],
                containerSize: containerSize
            )
        }
        
        // 增量更新
        updateCounter += 1
        let data: [String: Any] = [
            "count": updateCounter,
            "timestamp": Date().description
        ]
        
        if let view = cachedView {
            RenderEngine.shared.update(view: view, data: data, containerSize: containerSize)
        }
    }
}
