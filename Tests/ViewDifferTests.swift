import XCTest
@testable import TemplateX

final class ViewDifferTests: XCTestCase {
    
    var differ: ViewDiffer!
    
    override func setUp() {
        super.setUp()
        differ = ViewDiffer.shared
    }
    
    // MARK: - 基础测试
    
    func testNilTrees() {
        let result = differ.diff(oldTree: nil, newTree: nil)
        XCTAssertFalse(result.hasDiff)
        XCTAssertEqual(result.operationCount, 0)
    }
    
    func testNewTreeInsert() {
        let newComponent = createComponent(id: "root", type: "view")
        
        let result = differ.diff(oldTree: nil, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        XCTAssertEqual(result.operationCount, 1)
        
        if case .insert(let component, let index, let parentId) = result.operations[0] {
            XCTAssertEqual(component.id, "root")
            XCTAssertEqual(index, 0)
            XCTAssertEqual(parentId, "root")
        } else {
            XCTFail("Expected insert operation")
        }
    }
    
    func testOldTreeDelete() {
        let oldComponent = createComponent(id: "root", type: "view")
        
        let result = differ.diff(oldTree: oldComponent, newTree: nil)
        
        XCTAssertTrue(result.hasDiff)
        XCTAssertEqual(result.operationCount, 1)
        
        if case .delete(let componentId, let parentId) = result.operations[0] {
            XCTAssertEqual(componentId, "root")
            XCTAssertEqual(parentId, "root")
        } else {
            XCTFail("Expected delete operation")
        }
    }
    
    // MARK: - 类型变化测试
    
    func testTypeChange() {
        let oldComponent = createComponent(id: "node1", type: "view")
        let newComponent = createComponent(id: "node1", type: "text")
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        
        // 应该有一个 replace 操作
        let replaceOps = result.operations.filter {
            if case .replace = $0 { return true }
            return false
        }
        XCTAssertEqual(replaceOps.count, 1)
    }
    
    // MARK: - 属性变化测试
    
    func testStyleWidthChange() {
        let oldComponent = createComponent(id: "node1", type: "view")
        oldComponent.style.width = .fixed(100)
        
        let newComponent = createComponent(id: "node1", type: "view")
        newComponent.style.width = .fixed(200)
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        
        if case .update(let componentId, let changes) = result.operations[0] {
            XCTAssertEqual(componentId, "node1")
            XCTAssertNotNil(changes.styleChanges)
        } else {
            XCTFail("Expected update operation")
        }
    }
    
    func testStyleCornerRadiusChange() {
        let oldComponent = createComponent(id: "node1", type: "view")
        oldComponent.style.cornerRadius = 0
        
        let newComponent = createComponent(id: "node1", type: "view")
        newComponent.style.cornerRadius = 10
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        
        if case .update(_, let changes) = result.operations[0] {
            XCTAssertNotNil(changes.styleChanges)
        } else {
            XCTFail("Expected update operation")
        }
    }
    
    func testBindingChange() {
        let oldComponent = createComponent(id: "node1", type: "text")
        oldComponent.bindings["text"] = "Hello"
        
        let newComponent = createComponent(id: "node1", type: "text")
        newComponent.bindings["text"] = "World"
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        
        if case .update(_, let changes) = result.operations[0] {
            XCTAssertNotNil(changes.bindingChanges)
            XCTAssertEqual(changes.bindingChanges?["text"] as? String, "World")
        } else {
            XCTFail("Expected update operation")
        }
    }
    
    // MARK: - 子节点变化测试
    
    func testChildInsert() {
        let oldComponent = createComponent(id: "root", type: "view")
        
        let newComponent = createComponent(id: "root", type: "view")
        let child = createComponent(id: "child1", type: "text")
        newComponent.addChild(child)
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        XCTAssertEqual(result.statistics.insertCount, 1)
    }
    
    func testChildDelete() {
        let oldComponent = createComponent(id: "root", type: "view")
        let child = createComponent(id: "child1", type: "text")
        oldComponent.addChild(child)
        
        let newComponent = createComponent(id: "root", type: "view")
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        XCTAssertEqual(result.statistics.deleteCount, 1)
    }
    
    func testChildReorder() {
        let oldComponent = createComponent(id: "root", type: "view")
        let child1 = createComponent(id: "child1", type: "text")
        child1.bindings["key"] = "a"
        let child2 = createComponent(id: "child2", type: "text")
        child2.bindings["key"] = "b"
        oldComponent.addChild(child1)
        oldComponent.addChild(child2)
        
        let newComponent = createComponent(id: "root", type: "view")
        let newChild1 = createComponent(id: "child1", type: "text")
        newChild1.bindings["key"] = "b"
        let newChild2 = createComponent(id: "child2", type: "text")
        newChild2.bindings["key"] = "a"
        newComponent.addChild(newChild1)
        newComponent.addChild(newChild2)
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        // 应该检测到移动操作
        XCTAssertGreaterThan(result.statistics.moveCount + result.statistics.updateCount, 0)
    }
    
    // MARK: - 复杂场景测试
    
    func testDeepTreeDiff() {
        // 创建三层深的树
        let oldRoot = createComponent(id: "root", type: "view")
        let oldLevel1 = createComponent(id: "l1", type: "view")
        let oldLevel2 = createComponent(id: "l2", type: "text")
        oldLevel2.bindings["text"] = "Old Text"
        oldRoot.addChild(oldLevel1)
        oldLevel1.addChild(oldLevel2)
        
        let newRoot = createComponent(id: "root", type: "view")
        let newLevel1 = createComponent(id: "l1", type: "view")
        let newLevel2 = createComponent(id: "l2", type: "text")
        newLevel2.bindings["text"] = "New Text"
        newRoot.addChild(newLevel1)
        newLevel1.addChild(newLevel2)
        
        let result = differ.diff(oldTree: oldRoot, newTree: newRoot)
        
        XCTAssertTrue(result.hasDiff)
        XCTAssertEqual(result.statistics.updateCount, 1)
    }
    
    func testNoChange() {
        let oldComponent = createComponent(id: "root", type: "view")
        oldComponent.style.width = .fixed(100)
        oldComponent.style.cornerRadius = 10
        
        let newComponent = createComponent(id: "root", type: "view")
        newComponent.style.width = .fixed(100)
        newComponent.style.cornerRadius = 10
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertFalse(result.hasDiff)
    }
    
    // MARK: - Display & Visibility 测试
    
    func testDisplayChange() {
        let oldComponent = createComponent(id: "node1", type: "view")
        oldComponent.style.display = .flex
        
        let newComponent = createComponent(id: "node1", type: "view")
        newComponent.style.display = .none
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
        
        if case .update(_, let changes) = result.operations[0] {
            XCTAssertNotNil(changes.styleChanges)
        } else {
            XCTFail("Expected update operation")
        }
    }
    
    func testVisibilityChange() {
        let oldComponent = createComponent(id: "node1", type: "view")
        oldComponent.style.visibility = .visible
        
        let newComponent = createComponent(id: "node1", type: "view")
        newComponent.style.visibility = .hidden
        
        let result = differ.diff(oldTree: oldComponent, newTree: newComponent)
        
        XCTAssertTrue(result.hasDiff)
    }
    
    // MARK: - 性能测试
    
    func testLargeListDiff() {
        // 创建包含100个子节点的列表
        let oldRoot = createComponent(id: "root", type: "view")
        for i in 0..<100 {
            let child = createComponent(id: "item_\(i)", type: "text")
            child.bindings["key"] = "key_\(i)"
            child.bindings["text"] = "Item \(i)"
            oldRoot.addChild(child)
        }
        
        // 新列表：修改第50个，删除第60个，在末尾添加一个
        let newRoot = createComponent(id: "root", type: "view")
        for i in 0..<100 {
            if i == 60 { continue }  // 删除
            
            let child = createComponent(id: "item_\(i)", type: "text")
            child.bindings["key"] = "key_\(i)"
            
            if i == 50 {
                child.bindings["text"] = "Modified Item 50"  // 修改
            } else {
                child.bindings["text"] = "Item \(i)"
            }
            newRoot.addChild(child)
        }
        // 添加新节点
        let newChild = createComponent(id: "item_100", type: "text")
        newChild.bindings["key"] = "key_100"
        newChild.bindings["text"] = "Item 100"
        newRoot.addChild(newChild)
        
        measure {
            _ = differ.diff(oldTree: oldRoot, newTree: newRoot)
        }
    }
    
    // MARK: - Helper
    
    private func createComponent(id: String, type: String) -> BaseComponent {
        return BaseComponent(id: id, type: type)
    }
}

// MARK: - ComponentSnapshot Tests

final class ComponentSnapshotTests: XCTestCase {
    
    func testSnapshotCreation() {
        let component = BaseComponent(id: "test", type: "view")
        component.style.width = .fixed(100)
        component.bindings["key"] = "myKey"
        
        let snapshot = ComponentSnapshot(from: component)
        
        XCTAssertEqual(snapshot.id, "test")
        XCTAssertEqual(snapshot.type, "view")
        XCTAssertEqual(snapshot.key, "myKey")
    }
    
    func testSnapshotMatching() {
        let component1 = BaseComponent(id: "test", type: "view")
        component1.bindings["key"] = "key1"
        
        let component2 = BaseComponent(id: "test", type: "view")
        component2.bindings["key"] = "key1"
        
        let snapshot1 = ComponentSnapshot(from: component1)
        let snapshot2 = ComponentSnapshot(from: component2)
        
        XCTAssertTrue(snapshot1.canMatch(snapshot2))
    }
    
    func testSnapshotContentEquals() {
        let component1 = BaseComponent(id: "test", type: "view")
        component1.style.width = .fixed(100)
        
        let component2 = BaseComponent(id: "test", type: "view")
        component2.style.width = .fixed(100)
        
        let snapshot1 = ComponentSnapshot(from: component1)
        let snapshot2 = ComponentSnapshot(from: component2)
        
        XCTAssertTrue(snapshot1.contentEquals(snapshot2))
    }
    
    func testSnapshotContentNotEquals() {
        let component1 = BaseComponent(id: "test", type: "view")
        component1.style.width = .fixed(100)
        
        let component2 = BaseComponent(id: "test", type: "view")
        component2.style.width = .fixed(200)
        
        let snapshot1 = ComponentSnapshot(from: component1)
        let snapshot2 = ComponentSnapshot(from: component2)
        
        XCTAssertFalse(snapshot1.contentEquals(snapshot2))
    }
}

// MARK: - DiffResult Tests

final class DiffResultTests: XCTestCase {
    
    func testEmptyResult() {
        let result = DiffResult()
        
        XCTAssertFalse(result.hasDiff)
        XCTAssertEqual(result.operationCount, 0)
    }
    
    func testAddOperations() {
        var result = DiffResult()
        let component = BaseComponent(id: "test", type: "view")
        
        result.addInsert(component, at: 0, parentId: "root")
        result.addDelete("old", parentId: "root")
        result.addUpdate("node1", changes: PropertyChanges())
        
        XCTAssertTrue(result.hasDiff)
        XCTAssertEqual(result.operationCount, 3)
    }
    
    func testStatistics() {
        var result = DiffResult()
        let component = BaseComponent(id: "test", type: "view")
        
        result.addInsert(component, at: 0, parentId: "root")
        result.addInsert(component, at: 1, parentId: "root")
        result.addDelete("old", parentId: "root")
        result.addUpdate("node1", changes: PropertyChanges())
        result.addMove("node2", from: 0, to: 2, parentId: "root")
        
        let stats = result.statistics
        
        XCTAssertEqual(stats.insertCount, 2)
        XCTAssertEqual(stats.deleteCount, 1)
        XCTAssertEqual(stats.updateCount, 1)
        XCTAssertEqual(stats.moveCount, 1)
        XCTAssertEqual(stats.totalCount, 5)
    }
    
    func testMerge() {
        var result1 = DiffResult()
        result1.addInsert(BaseComponent(id: "a", type: "view"), at: 0, parentId: "root")
        
        var result2 = DiffResult()
        result2.addDelete("b", parentId: "root")
        
        result1.merge(result2)
        
        XCTAssertEqual(result1.operationCount, 2)
    }
}
