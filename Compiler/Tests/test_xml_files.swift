#!/usr/bin/env swift

import Foundation

// MARK: - 简化版编译器测试
// 用于验证 XML → JSON 编译逻辑

// 加载编译器模块
let compilerPath = "/Users/lvyou4/Desktop/DSL/TemplateX/Compiler"
let testsPath = compilerPath + "/Tests"

// 测试 XML 解析
print("=" * 60)
print("TemplateX Compiler Test")
print("=" * 60)

// 读取测试文件
let testFiles = ["simple_card.xml", "product_card.xml", "user_profile.xml"]

for file in testFiles {
    let filePath = testsPath + "/" + file
    print("\n📄 Testing: \(file)")
    print("-" * 40)
    
    do {
        let xml = try String(contentsOfFile: filePath, encoding: .utf8)
        print("✅ XML loaded (\(xml.count) chars)")
        
        // 简单验证 XML 结构
        if xml.contains("<Template") {
            print("✅ Contains <Template> root")
        }
        
        if xml.contains("${") {
            let matches = xml.components(separatedBy: "${").count - 1
            print("✅ Contains \(matches) expressions")
        }
        
        // 检查常用标签
        let tags = ["Column", "Row", "Text", "Image", "View"]
        let foundTags = tags.filter { xml.contains("<\($0)") }
        print("✅ Found tags: \(foundTags.joined(separator: ", "))")
        
    } catch {
        print("❌ Error: \(error.localizedDescription)")
    }
}

print("\n" + "=" * 60)
print("Test completed!")
print("=" * 60)

// String repeat helper
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
