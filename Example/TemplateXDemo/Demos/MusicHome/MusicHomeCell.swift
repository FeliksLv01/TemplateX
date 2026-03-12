import UIKit
import TemplateX

/// 音乐首页 Cell - 包含 TemplateXView 渲染的模板
class MusicHomeCell: UICollectionViewCell {
    
    static let reuseIdentifier = "MusicHomeCell"
    
    // MARK: - Properties
    
    private var templateView: TemplateXView?
    private var currentTemplateId: String?
    
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
        // 不清理 templateView，复用时更新数据
    }
    
    // MARK: - Configure
    
    /// - Parameters:
    ///   - template: 模板 JSON
    ///   - templateId: 模板标识符
    ///   - data: 绑定数据
    ///   - containerWidth: 容器宽度
    ///   - precomputedHeight: 预计算高度（来自 sizeForItemAt，避免重复计算）
    func configure(
        template: [String: Any],
        templateId: String,
        data: [String: Any],
        containerWidth: CGFloat,
        precomputedHeight: CGFloat? = nil
    ) {
        // 检查是否需要重建 TemplateXView
        let needsRebuild = templateView == nil || currentTemplateId != templateId
        
        // 使用预计算高度或按需计算
        let height = precomputedHeight ?? TemplateXRenderEngine.shared.calculateHeight(
            json: template,
            templateId: templateId,
            data: data,
            containerWidth: containerWidth,
            useCache: true
        )
        
        if needsRebuild {
            // 清理旧视图
            templateView?.removeFromSuperview()
            
            // 创建新的 TemplateXView
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
            
            // 加载模板
            newTemplateView.loadTemplate(json: template, data: data)
        } else {
            // 复用现有视图，快速更新数据（跳过 clone + Diff）
            templateView?.updateDataFast(data)
            
            // 更新 frame
            templateView?.frame = CGRect(x: 0, y: 0, width: containerWidth, height: max(height, 100))
        }
    }
}
