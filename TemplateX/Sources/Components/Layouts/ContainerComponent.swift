import UIKit

// MARK: - Container 组件

/// 基础容器组件（Flexbox 容器）
/// 支持 flexDirection, justifyContent, alignItems 等属性
final class ContainerComponent: TemplateXComponent<UIView, EmptyProps> {
    
    override class var typeIdentifier: String { "container" }
}
