import UIKit
import TemplateX

/// 用于展示 TemplateX 模板的 UITableViewCell
class TemplateXDemoCell: UITableViewCell {
    
    static let reuseIdentifier = "TemplateXDemoCell"
    
    private var templateView: TemplateXView?
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 8
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        templateView?.removeFromSuperview()
        templateView = nil
    }
    
    // MARK: - Configure
    
    func configure(
        template: [String: Any],
        templateId: String,
        data: [String: Any]?,
        cellWidth: CGFloat
    ) {
        // 清理旧视图
        templateView?.removeFromSuperview()
        
        let contentWidth = cellWidth - horizontalPadding * 2
        
        // 计算高度
        let contentHeight = TemplateXRenderEngine.shared.calculateHeight(
            json: template,
            templateId: templateId,
            data: data,
            containerWidth: contentWidth,
            useCache: true
        )
        
        // 创建 TemplateXView
        let templateView = TemplateXView { builder in
            builder.config = TemplateXConfig { config in
                config.enablePerformanceMonitor = true
                config.enableSyncFlush = true
            }
            builder.screenSize = UIScreen.main.bounds.size
        }
        
        templateView.preferredLayoutWidth = contentWidth
        templateView.layoutWidthMode = .exact
        templateView.layoutHeightMode = .wrapContent
        
        templateView.frame = CGRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: contentWidth,
            height: contentHeight
        )
        
        contentView.addSubview(templateView)
        self.templateView = templateView
        
        // 加载模板
        if let data = data {
            templateView.loadTemplate(json: template, data: data)
        } else {
            templateView.loadTemplate(json: template)
        }
    }
    
    // MARK: - Height Calculation
    
    static func calculateHeight(
        template: [String: Any],
        templateId: String,
        data: [String: Any]?,
        containerWidth: CGFloat
    ) -> CGFloat {
        let contentWidth = containerWidth - 32  // 左右各 16pt padding
        
        let height = TemplateXRenderEngine.shared.calculateHeight(
            json: template,
            templateId: templateId,
            data: data,
            containerWidth: contentWidth,
            useCache: true
        )
        
        return height + 16  // 上下各 8pt padding
    }
}
