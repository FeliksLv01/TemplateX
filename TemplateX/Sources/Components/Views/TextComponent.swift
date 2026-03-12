import UIKit

// MARK: - Text 组件

/// 文本组件
///
/// Props 只包含内容属性，文本样式统一从 style 读取：
/// - style.fontSize, style.fontWeight, style.textColor
/// - style.textAlign, style.numberOfLines, style.lineHeight, style.letterSpacing
final class TextComponent: TemplateXComponent<UILabel, TextComponent.Props> {
    
    // MARK: - Props
    
    struct Props: ComponentProps {
        /// 文本内容
        var text: String = ""
    }
    
    // MARK: - Type Identifier
    
    override class var typeIdentifier: String { "text" }
    
    // MARK: - 缓存（性能优化）
    
    private var _cachedFont: UIFont?
    private var _cachedFontSize: CGFloat = 0
    private var _cachedFontWeight: UIFont.Weight = .regular
    private var _previousText: String?
    private var _previousStyle: ComponentStyle?
    
    private var _cachedAttributedString: NSAttributedString?
    private var _attrCacheText: String?
    private var _attrCacheLineHeight: CGFloat?
    private var _attrCacheLetterSpacing: CGFloat?
    private var _attrCacheFont: UIFont?
    private var _attrCacheColor: UIColor?
    private var _attrCacheAlignment: NSTextAlignment?
    
    // MARK: - View Lifecycle
    
    override func createView() -> UIView {
        let label = UILabel()
        label.backgroundColor = .clear
        return label
    }
    
    override func configureView(_ view: UILabel) {
        // 脏检查：只在内容或样式变化时更新
        let textChanged = _previousText != props.text
        let styleChanged = forceApplyStyle || _previousStyle != style
        
        guard textChanged || styleChanged else { return }
        
        _previousText = props.text
        _previousStyle = style
        
        // 基础属性
        view.text = props.text
        view.numberOfLines = style.numberOfLines ?? 0
        view.lineBreakMode = style.lineBreakMode ?? .byTruncatingTail
        
        // 颜色
        view.textColor = style.textColor ?? .black
        
        // 对齐
        view.textAlignment = style.textAlign?.toNSTextAlignment() ?? .left
        
        // 字体
        view.font = getFont()
        
        // 富文本属性（行高/字间距）
        if style.lineHeight != nil || style.letterSpacing != nil {
            applyAttributedText(to: view)
        }
    }
    
    // MARK: - Private
    
    private func getFont() -> UIFont {
        let size = style.fontSize ?? 14
        let weight = style.fontWeight.flatMap { FontWeightValue($0).weight } ?? .regular
        
        // 缓存优化
        if let cached = _cachedFont, _cachedFontSize == size, _cachedFontWeight == weight {
            return cached
        }
        
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        _cachedFont = font
        _cachedFontSize = size
        _cachedFontWeight = weight
        return font
    }
    
    private func applyAttributedText(to label: UILabel) {
        let font = getFont()
        let color = label.textColor ?? .black
        let alignment = label.textAlignment
        let lh = style.lineHeight
        let ls = style.letterSpacing
        
        if let cached = _cachedAttributedString,
           _attrCacheText == props.text,
           _attrCacheLineHeight == lh,
           _attrCacheLetterSpacing == ls,
           _attrCacheFont === font,
           _attrCacheColor == color,
           _attrCacheAlignment == alignment {
            label.attributedText = cached
            return
        }
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        if let lh = lh {
            let paragraphStyle = NSMutableParagraphStyle()
            let fontSize = style.fontSize ?? 14
            let actualLineHeight: CGFloat
            if lh <= 4 {
                actualLineHeight = fontSize * lh
            } else {
                actualLineHeight = lh
            }
            paragraphStyle.minimumLineHeight = actualLineHeight
            paragraphStyle.maximumLineHeight = actualLineHeight
            paragraphStyle.alignment = alignment
            attributes[.paragraphStyle] = paragraphStyle
        }
        
        if let ls = ls {
            attributes[.kern] = ls
        }
        
        let attrString = NSAttributedString(string: props.text, attributes: attributes)
        _cachedAttributedString = attrString
        _attrCacheText = props.text
        _attrCacheLineHeight = lh
        _attrCacheLetterSpacing = ls
        _attrCacheFont = font
        _attrCacheColor = color
        _attrCacheAlignment = alignment
        
        label.attributedText = attrString
    }
}
