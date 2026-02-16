import UIKit
import TemplateX

/// 增量更新演示
class IncrementalUpdateDemoViewController: UIViewController {
    
    private var containerView: UIView!
    private var renderedView: UIView?
    private var logTextView: UITextView!
    
    private var counter = 0
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupUI()
        renderTemplate()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    private func setupUI() {
        // 容器视图
        containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // 控制按钮
        let startButton = UIButton(type: .system)
        startButton.setTitle("开始自动更新", for: .normal)
        startButton.addTarget(self, action: #selector(startAutoUpdate), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startButton)
        
        let stopButton = UIButton(type: .system)
        stopButton.setTitle("停止", for: .normal)
        stopButton.addTarget(self, action: #selector(stopAutoUpdate), for: .touchUpInside)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stopButton)
        
        // 日志视图
        logTextView = UITextView()
        logTextView.isEditable = false
        logTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.backgroundColor = .secondarySystemBackground
        logTextView.layer.cornerRadius = 8
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            containerView.heightAnchor.constraint(equalToConstant: 150),
            
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            startButton.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 16),
            
            stopButton.leadingAnchor.constraint(equalTo: startButton.trailingAnchor, constant: 20),
            stopButton.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
            
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logTextView.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 16),
            logTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    private func renderTemplate() {
        // 统一 style 格式
        let template: [String: Any] = [
            "type": "flex",
            "id": "counter_card",
            "style": [
                "width": "100%",
                "height": "100%",
                "flexDirection": "column",
                "justifyContent": "center",
                "alignItems": "center",
                "padding": 16,
                "backgroundColor": "#FFFFFF"
            ],
            "children": [
                [
                    "type": "text",
                    "id": "counter_label",
                    "style": [
                        "width": "auto",
                        "height": "auto",
                        "fontSize": 14,
                        "textColor": "#666666"
                    ],
                    "props": [
                        "text": "计数器"
                    ]
                ],
                [
                    "type": "text",
                    "id": "counter_value",
                    "style": [
                        "width": "auto",
                        "height": "auto",
                        "marginTop": 8,
                        "fontSize": 48,
                        "fontWeight": "bold",
                        "textColor": "#007AFF"
                    ],
                    "props": [
                        "text": "${count}"
                    ]
                ],
                [
                    "type": "text",
                    "id": "update_time",
                    "style": [
                        "width": "auto",
                        "height": "auto",
                        "marginTop": 8,
                        "fontSize": 12,
                        "textColor": "#999999"
                    ],
                    "props": [
                        "text": "${'更新时间: ' + timestamp}"
                    ]
                ]
            ]
        ]
        
        let containerSize = CGSize(
            width: UIScreen.main.bounds.width - 32,
            height: 150
        )
        
        let data: [String: Any] = [
            "count": counter,
            "timestamp": currentTimestamp()
        ]
        
        renderedView = RenderEngine.shared.render(
            json: template,
            data: data,
            containerSize: containerSize
        )
        
        if let view = renderedView {
            containerView.addSubview(view)
        }
        
        appendLog("初始渲染完成")
    }
    
    @objc private func startAutoUpdate() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.performUpdate()
        }
        appendLog("开始自动更新 (500ms 间隔)")
    }
    
    @objc private func stopAutoUpdate() {
        timer?.invalidate()
        timer = nil
        appendLog("停止自动更新")
    }
    
    private func performUpdate() {
        counter += 1
        
        let data: [String: Any] = [
            "count": counter,
            "timestamp": currentTimestamp()
        ]
        
        guard let view = renderedView else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let containerSize = CGSize(
            width: UIScreen.main.bounds.width - 32,
            height: 150
        )
        
        let operationCount = RenderEngine.shared.update(
            view: view,
            data: data,
            containerSize: containerSize
        )
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        appendLog(String(format: "更新 #%d: %d 操作, %.2fms", counter, operationCount, duration))
    }
    
    private func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    private func appendLog(_ message: String) {
        let timestamp = currentTimestamp()
        let logLine = "[\(timestamp)] \(message)\n"
        logTextView.text = logLine + (logTextView.text ?? "")
        
        // 限制日志长度
        if logTextView.text.count > 5000 {
            logTextView.text = String(logTextView.text.prefix(3000))
        }
    }
}
