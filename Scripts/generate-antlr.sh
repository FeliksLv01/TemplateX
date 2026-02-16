#!/bin/bash
# TemplateX ANTLR4 代码生成脚本
#
# 使用方法:
#   ./Scripts/generate-antlr.sh
#
# 前置条件:
#   1. 安装 ANTLR4: brew install antlr4
#   2. 安装 antlr4-tools (可选): pip install antlr4-tools
#
# 生成的文件:
#   - TemplateXExprLexer.swift
#   - TemplateXExprParser.swift
#   - TemplateXExprVisitor.swift
#   - TemplateXExprBaseVisitor.swift

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GRAMMAR_DIR="$PROJECT_DIR/Sources/Core/Expression/Grammar"
OUTPUT_DIR="$PROJECT_DIR/Sources/Core/Expression/Generated"

echo "📦 TemplateX ANTLR4 Code Generator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Grammar: $GRAMMAR_DIR/TemplateXExpr.g4"
echo "Output:  $OUTPUT_DIR"
echo ""

# 检查 ANTLR4 是否安装
if ! command -v antlr4 &> /dev/null; then
    echo "❌ Error: antlr4 not found"
    echo ""
    echo "Please install ANTLR4:"
    echo "  brew install antlr4"
    echo ""
    echo "Or using pip:"
    echo "  pip install antlr4-tools"
    exit 1
fi

# 检查语法文件是否存在
if [ ! -f "$GRAMMAR_DIR/TemplateXExpr.g4" ]; then
    echo "❌ Error: Grammar file not found: $GRAMMAR_DIR/TemplateXExpr.g4"
    exit 1
fi

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

# 清理旧的生成文件
echo "🧹 Cleaning old generated files..."
rm -f "$OUTPUT_DIR"/*.swift
rm -f "$OUTPUT_DIR"/*.interp
rm -f "$OUTPUT_DIR"/*.tokens

# 生成 Swift 代码
echo "⚙️  Generating Swift code..."
antlr4 -Dlanguage=Swift \
       -visitor \
       -no-listener \
       -o "$OUTPUT_DIR" \
       -package TemplateXExpr \
       "$GRAMMAR_DIR/TemplateXExpr.g4"

# 移动生成的文件（ANTLR4 可能在子目录生成）
if [ -d "$OUTPUT_DIR/Grammar" ]; then
    mv "$OUTPUT_DIR/Grammar"/*.swift "$OUTPUT_DIR/" 2>/dev/null || true
    rm -rf "$OUTPUT_DIR/Grammar"
fi

# 清理不需要的文件
rm -f "$OUTPUT_DIR"/*.interp
rm -f "$OUTPUT_DIR"/*.tokens

# 列出生成的文件
echo ""
echo "✅ Generated files:"
ls -la "$OUTPUT_DIR"/*.swift 2>/dev/null || echo "   (no files generated)"

echo ""
echo "🎉 Done!"
