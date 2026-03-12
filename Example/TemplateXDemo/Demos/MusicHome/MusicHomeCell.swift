import UIKit
import TemplateX

class MusicHomeCell: UICollectionViewCell {
    
    static let reuseIdentifier = "MusicHomeCell"
    
    // MARK: - Properties
    
    private var templateView: TemplateXView?
    private var currentTemplateId: String?
    private var skeletonOverlay: ShimmerView?
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    // MARK: - Configure
    
    func configure(
        template: [String: Any],
        templateId: String,
        data: [String: Any],
        containerWidth: CGFloat,
        precomputedHeight: CGFloat? = nil
    ) {
        hideSkeleton()
        
        let needsRebuild = templateView == nil || currentTemplateId != templateId
        
        let height = precomputedHeight ?? TemplateXRenderEngine.shared.calculateHeight(
            json: template,
            templateId: templateId,
            data: data,
            containerWidth: containerWidth,
            useCache: true
        )
        
        if needsRebuild {
            templateView?.removeFromSuperview()
            
            let newTemplateView = TemplateXView { builder in
                builder.config = TemplateXConfig { config in
                    config.enablePerformanceMonitor = false
                    config.enableSyncFlush = true
                }
                builder.screenSize = UIScreen.main.bounds.size
            }
            
            newTemplateView.preferredLayoutWidth = containerWidth
            newTemplateView.layoutWidthMode = .exact
            newTemplateView.layoutHeightMode = .wrapContent
            
            newTemplateView.frame = CGRect(x: 0, y: 0, width: containerWidth, height: max(height, 100))
            contentView.addSubview(newTemplateView)
            
            self.templateView = newTemplateView
            self.currentTemplateId = templateId
            
            newTemplateView.loadTemplate(json: template, data: data)
        } else {
            templateView?.updateDataFast(data)
            templateView?.frame = CGRect(x: 0, y: 0, width: containerWidth, height: max(height, 100))
        }
    }
    
    // MARK: - Skeleton
    
    func showSkeleton() {
        templateView?.isHidden = true
        
        if skeletonOverlay == nil {
            let overlay = ShimmerView()
            contentView.addSubview(overlay)
            skeletonOverlay = overlay
        }
        skeletonOverlay?.frame = contentView.bounds
        skeletonOverlay?.isHidden = false
        skeletonOverlay?.startAnimating()
    }
    
    func hideSkeleton() {
        skeletonOverlay?.stopAnimating()
        skeletonOverlay?.isHidden = true
        templateView?.isHidden = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        skeletonOverlay?.frame = contentView.bounds
    }
}

// MARK: - ShimmerView

private final class ShimmerView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        setupBlocks()
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupBlocks() {
        let shimmerColor = UIColor.systemGray5
        let configs: [(CGRect, CGFloat)] = [
            (CGRect(x: 16, y: 12, width: 120, height: 18), 4),
            (CGRect(x: 16, y: 46, width: 127, height: 127), 8),
            (CGRect(x: 153, y: 46, width: 127, height: 127), 8),
            (CGRect(x: 290, y: 46, width: 127, height: 127), 8),
            (CGRect(x: 16, y: 181, width: 100, height: 13), 3),
            (CGRect(x: 153, y: 181, width: 90, height: 13), 3),
            (CGRect(x: 290, y: 181, width: 110, height: 13), 3),
        ]
        for (rect, radius) in configs {
            let block = UIView(frame: rect)
            block.backgroundColor = shimmerColor
            block.layer.cornerRadius = radius
            addSubview(block)
        }
    }
    
    private func setupGradient() {
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations = [0, 0.5, 1]
        layer.addSublayer(gradientLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
    }
    
    func startAnimating() {
        gradientLayer.removeAnimation(forKey: "shimmer")
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 1.2
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(animation, forKey: "shimmer")
    }
    
    func stopAnimating() {
        gradientLayer.removeAnimation(forKey: "shimmer")
    }
}
