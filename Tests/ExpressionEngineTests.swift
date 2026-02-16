import XCTest
@testable import TemplateX

final class ExpressionEngineTests: XCTestCase {
    
    var engine: ExpressionEngine!
    
    override func setUp() {
        super.setUp()
        engine = ExpressionEngine(cacheCapacity: 100)
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Literal Tests
    
    func testNumberLiteral() {
        let result = engine.eval("42", context: [:])
        XCTAssertEqual(result as? Double, 42.0)
    }
    
    func testFloatLiteral() {
        let result = engine.eval("3.14", context: [:])
        XCTAssertEqual(result as? Double, 3.14)
    }
    
    func testStringLiteral() {
        let result = engine.eval("'hello'", context: [:])
        XCTAssertEqual(result as? String, "hello")
    }
    
    func testBooleanTrue() {
        let result = engine.eval("true", context: [:])
        XCTAssertEqual(result as? Bool, true)
    }
    
    func testBooleanFalse() {
        let result = engine.eval("false", context: [:])
        XCTAssertEqual(result as? Bool, false)
    }
    
    func testNullLiteral() {
        let result = engine.eval("null", context: [:])
        XCTAssertNil(result)
    }
    
    // MARK: - Arithmetic Tests
    
    func testAddition() {
        let result = engine.eval("1 + 2", context: [:])
        XCTAssertEqual(result as? Double, 3.0)
    }
    
    func testSubtraction() {
        let result = engine.eval("10 - 3", context: [:])
        XCTAssertEqual(result as? Double, 7.0)
    }
    
    func testMultiplication() {
        let result = engine.eval("4 * 5", context: [:])
        XCTAssertEqual(result as? Double, 20.0)
    }
    
    func testDivision() {
        let result = engine.eval("15 / 3", context: [:])
        XCTAssertEqual(result as? Double, 5.0)
    }
    
    func testModulo() {
        let result = engine.eval("17 % 5", context: [:])
        XCTAssertEqual(result as? Double, 2.0)
    }
    
    func testComplexArithmetic() {
        let result = engine.eval("(1 + 2) * 3 - 4 / 2", context: [:])
        XCTAssertEqual(result as? Double, 7.0)
    }
    
    func testNegation() {
        let result = engine.eval("-5", context: [:])
        XCTAssertEqual(result as? Double, -5.0)
    }
    
    // MARK: - Comparison Tests
    
    func testEqual() {
        XCTAssertEqual(engine.eval("1 == 1", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("1 == 2", context: [:]) as? Bool, false)
    }
    
    func testNotEqual() {
        XCTAssertEqual(engine.eval("1 != 2", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("1 != 1", context: [:]) as? Bool, false)
    }
    
    func testLessThan() {
        XCTAssertEqual(engine.eval("1 < 2", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("2 < 1", context: [:]) as? Bool, false)
    }
    
    func testGreaterThan() {
        XCTAssertEqual(engine.eval("2 > 1", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("1 > 2", context: [:]) as? Bool, false)
    }
    
    func testLessOrEqual() {
        XCTAssertEqual(engine.eval("1 <= 2", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("2 <= 2", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("3 <= 2", context: [:]) as? Bool, false)
    }
    
    func testGreaterOrEqual() {
        XCTAssertEqual(engine.eval("2 >= 1", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("2 >= 2", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("1 >= 2", context: [:]) as? Bool, false)
    }
    
    // MARK: - Logical Tests
    
    func testLogicalAnd() {
        XCTAssertEqual(engine.eval("true && true", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("true && false", context: [:]) as? Bool, false)
        XCTAssertEqual(engine.eval("false && true", context: [:]) as? Bool, false)
    }
    
    func testLogicalOr() {
        XCTAssertEqual(engine.eval("true || false", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("false || true", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("false || false", context: [:]) as? Bool, false)
    }
    
    func testLogicalNot() {
        XCTAssertEqual(engine.eval("!true", context: [:]) as? Bool, false)
        XCTAssertEqual(engine.eval("!false", context: [:]) as? Bool, true)
    }
    
    // MARK: - Ternary Tests
    
    func testTernaryTrue() {
        let result = engine.eval("true ? 1 : 2", context: [:])
        XCTAssertEqual(result as? Double, 1.0)
    }
    
    func testTernaryFalse() {
        let result = engine.eval("false ? 1 : 2", context: [:])
        XCTAssertEqual(result as? Double, 2.0)
    }
    
    func testTernaryWithExpression() {
        let result = engine.eval("5 > 3 ? 'yes' : 'no'", context: [:])
        XCTAssertEqual(result as? String, "yes")
    }
    
    // MARK: - Variable Access Tests
    
    func testSimpleVariable() {
        let context: [String: Any] = ["name": "Alice"]
        let result = engine.eval("name", context: context)
        XCTAssertEqual(result as? String, "Alice")
    }
    
    func testNestedVariable() {
        let context: [String: Any] = [
            "user": ["name": "Bob", "age": 30]
        ]
        let result = engine.eval("user.name", context: context)
        XCTAssertEqual(result as? String, "Bob")
    }
    
    func testDeepNestedVariable() {
        let context: [String: Any] = [
            "data": [
                "user": [
                    "profile": ["name": "Charlie"]
                ]
            ]
        ]
        let result = engine.eval("data.user.profile.name", context: context)
        XCTAssertEqual(result as? String, "Charlie")
    }
    
    func testArrayIndex() {
        let context: [String: Any] = [
            "items": ["apple", "banana", "cherry"]
        ]
        let result = engine.eval("items[1]", context: context)
        XCTAssertEqual(result as? String, "banana")
    }
    
    // MARK: - String Concatenation Tests
    
    func testStringConcat() {
        let context: [String: Any] = ["name": "World"]
        let result = engine.eval("'Hello, ' + name", context: context)
        XCTAssertEqual(result as? String, "Hello, World")
    }
    
    // MARK: - Function Tests
    
    func testMaxFunction() {
        let result = engine.eval("max(1, 5, 3)", context: [:])
        XCTAssertEqual(result as? Double, 5.0)
    }
    
    func testMinFunction() {
        let result = engine.eval("min(1, 5, 3)", context: [:])
        XCTAssertEqual(result as? Double, 1.0)
    }
    
    func testAbsFunction() {
        let result = engine.eval("abs(-10)", context: [:])
        XCTAssertEqual(result as? Double, 10.0)
    }
    
    func testRoundFunction() {
        let result = engine.eval("round(3.7)", context: [:])
        XCTAssertEqual(result as? Double, 4.0)
    }
    
    func testLengthFunction() {
        let result = engine.eval("length('hello')", context: [:])
        XCTAssertEqual(result as? Double, 5.0)
    }
    
    func testUppercaseFunction() {
        let result = engine.eval("uppercase('hello')", context: [:])
        XCTAssertEqual(result as? String, "HELLO")
    }
    
    func testLowercaseFunction() {
        let result = engine.eval("lowercase('HELLO')", context: [:])
        XCTAssertEqual(result as? String, "hello")
    }
    
    func testTrimFunction() {
        let result = engine.eval("trim('  hello  ')", context: [:])
        XCTAssertEqual(result as? String, "hello")
    }
    
    func testSubstringFunction() {
        let result = engine.eval("substring('hello world', 0, 5)", context: [:])
        XCTAssertEqual(result as? String, "hello")
    }
    
    func testContainsFunction() {
        XCTAssertEqual(engine.eval("contains('hello', 'ell')", context: [:]) as? Bool, true)
        XCTAssertEqual(engine.eval("contains('hello', 'xyz')", context: [:]) as? Bool, false)
    }
    
    // MARK: - Binding Expression Tests
    
    func testSimpleBinding() {
        let context: [String: Any] = ["title": "Hello"]
        let result = engine.resolveBinding("${title}", context: context)
        XCTAssertEqual(result as? String, "Hello")
    }
    
    func testMixedBinding() {
        let context: [String: Any] = ["name": "World"]
        let result = engine.resolveBinding("Hello, ${name}!", context: context)
        XCTAssertEqual(result as? String, "Hello, World!")
    }
    
    func testMultipleBindings() {
        let context: [String: Any] = ["first": "Hello", "last": "World"]
        let result = engine.resolveBinding("${first}, ${last}!", context: context)
        XCTAssertEqual(result as? String, "Hello, World!")
    }
    
    func testExpressionBinding() {
        let context: [String: Any] = ["price": 100, "discount": 20]
        let result = engine.resolveBinding("${price - discount}", context: context)
        XCTAssertEqual(result as? Double, 80.0)
    }
    
    func testNoBinding() {
        let result = engine.resolveBinding("plain text", context: [:])
        XCTAssertEqual(result as? String, "plain text")
    }
    
    // MARK: - Cache Tests
    
    func testCacheHit() {
        let context: [String: Any] = ["x": 10]
        
        // 第一次求值
        _ = engine.eval("x + 1", context: context)
        let initialHitRate = engine.cacheHitRate
        
        // 第二次求值（应该命中缓存）
        _ = engine.eval("x + 1", context: context)
        
        // 缓存命中率应该增加
        XCTAssertGreaterThan(engine.cacheHitRate, initialHitRate)
    }
    
    func testCacheCount() {
        let expressions = ["1 + 1", "2 + 2", "3 + 3"]
        
        for expr in expressions {
            _ = engine.eval(expr, context: [:])
        }
        
        XCTAssertEqual(engine.cacheCount, 3)
    }
    
    func testClearCache() {
        _ = engine.eval("1 + 1", context: [:])
        XCTAssertEqual(engine.cacheCount, 1)
        
        engine.clearCache()
        XCTAssertEqual(engine.cacheCount, 0)
    }
    
    // MARK: - Custom Function Tests
    
    func testRegisterCustomFunction() {
        engine.registerFunction(name: "double") { args in
            guard let num = args.first as? Double else { return 0.0 }
            return num * 2
        }
        
        let result = engine.eval("double(5)", context: [:])
        XCTAssertEqual(result as? Double, 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidExpression() {
        let result = engine.evaluate("1 +", context: [:])
        XCTAssertFalse(result.isSuccess)
    }
    
    func testUndefinedVariable() {
        let result = engine.eval("undefined_var", context: [:])
        XCTAssertNil(result)
    }
    
    // MARK: - Complex Expression Tests
    
    func testComplexExpression() {
        let context: [String: Any] = [
            "user": [
                "name": "Alice",
                "age": 25,
                "isVip": true
            ],
            "discount": 0.2
        ]
        
        // 测试复杂条件表达式
        let result = engine.eval(
            "user.isVip && user.age >= 18 ? user.name + ' gets ' + (100 * discount) + '% off' : 'No discount'",
            context: context
        )
        XCTAssertEqual(result as? String, "Alice gets 20% off")
    }
    
    // MARK: - Array/Object Literal Tests
    
    func testArrayLiteral() {
        let result = engine.eval("[1, 2, 3]", context: [:])
        XCTAssertEqual(result as? [Double], [1.0, 2.0, 3.0])
    }
    
    func testObjectLiteral() {
        let result = engine.eval("{name: 'test', value: 42}", context: [:])
        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["name"] as? String, "test")
        XCTAssertEqual(dict?["value"] as? Double, 42.0)
    }
}
