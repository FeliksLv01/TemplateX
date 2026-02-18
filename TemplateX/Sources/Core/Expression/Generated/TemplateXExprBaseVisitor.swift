// Generated from /Users/lvyou4/Desktop/DSL/TemplateX/Sources/Core/Expression/Grammar/TemplateXExpr.g4 by ANTLR 4.13.2
import Antlr4

/**
 * This class provides an empty implementation of {@link TemplateXExprVisitor},
 * which can be extended to create a visitor which only needs to handle a subset
 * of the available methods.
 *
 * @param <T> The return type of the visit operation. Use {@link Void} for
 * operations with no return type.
 */
open class TemplateXExprBaseVisitor<T>: AbstractParseTreeVisitor<T> {
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitExpression(_ ctx: TemplateXExprParser.ExpressionContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitTernary(_ ctx: TemplateXExprParser.TernaryContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitLogicalOr(_ ctx: TemplateXExprParser.LogicalOrContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitLogicalAnd(_ ctx: TemplateXExprParser.LogicalAndContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitEquality(_ ctx: TemplateXExprParser.EqualityContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitComparison(_ ctx: TemplateXExprParser.ComparisonContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitAdditive(_ ctx: TemplateXExprParser.AdditiveContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitMultiplicative(_ ctx: TemplateXExprParser.MultiplicativeContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitUnary(_ ctx: TemplateXExprParser.UnaryContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitPostfix(_ ctx: TemplateXExprParser.PostfixContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitMemberAccess(_ ctx: TemplateXExprParser.MemberAccessContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitFunctionCall(_ ctx: TemplateXExprParser.FunctionCallContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitIndexAccess(_ ctx: TemplateXExprParser.IndexAccessContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitArgumentList(_ ctx: TemplateXExprParser.ArgumentListContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitNumberLiteral(_ ctx: TemplateXExprParser.NumberLiteralContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitStringLiteral(_ ctx: TemplateXExprParser.StringLiteralContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitTrueLiteral(_ ctx: TemplateXExprParser.TrueLiteralContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitFalseLiteral(_ ctx: TemplateXExprParser.FalseLiteralContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitNullLiteral(_ ctx: TemplateXExprParser.NullLiteralContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitIdentifier(_ ctx: TemplateXExprParser.IdentifierContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitParenthesized(_ ctx: TemplateXExprParser.ParenthesizedContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitArrayExpr(_ ctx: TemplateXExprParser.ArrayExprContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitObjectExpr(_ ctx: TemplateXExprParser.ObjectExprContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitArrayLiteral(_ ctx: TemplateXExprParser.ArrayLiteralContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitObjectLiteral(_ ctx: TemplateXExprParser.ObjectLiteralContext) -> T? { return visitChildren(ctx) }
	/**
	 * {@inheritDoc}
	 *
	 * <p>The default implementation returns the result of calling
	 * {@link #visitChildren} on {@code ctx}.</p>
	 */
	open func visitObjectEntry(_ ctx: TemplateXExprParser.ObjectEntryContext) -> T? { return visitChildren(ctx) }
}