import Foundation
import CoreGraphics

// MARK: - PrefetchItemInfo

/// 预加载项信息
struct PrefetchItemInfo {
    /// Cell 位置（index）
    let position: Int
    
    /// 距离视口的距离（用于优先级计算）
    /// 距离越小，优先级越高
    let distance: CGFloat
}

// MARK: - PrefetchRegistry

/// 预加载位置收集器
/// 收集即将进入屏幕的 Cell 位置
/// 对应 Lynx: clay/ui/component/list/base_list_view.h:44 LayoutPrefetchRegistry
final class PrefetchRegistry {
    
    /// 预加载项信息 [position -> info]
    private(set) var prefetchItemInfos: [Int: PrefetchItemInfo] = [:]
    
    /// 添加预加载位置
    /// 对应 Lynx: AddPosition()
    func addPosition(_ position: Int, distance: CGFloat) {
        // 如果已存在，取距离更小的
        if let existing = prefetchItemInfos[position] {
            if distance < existing.distance {
                prefetchItemInfos[position] = PrefetchItemInfo(position: position, distance: distance)
            }
        } else {
            prefetchItemInfos[position] = PrefetchItemInfo(position: position, distance: distance)
        }
    }
    
    /// 清空预加载位置
    func clearPrefetchPositions() {
        prefetchItemInfos.removeAll()
    }
    
    /// 获取排序后的预加载位置（按距离排序）
    func getSortedPositions() -> [PrefetchItemInfo] {
        return prefetchItemInfos.values.sorted { $0.distance < $1.distance }
    }
    
    /// 是否为空
    var isEmpty: Bool {
        prefetchItemInfos.isEmpty
    }
    
    /// 位置数量
    var count: Int {
        prefetchItemInfos.count
    }
}

// MARK: - LinearLayoutPrefetchHelper

/// 线性布局预加载辅助器
/// 根据滚动方向收集即将进入屏幕的 Cell 位置
/// 对应 Lynx: list_layout_manager_linear.cc:1058 CollectPrefetchPositionsForScrolling
struct LinearLayoutPrefetchHelper {
    
    /// 预加载缓冲区大小（提前加载几个 Cell）
    var prefetchBufferCount: Int = 3
    
    /// 收集预加载位置
    /// - Parameters:
    ///   - registry: 预加载注册器
    ///   - visibleRange: 当前可见的 Cell 范围
    ///   - totalCount: Cell 总数
    ///   - scrollDirection: 滚动方向 (正值向下/右，负值向上/左)
    ///   - averageItemSize: 平均 Cell 尺寸（用于计算距离）
    func collectPrefetchPositions(
        into registry: PrefetchRegistry,
        visibleRange: Range<Int>,
        totalCount: Int,
        scrollDirection: CGFloat,
        averageItemSize: CGFloat
    ) {
        registry.clearPrefetchPositions()
        
        guard !visibleRange.isEmpty else { return }
        
        if scrollDirection > 0 {
            // 向下/向右滚动 → 预加载后面的 Cell
            let startPosition = visibleRange.upperBound
            let endPosition = min(startPosition + prefetchBufferCount, totalCount)
            
            for position in startPosition..<endPosition {
                let distance = CGFloat(position - visibleRange.upperBound + 1) * averageItemSize
                registry.addPosition(position, distance: distance)
            }
        } else if scrollDirection < 0 {
            // 向上/向左滚动 → 预加载前面的 Cell
            let startPosition = max(visibleRange.lowerBound - prefetchBufferCount, 0)
            let endPosition = visibleRange.lowerBound
            
            for position in startPosition..<endPosition {
                let distance = CGFloat(visibleRange.lowerBound - position) * averageItemSize
                registry.addPosition(position, distance: distance)
            }
        }
    }
}
