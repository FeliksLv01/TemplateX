import XCTest
@testable import TemplateX

final class XMLCompilerTests: XCTestCase {
    
    var compiler: XMLToJSONCompiler!
    
    override func setUp() {
        super.setUp()
        compiler = XMLToJSONCompiler()
    }
    
    // MARK: - 基础解析测试
    
    func testParseSimpleView() throws {
        let xml = """
        <View width="100dp" height="50dp" backgroundColor="#FF0000"/>
        """
        
        let json = try compiler.compile(xml)
        
        XCTAssertEqual(json["type"] as? String, "view")
        
        let props = json["props"] as? [String: Any]
        XCTAssertNotNil(props)
        XCTAssertEqual(props?["width"] as? Double, 100)
        XCTAssertEqual(props?["height"] as? Double, 50)
        XCTAssertEqual(props?["backgroundColor"] as? String, "#FF0000")
    }
    
    func testParseTemplate() throws {
        let xml = """
        <Template name="test_card" version="1.0">
            <View width="match_parent" height="wrap_content"/>
        </Template>
        """
        
        let json = try compiler.compile(xml)
        
        XCTAssertEqual(json["name"] as? String, "test_card")
        XCTAssertEqual(json["version"] as? String, "1.0")
        XCTAssertNotNil(json["root"])
    }
    
    // MARK: - 单位解析测试
    
    func testParseDimensions() throws {
        let xml = """
        <View width="match_parent" height="wrap_content" minWidth="50dp" maxHeight="100px"/>
        """
        
        let json = try compiler.compile(xml)
        let props = json["props"] as? [String: Any]
        
        XCTAssertEqual(props?["width"] as? Int, -1)  // match_parent
        XCTAssertEqual(props?["height"] as? Int, -2)  // wrap_content
        XCTAssertEqual(props?["minWidth"] as? Double, 50)
    }
    
    func testParseEdgeInsets() throws {
        let xml = """
        <View padding="16dp" margin="8dp 16dp"/>
        """
        
        let json = try compiler.compile(xml)
        let props = json["props"] as? [String: Any]
        
        let padding = props?["padding"] as? [Double]
        XCTAssertEqual(padding, [16, 16, 16, 16])
        
        let margin = props?["margin"] as? [Double]
        XCTAssertEqual(margin, [8, 16, 8, 16])
    }
    
    // MARK: - 颜色解析测试
    
    func testParseColors() {
        // 十六进制
        XCTAssertEqual(UnitParser.parseColor("#FFF"), "#FFFFFF")
        XCTAssertEqual(UnitParser.parseColor("#FF0000"), "#FF0000")
        XCTAssertEqual(UnitParser.parseColor("#80FF0000"), "#80FF0000")
        
        // rgb/rgba
        XCTAssertEqual(UnitParser.parseColor("rgb(255, 0, 0)"), "#FF0000")
        XCTAssertEqual(UnitParser.parseColor("rgba(255, 0, 0, 0.5)"), "#7FFF0000")
        
        // 颜色名称
        XCTAssertEqual(UnitParser.parseColor("red"), "#FF0000")
        XCTAssertEqual(UnitParser.parseColor("transparent"), "#00000000")
    }
    
    // MARK: - 表达式测试
    
    func testExpressionExtraction() {
        XCTAssertTrue(ExpressionExtractor.containsExpression("${data.title}"))
        XCTAssertFalse(ExpressionExtractor.containsExpression("Hello World"))
        
        XCTAssertTrue(ExpressionExtractor.isPureExpression("${data.title}"))
        XCTAssertFalse(ExpressionExtractor.isPureExpression("Hello ${name}"))
        
        XCTAssertEqual(
            ExpressionExtractor.extractPureExpression("${data.title}"),
            "data.title"
        )
    }
    
    func testMixedStringCompilation() {
        let result = ExpressionExtractor.compileMixedString("Hello, ${name}!")
        
        XCTAssertEqual(result?["type"] as? String, "template")
        
        let segments = result?["segments"] as? [[String: Any]]
        XCTAssertEqual(segments?.count, 3)
        
        XCTAssertEqual(segments?[0]["type"] as? String, "text")
        XCTAssertEqual(segments?[0]["value"] as? String, "Hello, ")
        
        XCTAssertEqual(segments?[1]["type"] as? String, "expr")
        XCTAssertEqual(segments?[1]["value"] as? String, "name")
        
        XCTAssertEqual(segments?[2]["type"] as? String, "text")
        XCTAssertEqual(segments?[2]["value"] as? String, "!")
    }
    
    func testDataBinding() throws {
        let xml = """
        <Text text="${data.title}" fontSize="16sp"/>
        """
        
        let json = try compiler.compile(xml)
        
        let bindings = json["bindings"] as? [String: Any]
        XCTAssertNotNil(bindings)
        XCTAssertNotNil(bindings?["text"])
    }
    
    // MARK: - For 循环测试
    
    func testForExpressionParsing() {
        // 简单格式
        let result1 = ExpressionExtractor.parseForExpression("item in items")
        XCTAssertEqual(result1?.itemName, "item")
        XCTAssertNil(result1?.indexName)
        XCTAssertEqual(result1?.itemsExpression, "items")
        
        // 带索引
        let result2 = ExpressionExtractor.parseForExpression("(item, index) in items")
        XCTAssertEqual(result2?.itemName, "item")
        XCTAssertEqual(result2?.indexName, "index")
        
        // 带 key
        let result3 = ExpressionExtractor.parseForExpression("item in items :key item.id")
        XCTAssertEqual(result3?.keyExpression, "item.id")
        
        // 表达式格式
        let result4 = ExpressionExtractor.parseForExpression("item in ${data.list}")
        XCTAssertEqual(result4?.itemsExpression, "data.list")
    }
    
    func testForEachCompilation() throws {
        let xml = """
        <ForEach items="${data.tags}" itemName="tag" indexName="i">
            <Text text="${tag.name}"/>
        </ForEach>
        """
        
        let json = try compiler.compile(xml)
        
        XCTAssertEqual(json["type"] as? String, "_for")
        XCTAssertEqual(json["items"] as? String, "data.tags")
        XCTAssertEqual(json["item"] as? String, "tag")
        XCTAssertEqual(json["index"] as? String, "i")
        
        let template = json["template"] as? [[String: Any]]
        XCTAssertEqual(template?.count, 1)
    }
    
    // MARK: - 条件渲染测试
    
    func testIfCompilation() throws {
        let xml = """
        <If condition="${data.show}">
            <Text text="Visible"/>
        </If>
        """
        
        let json = try compiler.compile(xml)
        
        XCTAssertEqual(json["type"] as? String, "_conditional")
        XCTAssertEqual(json["condition"] as? String, "data.show")
    }
    
    func testIfElseCompilation() throws {
        let xml = """
        <IfElse condition="${data.type == 'video'}">
            <Then>
                <View id="video"/>
            </Then>
            <Else>
                <View id="image"/>
            </Else>
        </IfElse>
        """
        
        let json = try compiler.compile(xml)
        
        XCTAssertEqual(json["type"] as? String, "_conditional")
        
        let thenBranch = json["then"] as? [[String: Any]]
        XCTAssertEqual(thenBranch?.first?["id"] as? String, "video")
        
        let elseBranch = json["else"] as? [[String: Any]]
        XCTAssertEqual(elseBranch?.first?["id"] as? String, "image")
    }
    
    // MARK: - 事件测试
    
    func testEventCompilation() throws {
        let xml = """
        <View onClick="handleClick" onLongPress="showMenu(data.id)"/>
        """
        
        let json = try compiler.compile(xml)
        let events = json["events"] as? [String: Any]
        
        XCTAssertNotNil(events)
        
        let tapEvent = events?["tap"] as? [String: Any]
        XCTAssertEqual(tapEvent?["method"] as? String, "handleClick")
        
        let longPressEvent = events?["longPress"] as? [String: Any]
        XCTAssertEqual(longPressEvent?["method"] as? String, "showMenu")
        XCTAssertEqual(longPressEvent?["args"] as? String, "data.id")
    }
    
    // MARK: - 子节点测试
    
    func testChildrenCompilation() throws {
        let xml = """
        <LinearLayout orientation="vertical">
            <Text text="Title"/>
            <Text text="Subtitle"/>
        </LinearLayout>
        """
        
        let json = try compiler.compile(xml)
        
        XCTAssertEqual(json["type"] as? String, "linear")
        
        let props = json["props"] as? [String: Any]
        XCTAssertEqual(props?["orientation"] as? Int, 1)  // vertical
        
        let children = json["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 2)
    }
    
    // MARK: - 枚举压缩测试
    
    func testEnumCompression() throws {
        compiler.options.compressEnums = true
        
        let xml = """
        <Text textAlign="center" fontWeight="bold" ellipsize="end"/>
        """
        
        let json = try compiler.compile(xml)
        let props = json["props"] as? [String: Any]
        
        XCTAssertEqual(props?["textAlign"] as? Int, 1)  // center
        XCTAssertEqual(props?["fontWeight"] as? Int, 700)  // bold
        XCTAssertEqual(props?["ellipsize"] as? Int, 2)  // end
    }
    
    // MARK: - 表达式池测试
    
    func testExpressionPool() throws {
        compiler.options.precompileExpressions = true
        
        let xml = """
        <Template name="test">
            <LinearLayout>
                <Text text="${data.title}"/>
                <Text text="${data.title}"/>
                <Text text="${data.subtitle}"/>
            </LinearLayout>
        </Template>
        """
        
        let json = try compiler.compile(xml)
        
        let expressions = json["expressions"] as? [String: Any]
        XCTAssertNotNil(expressions)
        XCTAssertEqual(expressions?["precompiled"] as? Bool, true)
        
        let pool = expressions?["pool"] as? [[String: Any]]
        // 应该只有 2 个表达式（title 去重）
        XCTAssertEqual(pool?.count, 2)
    }
    
    // MARK: - 完整模板测试
    
    func testCompleteTemplateCompilation() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Template name="home_card" version="1.0">
            <LinearLayout
                width="match_parent"
                height="wrap_content"
                orientation="vertical"
                padding="16dp"
                backgroundColor="#FFFFFF"
                cornerRadius="8dp">
                
                <Text
                    id="title"
                    width="match_parent"
                    height="wrap_content"
                    text="${data.title}"
                    fontSize="18sp"
                    fontWeight="bold"
                    textColor="#333333"
                    maxLines="2"
                    ellipsize="end"/>
                
                <Image
                    id="cover"
                    width="match_parent"
                    height="0dp"
                    aspectRatio="1.5"
                    src="${data.imageUrl}"
                    scaleType="cover"
                    cornerRadius="4dp"
                    marginTop="12dp"/>
                
                <FrameLayout
                    width="match_parent"
                    height="wrap_content"
                    marginTop="12dp">
                    
                    <Text
                        id="author"
                        text="${data.author}"
                        fontSize="14sp"
                        textColor="#999999"/>
                    
                    <Text
                        id="likes"
                        text="${formatNumber(data.likeCount)}"
                        fontSize="14sp"
                        textColor="#FF6B6B"/>
                        
                </FrameLayout>
                
            </LinearLayout>
        </Template>
        """
        
        let json = try compiler.compile(xml)
        
        // 验证模板信息
        XCTAssertEqual(json["name"] as? String, "home_card")
        XCTAssertEqual(json["version"] as? String, "1.0")
        
        // 验证根节点
        let root = json["root"] as? [String: Any]
        XCTAssertEqual(root?["type"] as? String, "linear")
        
        // 验证子节点数量
        let children = root?["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 3)  // Text, Image, FrameLayout
        
        // 验证绑定
        let titleNode = children?.first
        let titleBindings = titleNode?["bindings"] as? [String: Any]
        XCTAssertNotNil(titleBindings?["text"])
    }
    
    // MARK: - JSON 输出测试
    
    func testMinifiedOutput() throws {
        compiler.options.minify = true
        
        let xml = """
        <View width="100dp" height="50dp"/>
        """
        
        let jsonString = try compiler.compileToString(xml)
        
        // 压缩输出不应包含换行
        XCTAssertFalse(jsonString.contains("\n"))
    }
    
    func testPrettyOutput() throws {
        compiler.options.minify = false
        
        let xml = """
        <View width="100dp" height="50dp"/>
        """
        
        let jsonString = try compiler.compileToString(xml)
        
        // 格式化输出应包含换行
        XCTAssertTrue(jsonString.contains("\n"))
    }
}
