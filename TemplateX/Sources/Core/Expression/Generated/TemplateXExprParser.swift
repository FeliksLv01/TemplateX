// Generated from /Users/lvyou4/Desktop/DSL/TemplateX/Sources/Core/Expression/Grammar/TemplateXExpr.g4 by ANTLR 4.13.2
import Antlr4

open class TemplateXExprParser: Parser {

	internal static var _decisionToDFA: [DFA] = {
          var decisionToDFA = [DFA]()
          let length = TemplateXExprParser._ATN.getNumberOfDecisions()
          for i in 0..<length {
            decisionToDFA.append(DFA(TemplateXExprParser._ATN.getDecisionState(i)!, i))
           }
           return decisionToDFA
     }()

	internal static let _sharedContextCache = PredictionContextCache()

	public
	enum Tokens: Int {
		case EOF = -1, TRUE = 1, FALSE = 2, NULL = 3, PLUS = 4, MINUS = 5, MUL = 6, 
                 DIV = 7, MOD = 8, EQ = 9, NE = 10, LT = 11, GT = 12, LE = 13, 
                 GE = 14, AND = 15, OR = 16, NOT = 17, QUESTION = 18, COLON = 19, 
                 DOT = 20, COMMA = 21, LPAREN = 22, RPAREN = 23, LBRACK = 24, 
                 RBRACK = 25, LBRACE = 26, RBRACE = 27, NUMBER = 28, STRING = 29, 
                 IDENTIFIER = 30, WS = 31
	}

	public
	static let RULE_expression = 0, RULE_ternary = 1, RULE_logicalOr = 2, RULE_logicalAnd = 3, 
            RULE_equality = 4, RULE_comparison = 5, RULE_additive = 6, RULE_multiplicative = 7, 
            RULE_unary = 8, RULE_postfix = 9, RULE_postfixOp = 10, RULE_argumentList = 11, 
            RULE_primary = 12, RULE_arrayLiteral = 13, RULE_objectLiteral = 14, 
            RULE_objectEntry = 15

	public
	static let ruleNames: [String] = [
		"expression", "ternary", "logicalOr", "logicalAnd", "equality", "comparison", 
		"additive", "multiplicative", "unary", "postfix", "postfixOp", "argumentList", 
		"primary", "arrayLiteral", "objectLiteral", "objectEntry"
	]

	private static let _LITERAL_NAMES: [String?] = [
		nil, "'true'", "'false'", "'null'", "'+'", "'-'", "'*'", "'/'", "'%'", 
		"'=='", "'!='", "'<'", "'>'", "'<='", "'>='", "'&&'", "'||'", "'!'", "'?'", 
		"':'", "'.'", "','", "'('", "')'", "'['", "']'", "'{'", "'}'"
	]
	private static let _SYMBOLIC_NAMES: [String?] = [
		nil, "TRUE", "FALSE", "NULL", "PLUS", "MINUS", "MUL", "DIV", "MOD", "EQ", 
		"NE", "LT", "GT", "LE", "GE", "AND", "OR", "NOT", "QUESTION", "COLON", 
		"DOT", "COMMA", "LPAREN", "RPAREN", "LBRACK", "RBRACK", "LBRACE", "RBRACE", 
		"NUMBER", "STRING", "IDENTIFIER", "WS"
	]
	public
	static let VOCABULARY = Vocabulary(_LITERAL_NAMES, _SYMBOLIC_NAMES)

	override open
	func getGrammarFileName() -> String { return "TemplateXExpr.g4" }

	override open
	func getRuleNames() -> [String] { return TemplateXExprParser.ruleNames }

	override open
	func getSerializedATN() -> [Int] { return TemplateXExprParser._serializedATN }

	override open
	func getATN() -> ATN { return TemplateXExprParser._ATN }


	override open
	func getVocabulary() -> Vocabulary {
	    return TemplateXExprParser.VOCABULARY
	}

	override public
	init(_ input:TokenStream) throws {
	    RuntimeMetaData.checkVersion("4.13.2", RuntimeMetaData.VERSION)
		try super.init(input)
		_interp = ParserATNSimulator(self,TemplateXExprParser._ATN,TemplateXExprParser._decisionToDFA, TemplateXExprParser._sharedContextCache)
	}


	public class ExpressionContext: ParserRuleContext {
			open
			func ternary() -> TernaryContext? {
				return getRuleContext(TernaryContext.self, 0)
			}
			open
			func EOF() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.EOF.rawValue, 0)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_expression
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitExpression(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitExpression(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func expression() throws -> ExpressionContext {
		var _localctx: ExpressionContext
		_localctx = ExpressionContext(_ctx, getState())
		try enterRule(_localctx, 0, TemplateXExprParser.RULE_expression)
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(32)
		 	try ternary()
		 	setState(33)
		 	try match(TemplateXExprParser.Tokens.EOF.rawValue)

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class TernaryContext: ParserRuleContext {
			open
			func logicalOr() -> LogicalOrContext? {
				return getRuleContext(LogicalOrContext.self, 0)
			}
			open
			func QUESTION() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.QUESTION.rawValue, 0)
			}
			open
			func ternary() -> [TernaryContext] {
				return getRuleContexts(TernaryContext.self)
			}
			open
			func ternary(_ i: Int) -> TernaryContext? {
				return getRuleContext(TernaryContext.self, i)
			}
			open
			func COLON() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.COLON.rawValue, 0)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_ternary
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitTernary(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitTernary(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func ternary() throws -> TernaryContext {
		var _localctx: TernaryContext
		_localctx = TernaryContext(_ctx, getState())
		try enterRule(_localctx, 2, TemplateXExprParser.RULE_ternary)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(35)
		 	try logicalOr()
		 	setState(41)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (_la == TemplateXExprParser.Tokens.QUESTION.rawValue) {
		 		setState(36)
		 		try match(TemplateXExprParser.Tokens.QUESTION.rawValue)
		 		setState(37)
		 		try ternary()
		 		setState(38)
		 		try match(TemplateXExprParser.Tokens.COLON.rawValue)
		 		setState(39)
		 		try ternary()

		 	}


		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class LogicalOrContext: ParserRuleContext {
			open
			func logicalAnd() -> [LogicalAndContext] {
				return getRuleContexts(LogicalAndContext.self)
			}
			open
			func logicalAnd(_ i: Int) -> LogicalAndContext? {
				return getRuleContext(LogicalAndContext.self, i)
			}
			open
			func OR() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.OR.rawValue)
			}
			open
			func OR(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.OR.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_logicalOr
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitLogicalOr(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitLogicalOr(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func logicalOr() throws -> LogicalOrContext {
		var _localctx: LogicalOrContext
		_localctx = LogicalOrContext(_ctx, getState())
		try enterRule(_localctx, 4, TemplateXExprParser.RULE_logicalOr)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(43)
		 	try logicalAnd()
		 	setState(48)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == TemplateXExprParser.Tokens.OR.rawValue) {
		 		setState(44)
		 		try match(TemplateXExprParser.Tokens.OR.rawValue)
		 		setState(45)
		 		try logicalAnd()


		 		setState(50)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class LogicalAndContext: ParserRuleContext {
			open
			func equality() -> [EqualityContext] {
				return getRuleContexts(EqualityContext.self)
			}
			open
			func equality(_ i: Int) -> EqualityContext? {
				return getRuleContext(EqualityContext.self, i)
			}
			open
			func AND() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.AND.rawValue)
			}
			open
			func AND(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.AND.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_logicalAnd
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitLogicalAnd(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitLogicalAnd(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func logicalAnd() throws -> LogicalAndContext {
		var _localctx: LogicalAndContext
		_localctx = LogicalAndContext(_ctx, getState())
		try enterRule(_localctx, 6, TemplateXExprParser.RULE_logicalAnd)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(51)
		 	try equality()
		 	setState(56)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == TemplateXExprParser.Tokens.AND.rawValue) {
		 		setState(52)
		 		try match(TemplateXExprParser.Tokens.AND.rawValue)
		 		setState(53)
		 		try equality()


		 		setState(58)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class EqualityContext: ParserRuleContext {
			open
			func comparison() -> [ComparisonContext] {
				return getRuleContexts(ComparisonContext.self)
			}
			open
			func comparison(_ i: Int) -> ComparisonContext? {
				return getRuleContext(ComparisonContext.self, i)
			}
			open
			func EQ() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.EQ.rawValue)
			}
			open
			func EQ(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.EQ.rawValue, i)
			}
			open
			func NE() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.NE.rawValue)
			}
			open
			func NE(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.NE.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_equality
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitEquality(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitEquality(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func equality() throws -> EqualityContext {
		var _localctx: EqualityContext
		_localctx = EqualityContext(_ctx, getState())
		try enterRule(_localctx, 8, TemplateXExprParser.RULE_equality)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(59)
		 	try comparison()
		 	setState(64)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == TemplateXExprParser.Tokens.EQ.rawValue || _la == TemplateXExprParser.Tokens.NE.rawValue) {
		 		setState(60)
		 		_la = try _input.LA(1)
		 		if (!(_la == TemplateXExprParser.Tokens.EQ.rawValue || _la == TemplateXExprParser.Tokens.NE.rawValue)) {
		 		try _errHandler.recoverInline(self)
		 		}
		 		else {
		 			_errHandler.reportMatch(self)
		 			try consume()
		 		}
		 		setState(61)
		 		try comparison()


		 		setState(66)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class ComparisonContext: ParserRuleContext {
			open
			func additive() -> [AdditiveContext] {
				return getRuleContexts(AdditiveContext.self)
			}
			open
			func additive(_ i: Int) -> AdditiveContext? {
				return getRuleContext(AdditiveContext.self, i)
			}
			open
			func LT() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.LT.rawValue)
			}
			open
			func LT(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.LT.rawValue, i)
			}
			open
			func GT() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.GT.rawValue)
			}
			open
			func GT(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.GT.rawValue, i)
			}
			open
			func LE() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.LE.rawValue)
			}
			open
			func LE(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.LE.rawValue, i)
			}
			open
			func GE() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.GE.rawValue)
			}
			open
			func GE(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.GE.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_comparison
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitComparison(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitComparison(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func comparison() throws -> ComparisonContext {
		var _localctx: ComparisonContext
		_localctx = ComparisonContext(_ctx, getState())
		try enterRule(_localctx, 10, TemplateXExprParser.RULE_comparison)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(67)
		 	try additive()
		 	setState(72)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 30720) != 0)) {
		 		setState(68)
		 		_la = try _input.LA(1)
		 		if (!(((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 30720) != 0))) {
		 		try _errHandler.recoverInline(self)
		 		}
		 		else {
		 			_errHandler.reportMatch(self)
		 			try consume()
		 		}
		 		setState(69)
		 		try additive()


		 		setState(74)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class AdditiveContext: ParserRuleContext {
			open
			func multiplicative() -> [MultiplicativeContext] {
				return getRuleContexts(MultiplicativeContext.self)
			}
			open
			func multiplicative(_ i: Int) -> MultiplicativeContext? {
				return getRuleContext(MultiplicativeContext.self, i)
			}
			open
			func PLUS() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.PLUS.rawValue)
			}
			open
			func PLUS(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.PLUS.rawValue, i)
			}
			open
			func MINUS() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.MINUS.rawValue)
			}
			open
			func MINUS(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.MINUS.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_additive
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitAdditive(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitAdditive(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func additive() throws -> AdditiveContext {
		var _localctx: AdditiveContext
		_localctx = AdditiveContext(_ctx, getState())
		try enterRule(_localctx, 12, TemplateXExprParser.RULE_additive)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(75)
		 	try multiplicative()
		 	setState(80)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == TemplateXExprParser.Tokens.PLUS.rawValue || _la == TemplateXExprParser.Tokens.MINUS.rawValue) {
		 		setState(76)
		 		_la = try _input.LA(1)
		 		if (!(_la == TemplateXExprParser.Tokens.PLUS.rawValue || _la == TemplateXExprParser.Tokens.MINUS.rawValue)) {
		 		try _errHandler.recoverInline(self)
		 		}
		 		else {
		 			_errHandler.reportMatch(self)
		 			try consume()
		 		}
		 		setState(77)
		 		try multiplicative()


		 		setState(82)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class MultiplicativeContext: ParserRuleContext {
			open
			func unary() -> [UnaryContext] {
				return getRuleContexts(UnaryContext.self)
			}
			open
			func unary(_ i: Int) -> UnaryContext? {
				return getRuleContext(UnaryContext.self, i)
			}
			open
			func MUL() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.MUL.rawValue)
			}
			open
			func MUL(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.MUL.rawValue, i)
			}
			open
			func DIV() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.DIV.rawValue)
			}
			open
			func DIV(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.DIV.rawValue, i)
			}
			open
			func MOD() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.MOD.rawValue)
			}
			open
			func MOD(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.MOD.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_multiplicative
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitMultiplicative(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitMultiplicative(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func multiplicative() throws -> MultiplicativeContext {
		var _localctx: MultiplicativeContext
		_localctx = MultiplicativeContext(_ctx, getState())
		try enterRule(_localctx, 14, TemplateXExprParser.RULE_multiplicative)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(83)
		 	try unary()
		 	setState(88)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 448) != 0)) {
		 		setState(84)
		 		_la = try _input.LA(1)
		 		if (!(((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 448) != 0))) {
		 		try _errHandler.recoverInline(self)
		 		}
		 		else {
		 			_errHandler.reportMatch(self)
		 			try consume()
		 		}
		 		setState(85)
		 		try unary()


		 		setState(90)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class UnaryContext: ParserRuleContext {
			open
			func NOT() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.NOT.rawValue, 0)
			}
			open
			func unary() -> UnaryContext? {
				return getRuleContext(UnaryContext.self, 0)
			}
			open
			func MINUS() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.MINUS.rawValue, 0)
			}
			open
			func `postfix`() -> PostfixContext? {
				return getRuleContext(PostfixContext.self, 0)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_unary
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitUnary(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitUnary(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func unary() throws -> UnaryContext {
		var _localctx: UnaryContext
		_localctx = UnaryContext(_ctx, getState())
		try enterRule(_localctx, 16, TemplateXExprParser.RULE_unary)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(96)
		 	try _errHandler.sync(self)
		 	switch (TemplateXExprParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .NOT:
		 		try enterOuterAlt(_localctx, 1)
		 		setState(91)
		 		try match(TemplateXExprParser.Tokens.NOT.rawValue)
		 		setState(92)
		 		try unary()

		 		break

		 	case .MINUS:
		 		try enterOuterAlt(_localctx, 2)
		 		setState(93)
		 		try match(TemplateXExprParser.Tokens.MINUS.rawValue)
		 		setState(94)
		 		try unary()

		 		break
		 	case .TRUE:fallthrough
		 	case .FALSE:fallthrough
		 	case .NULL:fallthrough
		 	case .LPAREN:fallthrough
		 	case .LBRACK:fallthrough
		 	case .LBRACE:fallthrough
		 	case .NUMBER:fallthrough
		 	case .STRING:fallthrough
		 	case .IDENTIFIER:
		 		try enterOuterAlt(_localctx, 3)
		 		setState(95)
		 		try `postfix`()

		 		break
		 	default:
		 		throw ANTLRException.recognition(e: NoViableAltException(self))
		 	}
		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class PostfixContext: ParserRuleContext {
			open
			func primary() -> PrimaryContext? {
				return getRuleContext(PrimaryContext.self, 0)
			}
			open
			func postfixOp() -> [PostfixOpContext] {
				return getRuleContexts(PostfixOpContext.self)
			}
			open
			func postfixOp(_ i: Int) -> PostfixOpContext? {
				return getRuleContext(PostfixOpContext.self, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_postfix
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitPostfix(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitPostfix(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func `postfix`() throws -> PostfixContext {
		var _localctx: PostfixContext
		_localctx = PostfixContext(_ctx, getState())
		try enterRule(_localctx, 18, TemplateXExprParser.RULE_postfix)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(98)
		 	try primary()
		 	setState(102)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 22020096) != 0)) {
		 		setState(99)
		 		try postfixOp()


		 		setState(104)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class PostfixOpContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_postfixOp
		}
	}
	public class MemberAccessContext: PostfixOpContext {
			open
			func DOT() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.DOT.rawValue, 0)
			}
			open
			func IDENTIFIER() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.IDENTIFIER.rawValue, 0)
			}

		public
		init(_ ctx: PostfixOpContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitMemberAccess(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitMemberAccess(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class IndexAccessContext: PostfixOpContext {
			open
			func LBRACK() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.LBRACK.rawValue, 0)
			}
			open
			func expression() -> ExpressionContext? {
				return getRuleContext(ExpressionContext.self, 0)
			}
			open
			func RBRACK() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.RBRACK.rawValue, 0)
			}

		public
		init(_ ctx: PostfixOpContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitIndexAccess(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitIndexAccess(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class FunctionCallContext: PostfixOpContext {
			open
			func LPAREN() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.LPAREN.rawValue, 0)
			}
			open
			func RPAREN() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.RPAREN.rawValue, 0)
			}
			open
			func argumentList() -> ArgumentListContext? {
				return getRuleContext(ArgumentListContext.self, 0)
			}

		public
		init(_ ctx: PostfixOpContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitFunctionCall(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitFunctionCall(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func postfixOp() throws -> PostfixOpContext {
		var _localctx: PostfixOpContext
		_localctx = PostfixOpContext(_ctx, getState())
		try enterRule(_localctx, 20, TemplateXExprParser.RULE_postfixOp)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(116)
		 	try _errHandler.sync(self)
		 	switch (TemplateXExprParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .DOT:
		 		_localctx =  MemberAccessContext(_localctx);
		 		try enterOuterAlt(_localctx, 1)
		 		setState(105)
		 		try match(TemplateXExprParser.Tokens.DOT.rawValue)
		 		setState(106)
		 		try match(TemplateXExprParser.Tokens.IDENTIFIER.rawValue)

		 		break

		 	case .LPAREN:
		 		_localctx =  FunctionCallContext(_localctx);
		 		try enterOuterAlt(_localctx, 2)
		 		setState(107)
		 		try match(TemplateXExprParser.Tokens.LPAREN.rawValue)
		 		setState(109)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		if (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 1967259694) != 0)) {
		 			setState(108)
		 			try argumentList()

		 		}

		 		setState(111)
		 		try match(TemplateXExprParser.Tokens.RPAREN.rawValue)

		 		break

		 	case .LBRACK:
		 		_localctx =  IndexAccessContext(_localctx);
		 		try enterOuterAlt(_localctx, 3)
		 		setState(112)
		 		try match(TemplateXExprParser.Tokens.LBRACK.rawValue)
		 		setState(113)
		 		try expression()
		 		setState(114)
		 		try match(TemplateXExprParser.Tokens.RBRACK.rawValue)

		 		break
		 	default:
		 		throw ANTLRException.recognition(e: NoViableAltException(self))
		 	}
		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class ArgumentListContext: ParserRuleContext {
			open
			func ternary() -> [TernaryContext] {
				return getRuleContexts(TernaryContext.self)
			}
			open
			func ternary(_ i: Int) -> TernaryContext? {
				return getRuleContext(TernaryContext.self, i)
			}
			open
			func COMMA() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.COMMA.rawValue)
			}
			open
			func COMMA(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.COMMA.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_argumentList
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitArgumentList(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitArgumentList(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func argumentList() throws -> ArgumentListContext {
		var _localctx: ArgumentListContext
		_localctx = ArgumentListContext(_ctx, getState())
		try enterRule(_localctx, 22, TemplateXExprParser.RULE_argumentList)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(118)
		 	try ternary()
		 	setState(123)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == TemplateXExprParser.Tokens.COMMA.rawValue) {
		 		setState(119)
		 		try match(TemplateXExprParser.Tokens.COMMA.rawValue)
		 		setState(120)
		 		try ternary()


		 		setState(125)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class PrimaryContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_primary
		}
	}
	public class ArrayExprContext: PrimaryContext {
			open
			func arrayLiteral() -> ArrayLiteralContext? {
				return getRuleContext(ArrayLiteralContext.self, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitArrayExpr(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitArrayExpr(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class IdentifierContext: PrimaryContext {
			open
			func IDENTIFIER() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.IDENTIFIER.rawValue, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitIdentifier(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitIdentifier(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class StringLiteralContext: PrimaryContext {
			open
			func STRING() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.STRING.rawValue, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitStringLiteral(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitStringLiteral(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class TrueLiteralContext: PrimaryContext {
			open
			func TRUE() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.TRUE.rawValue, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitTrueLiteral(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitTrueLiteral(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class ObjectExprContext: PrimaryContext {
			open
			func objectLiteral() -> ObjectLiteralContext? {
				return getRuleContext(ObjectLiteralContext.self, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitObjectExpr(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitObjectExpr(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class ParenthesizedContext: PrimaryContext {
			open
			func LPAREN() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.LPAREN.rawValue, 0)
			}
			open
			func ternary() -> TernaryContext? {
				return getRuleContext(TernaryContext.self, 0)
			}
			open
			func RPAREN() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.RPAREN.rawValue, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitParenthesized(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitParenthesized(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class NullLiteralContext: PrimaryContext {
			open
			func NULL() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.NULL.rawValue, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitNullLiteral(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitNullLiteral(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class NumberLiteralContext: PrimaryContext {
			open
			func NUMBER() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.NUMBER.rawValue, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitNumberLiteral(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitNumberLiteral(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	public class FalseLiteralContext: PrimaryContext {
			open
			func FALSE() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.FALSE.rawValue, 0)
			}

		public
		init(_ ctx: PrimaryContext) {
			super.init()
			copyFrom(ctx)
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitFalseLiteral(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitFalseLiteral(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func primary() throws -> PrimaryContext {
		var _localctx: PrimaryContext
		_localctx = PrimaryContext(_ctx, getState())
		try enterRule(_localctx, 24, TemplateXExprParser.RULE_primary)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(138)
		 	try _errHandler.sync(self)
		 	switch (TemplateXExprParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .NUMBER:
		 		_localctx =  NumberLiteralContext(_localctx);
		 		try enterOuterAlt(_localctx, 1)
		 		setState(126)
		 		try match(TemplateXExprParser.Tokens.NUMBER.rawValue)

		 		break

		 	case .STRING:
		 		_localctx =  StringLiteralContext(_localctx);
		 		try enterOuterAlt(_localctx, 2)
		 		setState(127)
		 		try match(TemplateXExprParser.Tokens.STRING.rawValue)

		 		break

		 	case .TRUE:
		 		_localctx =  TrueLiteralContext(_localctx);
		 		try enterOuterAlt(_localctx, 3)
		 		setState(128)
		 		try match(TemplateXExprParser.Tokens.TRUE.rawValue)

		 		break

		 	case .FALSE:
		 		_localctx =  FalseLiteralContext(_localctx);
		 		try enterOuterAlt(_localctx, 4)
		 		setState(129)
		 		try match(TemplateXExprParser.Tokens.FALSE.rawValue)

		 		break

		 	case .NULL:
		 		_localctx =  NullLiteralContext(_localctx);
		 		try enterOuterAlt(_localctx, 5)
		 		setState(130)
		 		try match(TemplateXExprParser.Tokens.NULL.rawValue)

		 		break

		 	case .IDENTIFIER:
		 		_localctx =  IdentifierContext(_localctx);
		 		try enterOuterAlt(_localctx, 6)
		 		setState(131)
		 		try match(TemplateXExprParser.Tokens.IDENTIFIER.rawValue)

		 		break

		 	case .LPAREN:
		 		_localctx =  ParenthesizedContext(_localctx);
		 		try enterOuterAlt(_localctx, 7)
		 		setState(132)
		 		try match(TemplateXExprParser.Tokens.LPAREN.rawValue)
		 		setState(133)
		 		try ternary()
		 		setState(134)
		 		try match(TemplateXExprParser.Tokens.RPAREN.rawValue)

		 		break

		 	case .LBRACK:
		 		_localctx =  ArrayExprContext(_localctx);
		 		try enterOuterAlt(_localctx, 8)
		 		setState(136)
		 		try arrayLiteral()

		 		break

		 	case .LBRACE:
		 		_localctx =  ObjectExprContext(_localctx);
		 		try enterOuterAlt(_localctx, 9)
		 		setState(137)
		 		try objectLiteral()

		 		break
		 	default:
		 		throw ANTLRException.recognition(e: NoViableAltException(self))
		 	}
		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class ArrayLiteralContext: ParserRuleContext {
			open
			func LBRACK() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.LBRACK.rawValue, 0)
			}
			open
			func RBRACK() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.RBRACK.rawValue, 0)
			}
			open
			func ternary() -> [TernaryContext] {
				return getRuleContexts(TernaryContext.self)
			}
			open
			func ternary(_ i: Int) -> TernaryContext? {
				return getRuleContext(TernaryContext.self, i)
			}
			open
			func COMMA() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.COMMA.rawValue)
			}
			open
			func COMMA(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.COMMA.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_arrayLiteral
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitArrayLiteral(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitArrayLiteral(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func arrayLiteral() throws -> ArrayLiteralContext {
		var _localctx: ArrayLiteralContext
		_localctx = ArrayLiteralContext(_ctx, getState())
		try enterRule(_localctx, 26, TemplateXExprParser.RULE_arrayLiteral)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(140)
		 	try match(TemplateXExprParser.Tokens.LBRACK.rawValue)
		 	setState(149)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 1967259694) != 0)) {
		 		setState(141)
		 		try ternary()
		 		setState(146)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		while (_la == TemplateXExprParser.Tokens.COMMA.rawValue) {
		 			setState(142)
		 			try match(TemplateXExprParser.Tokens.COMMA.rawValue)
		 			setState(143)
		 			try ternary()


		 			setState(148)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 		}

		 	}

		 	setState(151)
		 	try match(TemplateXExprParser.Tokens.RBRACK.rawValue)

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class ObjectLiteralContext: ParserRuleContext {
			open
			func LBRACE() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.LBRACE.rawValue, 0)
			}
			open
			func RBRACE() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.RBRACE.rawValue, 0)
			}
			open
			func objectEntry() -> [ObjectEntryContext] {
				return getRuleContexts(ObjectEntryContext.self)
			}
			open
			func objectEntry(_ i: Int) -> ObjectEntryContext? {
				return getRuleContext(ObjectEntryContext.self, i)
			}
			open
			func COMMA() -> [TerminalNode] {
				return getTokens(TemplateXExprParser.Tokens.COMMA.rawValue)
			}
			open
			func COMMA(_ i:Int) -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.COMMA.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_objectLiteral
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitObjectLiteral(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitObjectLiteral(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func objectLiteral() throws -> ObjectLiteralContext {
		var _localctx: ObjectLiteralContext
		_localctx = ObjectLiteralContext(_ctx, getState())
		try enterRule(_localctx, 28, TemplateXExprParser.RULE_objectLiteral)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(153)
		 	try match(TemplateXExprParser.Tokens.LBRACE.rawValue)
		 	setState(162)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (_la == TemplateXExprParser.Tokens.STRING.rawValue || _la == TemplateXExprParser.Tokens.IDENTIFIER.rawValue) {
		 		setState(154)
		 		try objectEntry()
		 		setState(159)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		while (_la == TemplateXExprParser.Tokens.COMMA.rawValue) {
		 			setState(155)
		 			try match(TemplateXExprParser.Tokens.COMMA.rawValue)
		 			setState(156)
		 			try objectEntry()


		 			setState(161)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 		}

		 	}

		 	setState(164)
		 	try match(TemplateXExprParser.Tokens.RBRACE.rawValue)

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class ObjectEntryContext: ParserRuleContext {
			open
			func COLON() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.COLON.rawValue, 0)
			}
			open
			func ternary() -> TernaryContext? {
				return getRuleContext(TernaryContext.self, 0)
			}
			open
			func IDENTIFIER() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.IDENTIFIER.rawValue, 0)
			}
			open
			func STRING() -> TerminalNode? {
				return getToken(TemplateXExprParser.Tokens.STRING.rawValue, 0)
			}
		override open
		func getRuleIndex() -> Int {
			return TemplateXExprParser.RULE_objectEntry
		}
		override open
		func accept<T>(_ visitor: ParseTreeVisitor<T>) -> T? {
			if let visitor = visitor as? TemplateXExprVisitor {
			    return visitor.visitObjectEntry(self)
			}
			else if let visitor = visitor as? TemplateXExprBaseVisitor {
			    return visitor.visitObjectEntry(self)
			}
			else {
			     return visitor.visitChildren(self)
			}
		}
	}
	@discardableResult
	 open func objectEntry() throws -> ObjectEntryContext {
		var _localctx: ObjectEntryContext
		_localctx = ObjectEntryContext(_ctx, getState())
		try enterRule(_localctx, 30, TemplateXExprParser.RULE_objectEntry)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(166)
		 	_la = try _input.LA(1)
		 	if (!(_la == TemplateXExprParser.Tokens.STRING.rawValue || _la == TemplateXExprParser.Tokens.IDENTIFIER.rawValue)) {
		 	try _errHandler.recoverInline(self)
		 	}
		 	else {
		 		_errHandler.reportMatch(self)
		 		try consume()
		 	}
		 	setState(167)
		 	try match(TemplateXExprParser.Tokens.COLON.rawValue)
		 	setState(168)
		 	try ternary()

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	static let _serializedATN:[Int] = [
		4,1,31,171,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,7,6,2,7,
		7,7,2,8,7,8,2,9,7,9,2,10,7,10,2,11,7,11,2,12,7,12,2,13,7,13,2,14,7,14,
		2,15,7,15,1,0,1,0,1,0,1,1,1,1,1,1,1,1,1,1,1,1,3,1,42,8,1,1,2,1,2,1,2,5,
		2,47,8,2,10,2,12,2,50,9,2,1,3,1,3,1,3,5,3,55,8,3,10,3,12,3,58,9,3,1,4,
		1,4,1,4,5,4,63,8,4,10,4,12,4,66,9,4,1,5,1,5,1,5,5,5,71,8,5,10,5,12,5,74,
		9,5,1,6,1,6,1,6,5,6,79,8,6,10,6,12,6,82,9,6,1,7,1,7,1,7,5,7,87,8,7,10,
		7,12,7,90,9,7,1,8,1,8,1,8,1,8,1,8,3,8,97,8,8,1,9,1,9,5,9,101,8,9,10,9,
		12,9,104,9,9,1,10,1,10,1,10,1,10,3,10,110,8,10,1,10,1,10,1,10,1,10,1,10,
		3,10,117,8,10,1,11,1,11,1,11,5,11,122,8,11,10,11,12,11,125,9,11,1,12,1,
		12,1,12,1,12,1,12,1,12,1,12,1,12,1,12,1,12,1,12,1,12,3,12,139,8,12,1,13,
		1,13,1,13,1,13,5,13,145,8,13,10,13,12,13,148,9,13,3,13,150,8,13,1,13,1,
		13,1,14,1,14,1,14,1,14,5,14,158,8,14,10,14,12,14,161,9,14,3,14,163,8,14,
		1,14,1,14,1,15,1,15,1,15,1,15,1,15,0,0,16,0,2,4,6,8,10,12,14,16,18,20,
		22,24,26,28,30,0,5,1,0,9,10,1,0,11,14,1,0,4,5,1,0,6,8,1,0,29,30,180,0,
		32,1,0,0,0,2,35,1,0,0,0,4,43,1,0,0,0,6,51,1,0,0,0,8,59,1,0,0,0,10,67,1,
		0,0,0,12,75,1,0,0,0,14,83,1,0,0,0,16,96,1,0,0,0,18,98,1,0,0,0,20,116,1,
		0,0,0,22,118,1,0,0,0,24,138,1,0,0,0,26,140,1,0,0,0,28,153,1,0,0,0,30,166,
		1,0,0,0,32,33,3,2,1,0,33,34,5,0,0,1,34,1,1,0,0,0,35,41,3,4,2,0,36,37,5,
		18,0,0,37,38,3,2,1,0,38,39,5,19,0,0,39,40,3,2,1,0,40,42,1,0,0,0,41,36,
		1,0,0,0,41,42,1,0,0,0,42,3,1,0,0,0,43,48,3,6,3,0,44,45,5,16,0,0,45,47,
		3,6,3,0,46,44,1,0,0,0,47,50,1,0,0,0,48,46,1,0,0,0,48,49,1,0,0,0,49,5,1,
		0,0,0,50,48,1,0,0,0,51,56,3,8,4,0,52,53,5,15,0,0,53,55,3,8,4,0,54,52,1,
		0,0,0,55,58,1,0,0,0,56,54,1,0,0,0,56,57,1,0,0,0,57,7,1,0,0,0,58,56,1,0,
		0,0,59,64,3,10,5,0,60,61,7,0,0,0,61,63,3,10,5,0,62,60,1,0,0,0,63,66,1,
		0,0,0,64,62,1,0,0,0,64,65,1,0,0,0,65,9,1,0,0,0,66,64,1,0,0,0,67,72,3,12,
		6,0,68,69,7,1,0,0,69,71,3,12,6,0,70,68,1,0,0,0,71,74,1,0,0,0,72,70,1,0,
		0,0,72,73,1,0,0,0,73,11,1,0,0,0,74,72,1,0,0,0,75,80,3,14,7,0,76,77,7,2,
		0,0,77,79,3,14,7,0,78,76,1,0,0,0,79,82,1,0,0,0,80,78,1,0,0,0,80,81,1,0,
		0,0,81,13,1,0,0,0,82,80,1,0,0,0,83,88,3,16,8,0,84,85,7,3,0,0,85,87,3,16,
		8,0,86,84,1,0,0,0,87,90,1,0,0,0,88,86,1,0,0,0,88,89,1,0,0,0,89,15,1,0,
		0,0,90,88,1,0,0,0,91,92,5,17,0,0,92,97,3,16,8,0,93,94,5,5,0,0,94,97,3,
		16,8,0,95,97,3,18,9,0,96,91,1,0,0,0,96,93,1,0,0,0,96,95,1,0,0,0,97,17,
		1,0,0,0,98,102,3,24,12,0,99,101,3,20,10,0,100,99,1,0,0,0,101,104,1,0,0,
		0,102,100,1,0,0,0,102,103,1,0,0,0,103,19,1,0,0,0,104,102,1,0,0,0,105,106,
		5,20,0,0,106,117,5,30,0,0,107,109,5,22,0,0,108,110,3,22,11,0,109,108,1,
		0,0,0,109,110,1,0,0,0,110,111,1,0,0,0,111,117,5,23,0,0,112,113,5,24,0,
		0,113,114,3,0,0,0,114,115,5,25,0,0,115,117,1,0,0,0,116,105,1,0,0,0,116,
		107,1,0,0,0,116,112,1,0,0,0,117,21,1,0,0,0,118,123,3,2,1,0,119,120,5,21,
		0,0,120,122,3,2,1,0,121,119,1,0,0,0,122,125,1,0,0,0,123,121,1,0,0,0,123,
		124,1,0,0,0,124,23,1,0,0,0,125,123,1,0,0,0,126,139,5,28,0,0,127,139,5,
		29,0,0,128,139,5,1,0,0,129,139,5,2,0,0,130,139,5,3,0,0,131,139,5,30,0,
		0,132,133,5,22,0,0,133,134,3,2,1,0,134,135,5,23,0,0,135,139,1,0,0,0,136,
		139,3,26,13,0,137,139,3,28,14,0,138,126,1,0,0,0,138,127,1,0,0,0,138,128,
		1,0,0,0,138,129,1,0,0,0,138,130,1,0,0,0,138,131,1,0,0,0,138,132,1,0,0,
		0,138,136,1,0,0,0,138,137,1,0,0,0,139,25,1,0,0,0,140,149,5,24,0,0,141,
		146,3,2,1,0,142,143,5,21,0,0,143,145,3,2,1,0,144,142,1,0,0,0,145,148,1,
		0,0,0,146,144,1,0,0,0,146,147,1,0,0,0,147,150,1,0,0,0,148,146,1,0,0,0,
		149,141,1,0,0,0,149,150,1,0,0,0,150,151,1,0,0,0,151,152,5,25,0,0,152,27,
		1,0,0,0,153,162,5,26,0,0,154,159,3,30,15,0,155,156,5,21,0,0,156,158,3,
		30,15,0,157,155,1,0,0,0,158,161,1,0,0,0,159,157,1,0,0,0,159,160,1,0,0,
		0,160,163,1,0,0,0,161,159,1,0,0,0,162,154,1,0,0,0,162,163,1,0,0,0,163,
		164,1,0,0,0,164,165,5,27,0,0,165,29,1,0,0,0,166,167,7,4,0,0,167,168,5,
		19,0,0,168,169,3,2,1,0,169,31,1,0,0,0,17,41,48,56,64,72,80,88,96,102,109,
		116,123,138,146,149,159,162
	]

	public
	static let _ATN = try! ATNDeserializer().deserialize(_serializedATN)
}