/**
 * TemplateX 表达式语法
 * 
 * 支持的特性:
 * - 数据访问: data.title, data.user.name, data.items[0]
 * - 算术运算: +, -, *, /, %
 * - 比较运算: ==, !=, >, <, >=, <=
 * - 逻辑运算: &&, ||, !
 * - 三元表达式: condition ? trueValue : falseValue
 * - 函数调用: formatDate(data.time, 'yyyy-MM-dd')
 * - 字面量: 数字, 字符串, 布尔值, null
 */
grammar TemplateXExpr;

// ==================== Parser Rules ====================

/** 入口规则 */
expression
    : ternary EOF
    ;

/** 三元表达式: condition ? trueExpr : falseExpr */
ternary
    : logicalOr (QUESTION ternary COLON ternary)?
    ;

/** 逻辑或: a || b */
logicalOr
    : logicalAnd (OR logicalAnd)*
    ;

/** 逻辑与: a && b */
logicalAnd
    : equality (AND equality)*
    ;

/** 相等比较: a == b, a != b */
equality
    : comparison ((EQ | NE) comparison)*
    ;

/** 大小比较: a < b, a > b, a <= b, a >= b */
comparison
    : additive ((LT | GT | LE | GE) additive)*
    ;

/** 加减运算: a + b, a - b */
additive
    : multiplicative ((PLUS | MINUS) multiplicative)*
    ;

/** 乘除运算: a * b, a / b, a % b */
multiplicative
    : unary ((MUL | DIV | MOD) unary)*
    ;

/** 一元运算: !a, -a */
unary
    : NOT unary
    | MINUS unary
    | postfix
    ;

/** 后缀运算: 成员访问、函数调用、数组索引 */
postfix
    : primary postfixOp*
    ;

postfixOp
    : DOT IDENTIFIER                              # MemberAccess
    | LPAREN argumentList? RPAREN                 # FunctionCall
    | LBRACK expression RBRACK                    # IndexAccess
    ;

/** 函数参数列表 */
argumentList
    : ternary (COMMA ternary)*
    ;

/** 基础表达式 */
primary
    : NUMBER                                      # NumberLiteral
    | STRING                                      # StringLiteral
    | TRUE                                        # TrueLiteral
    | FALSE                                       # FalseLiteral
    | NULL                                        # NullLiteral
    | IDENTIFIER                                  # Identifier
    | LPAREN ternary RPAREN                       # Parenthesized
    | arrayLiteral                                # ArrayExpr
    | objectLiteral                               # ObjectExpr
    ;

/** 数组字面量: [1, 2, 3] */
arrayLiteral
    : LBRACK (ternary (COMMA ternary)*)? RBRACK
    ;

/** 对象字面量: {key: value, key2: value2} */
objectLiteral
    : LBRACE (objectEntry (COMMA objectEntry)*)? RBRACE
    ;

objectEntry
    : (IDENTIFIER | STRING) COLON ternary
    ;

// ==================== Lexer Rules ====================

// 关键字
TRUE    : 'true';
FALSE   : 'false';
NULL    : 'null';

// 运算符
PLUS    : '+';
MINUS   : '-';
MUL     : '*';
DIV     : '/';
MOD     : '%';

EQ      : '==';
NE      : '!=';
LT      : '<';
GT      : '>';
LE      : '<=';
GE      : '>=';

AND     : '&&';
OR      : '||';
NOT     : '!';

QUESTION: '?';
COLON   : ':';

DOT     : '.';
COMMA   : ',';

LPAREN  : '(';
RPAREN  : ')';
LBRACK  : '[';
RBRACK  : ']';
LBRACE  : '{';
RBRACE  : '}';

// 数字: 整数或小数
NUMBER
    : [0-9]+ ('.' [0-9]+)?
    ;

// 字符串: 单引号或双引号
STRING
    : '"' (~["\r\n\\] | '\\' .)* '"'
    | '\'' (~['\r\n\\] | '\\' .)* '\''
    ;

// 标识符
IDENTIFIER
    : [a-zA-Z_][a-zA-Z0-9_]*
    ;

// 跳过空白字符
WS
    : [ \t\r\n]+ -> skip
    ;
