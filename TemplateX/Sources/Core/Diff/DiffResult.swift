import UIKit

// MARK: - Diff 操作类型

/// Diff 操作类型
public enum DiffOperation {
    /// 插入新组件
    case insert(component: Component, index: Int, parentId: String)
    
    /// 删除组件
    case delete(componentId: String, parentId: String)
    
    /// 更新组件（属性变化）
    /// - componentId: 旧组件的 ID（用于在 componentIndex 中查找）
    /// - newComponent: 新组件（包含更新后的属性值）
    /// - changes: 属性变化描述
    case update(componentId: String, newComponent: Component, changes: PropertyChanges)
    
    /// 移动组件（位置变化）
    case move(componentId: String, fromIndex: Int, toIndex: Int, parentId: String)
    
    /// 替换组件（类型变化）
    case replace(oldComponentId: String, newComponent: Component, parentId: String)
}

// MARK: - 属性变化

/// 属性变化集合
public struct PropertyChanges {
    /// 样式变化（包含布局、视觉、文本样式）
    public var styleChanges: ComponentStyle?
    
    /// 绑定数据变化
    public var bindingChanges: [String: Any]?
    
    /// 是否有变化
    public var hasChanges: Bool {
        return styleChanges != nil || bindingChanges != nil
    }
    
    /// 是否需要重新布局
    public var needsRelayout: Bool {
        // 有样式变化就检查是否影响布局
        return styleChanges != nil
    }
    
    public init(
        styleChanges: ComponentStyle? = nil,
        bindingChanges: [String: Any]? = nil
    ) {
        self.styleChanges = styleChanges
        self.bindingChanges = bindingChanges
    }
}

// MARK: - Diff 结果

/// Diff 算法结果
public struct DiffResult {
    /// 所有操作列表（按执行顺序排列）
    public private(set) var operations: [DiffOperation] = []
    
    /// 是否有差异
    public var hasDiff: Bool {
        return !operations.isEmpty
    }
    
    /// 操作数量
    public var operationCount: Int {
        return operations.count
    }
    
    /// 统计信息
    public var statistics: DiffStatistics {
        var stats = DiffStatistics()
        for op in operations {
            switch op {
            case .insert: stats.insertCount += 1
            case .delete: stats.deleteCount += 1
            case .update: stats.updateCount += 1
            case .move: stats.moveCount += 1
            case .replace: stats.replaceCount += 1
            }
        }
        return stats
    }
    
    public init() {}
    
    // MARK: - 添加操作
    
    public mutating func addInsert(_ component: Component, at index: Int, parentId: String) {
        operations.append(.insert(component: component, index: index, parentId: parentId))
    }
    
    public mutating func addDelete(_ componentId: String, parentId: String) {
        operations.append(.delete(componentId: componentId, parentId: parentId))
    }
    
    public mutating func addUpdate(_ componentId: String, newComponent: Component, changes: PropertyChanges) {
        operations.append(.update(componentId: componentId, newComponent: newComponent, changes: changes))
    }
    
    public mutating func addMove(_ componentId: String, from: Int, to: Int, parentId: String) {
        operations.append(.move(componentId: componentId, fromIndex: from, toIndex: to, parentId: parentId))
    }
    
    public mutating func addReplace(old componentId: String, new component: Component, parentId: String) {
        operations.append(.replace(oldComponentId: componentId, newComponent: component, parentId: parentId))
    }
    
    // MARK: - 合并结果
    
    public mutating func merge(_ other: DiffResult) {
        operations.append(contentsOf: other.operations)
    }
}

// MARK: - Diff 统计

/// Diff 统计信息
public struct DiffStatistics {
    public var insertCount: Int = 0
    public var deleteCount: Int = 0
    public var updateCount: Int = 0
    public var moveCount: Int = 0
    public var replaceCount: Int = 0
    
    public var totalCount: Int {
        return insertCount + deleteCount + updateCount + moveCount + replaceCount
    }
    
    public var description: String {
        return "DiffStats(insert: \(insertCount), delete: \(deleteCount), update: \(updateCount), move: \(moveCount), replace: \(replaceCount))"
    }
}

// MARK: - 组件快照

/// 组件快照，用于 Diff 比较
/// 轻量级结构，只存储用于比较的关键信息
public struct ComponentSnapshot: Hashable {
    public let id: String
    public let type: String
    public let key: String?  // 用户指定的 key，用于列表优化
    
    // 样式的 hash（包含布局、视觉、文本样式）
    public let styleHash: Int
    
    // 绑定数据的 hash
    public let bindingsHash: Int
    
    // 组件特有属性的 hash（如 TextComponent.text、ImageComponent.src 等）
    public let componentPropsHash: Int
    
    public init(from component: Component) {
        self.id = component.id
        self.type = component.type
        self.key = component.bindings["key"] as? String
        
        // 计算各部分 hash
        self.styleHash = Self.hashStyle(component.style)
        self.bindingsHash = Self.hashBindings(component.bindings)
        self.componentPropsHash = Self.hashComponentProps(component)
    }
    
    /// 判断是否可能是同一个组件（用于匹配）
    public func canMatch(_ other: ComponentSnapshot) -> Bool {
        // 优先使用 key 匹配
        if let key1 = key, let key2 = other.key {
            return key1 == key2 && type == other.type
        }
        // 否则使用 id 匹配
        return id == other.id && type == other.type
    }
    
    /// 判断内容是否相同
    public func contentEquals(_ other: ComponentSnapshot) -> Bool {
        return styleHash == other.styleHash &&
               bindingsHash == other.bindingsHash &&
               componentPropsHash == other.componentPropsHash
    }
    
    // MARK: - Private
    
    private static func hashStyle(_ style: ComponentStyle) -> Int {
        var hasher = Hasher()
        
        // 布局属性
        hasher.combine(String(describing: style.width))
        hasher.combine(String(describing: style.height))
        hasher.combine(style.minWidth)
        hasher.combine(style.minHeight)
        hasher.combine(style.maxWidth)
        hasher.combine(style.maxHeight)
        hasher.combine(String(describing: style.margin))
        hasher.combine(String(describing: style.padding))
        hasher.combine(style.flexGrow)
        hasher.combine(style.flexShrink)
        hasher.combine(style.flexDirection.rawValue)
        hasher.combine(style.flexWrap.rawValue)
        hasher.combine(style.justifyContent.rawValue)
        hasher.combine(style.alignItems.rawValue)
        hasher.combine(style.alignSelf.rawValue)
        hasher.combine(style.positionType.rawValue)
        hasher.combine(style.display.rawValue)
        hasher.combine(style.visibility.rawValue)
        
        // 视觉属性
        hasher.combine(String(describing: style.backgroundColor))
        hasher.combine(style.borderWidth)
        hasher.combine(String(describing: style.borderColor))
        hasher.combine(style.cornerRadius)
        hasher.combine(String(describing: style.shadowColor))
        hasher.combine(style.shadowOffset.width)
        hasher.combine(style.shadowOffset.height)
        hasher.combine(style.shadowRadius)
        hasher.combine(style.shadowOpacity)
        hasher.combine(style.opacity)
        hasher.combine(style.clipsToBounds)
        
        // 文本属性
        hasher.combine(style.fontSize)
        hasher.combine(style.fontWeight)
        hasher.combine(String(describing: style.textColor))
        hasher.combine(style.textAlign?.rawValue)
        hasher.combine(style.lineHeight)
        hasher.combine(style.letterSpacing)
        hasher.combine(style.numberOfLines)
        
        return hasher.finalize()
    }
    
    private static func hashBindings(_ bindings: [String: Any]) -> Int {
        var hasher = Hasher()
        for key in bindings.keys.sorted() {
            hasher.combine(key)
            if let value = bindings[key] {
                hasher.combine(String(describing: value))
            }
        }
        return hasher.finalize()
    }
    
    /// 计算组件特有属性的 hash
    /// 用于检测 TextComponent.text、ImageComponent.src 等属性的变化
    private static func hashComponentProps(_ component: Component) -> Int {
        var hasher = Hasher()
        
        // TextComponent
        if let textComponent = component as? TextComponent {
            hasher.combine(textComponent.text)
            hasher.combine(textComponent.fontSize)
            hasher.combine(textComponent.fontWeight.rawValue)
            hasher.combine(String(describing: textComponent.textColor))
            hasher.combine(textComponent.textAlignment.rawValue)
            hasher.combine(textComponent.numberOfLines)
            hasher.combine(textComponent.lineHeight)
            hasher.combine(textComponent.letterSpacing)
            return hasher.finalize()
        }
        
        // ImageComponent
        if let imageComponent = component as? ImageComponent {
            hasher.combine(imageComponent.src)
            hasher.combine(imageComponent.scaleType.rawValue)
            hasher.combine(imageComponent.placeholder)
            return hasher.finalize()
        }
        
        // ButtonComponent
        if let buttonComponent = component as? ButtonComponent {
            hasher.combine(buttonComponent.title)
            hasher.combine(buttonComponent.isDisabled)
            hasher.combine(buttonComponent.isLoading)
            return hasher.finalize()
        }
        
        // InputComponent
        if let inputComponent = component as? InputComponent {
            hasher.combine(inputComponent.text)
            hasher.combine(inputComponent.placeholder)
            hasher.combine(inputComponent.inputType.rawValue)
            hasher.combine(inputComponent.isDisabled)
            return hasher.finalize()
        }
        
        // 其他组件返回 0
        return 0
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(key)
    }
    
    public static func == (lhs: ComponentSnapshot, rhs: ComponentSnapshot) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type && lhs.key == rhs.key
    }
}
