import UIKit

/// FPS 监控标签（基于 YYFPSLabel）
/// 使用 CADisplayLink 计算帧率，显示在屏幕右上角
final class FPSLabel: UILabel {
    
    private var displayLink: CADisplayLink?
    private var lastTime: TimeInterval = 0
    private var frameCount: Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        layer.cornerRadius = 5
        layer.masksToBounds = true
        textAlignment = .center
        isUserInteractionEnabled = false
        backgroundColor = UIColor(white: 0, alpha: 0.7)
        font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        
        // 默认尺寸
        if frame.size == .zero {
            frame.size = CGSize(width: 55, height: 20)
        }
        
        // 创建 CADisplayLink
        displayLink = CADisplayLink(target: WeakProxy(target: self), selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    @objc private func tick(_ link: CADisplayLink) {
        guard lastTime != 0 else {
            lastTime = link.timestamp
            return
        }
        
        frameCount += 1
        let delta = link.timestamp - lastTime
        
        // 每秒更新一次
        if delta >= 1.0 {
            let fps = Double(frameCount) / delta
            frameCount = 0
            lastTime = link.timestamp
            
            // 更新显示
            let fpsInt = Int(round(fps))
            let color: UIColor
            
            if fps >= 55 {
                color = UIColor(red: 0.35, green: 0.85, blue: 0.35, alpha: 1) // 绿色
            } else if fps >= 45 {
                color = UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1) // 黄色
            } else {
                color = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1) // 红色
            }
            
            textColor = color
            text = "\(fpsInt) FPS"
        }
    }
}

// MARK: - WeakProxy（避免循环引用）

private class WeakProxy: NSObject {
    weak var target: FPSLabel?
    
    init(target: FPSLabel) {
        self.target = target
        super.init()
    }
    
    override func responds(to aSelector: Selector!) -> Bool {
        return target?.responds(to: aSelector) ?? false
    }
    
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return target
    }
}

// MARK: - 便捷方法

extension FPSLabel {
    
    /// 在 window 上显示 FPS 标签
    static func show(in window: UIWindow) -> FPSLabel {
        let label = FPSLabel()
        label.frame.origin = CGPoint(
            x: window.bounds.width - label.frame.width - 12,
            y: window.safeAreaInsets.top + 50
        )
        window.addSubview(label)
        return label
    }
}
