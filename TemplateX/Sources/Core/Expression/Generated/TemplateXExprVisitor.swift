// Generated from /Users/lvyou4/Desktop/DSL/TemplateX/Sources/Core/Expression/Grammar/TemplateXExpr.g4 by ANTLR 4.13.2
import Antlr4

/**
 * This interface defines a complete generic visitor for a parse tree produced
 * by {@link TemplateXExprParser}.
 *
 * @param <T> The return type of the visit operation. Use {@link Void} for
 * operations with no return type.
 */
open class TemplateXExprVisitor<T>: ParseTreeVisitor<T> {
	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#expression}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitExpression(_ ctx: TemplateXExprParser.ExpressionContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#ternary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitTernary(_ ctx: TemplateXExprParser.TernaryContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#logicalOr}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitLogicalOr(_ ctx: TemplateXExprParser.LogicalOrContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#logicalAnd}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitLogicalAnd(_ ctx: TemplateXExprParser.LogicalAndContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#equality}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitEquality(_ ctx: TemplateXExprParser.EqualityContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#comparison}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitComparison(_ ctx: TemplateXExprParser.ComparisonContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#additive}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitAdditive(_ ctx: TemplateXExprParser.AdditiveContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#multiplicative}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitMultiplicative(_ ctx: TemplateXExprParser.MultiplicativeContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#unary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitUnary(_ ctx: TemplateXExprParser.UnaryContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#postfix}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitPostfix(_ ctx: TemplateXExprParser.PostfixContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code MemberAccess}
	 * labeled alternative in {@link TemplateXExprParser#postfixOp}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitMemberAccess(_ ctx: TemplateXExprParser.MemberAccessContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code FunctionCall}
	 * labeled alternative in {@link TemplateXExprParser#postfixOp}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitFunctionCall(_ ctx: TemplateXExprParser.FunctionCallContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code IndexAccess}
	 * labeled alternative in {@link TemplateXExprParser#postfixOp}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitIndexAccess(_ ctx: TemplateXExprParser.IndexAccessContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#argumentList}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitArgumentList(_ ctx: TemplateXExprParser.ArgumentListContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code NumberLiteral}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitNumberLiteral(_ ctx: TemplateXExprParser.NumberLiteralContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code StringLiteral}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitStringLiteral(_ ctx: TemplateXExprParser.StringLiteralContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code TrueLiteral}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitTrueLiteral(_ ctx: TemplateXExprParser.TrueLiteralContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code FalseLiteral}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitFalseLiteral(_ ctx: TemplateXExprParser.FalseLiteralContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code NullLiteral}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitNullLiteral(_ ctx: TemplateXExprParser.NullLiteralContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code Identifier}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitIdentifier(_ ctx: TemplateXExprParser.IdentifierContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code Parenthesized}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitParenthesized(_ ctx: TemplateXExprParser.ParenthesizedContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code ArrayExpr}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitArrayExpr(_ ctx: TemplateXExprParser.ArrayExprContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by the {@code ObjectExpr}
	 * labeled alternative in {@link TemplateXExprParser#primary}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitObjectExpr(_ ctx: TemplateXExprParser.ObjectExprContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#arrayLiteral}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitArrayLiteral(_ ctx: TemplateXExprParser.ArrayLiteralContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#objectLiteral}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitObjectLiteral(_ ctx: TemplateXExprParser.ObjectLiteralContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

	/**
	 * Visit a parse tree produced by {@link TemplateXExprParser#objectEntry}.
	- Parameters:
	  - ctx: the parse tree
	- returns: the visitor result
	 */
	open func visitObjectEntry(_ ctx: TemplateXExprParser.ObjectEntryContext) -> T {
	 	fatalError(#function + " must be overridden")
	}

}