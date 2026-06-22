#!/bin/bash
# 远行商人 · PC 端打包脚本
# 用法: bash scripts/export_pc.sh [version]
# 需要 Godot 4.x + 导出模板已安装

set -e

VERSION="${1:-0.1.0}"
GODOT_BIN="${GODOT_PATH:-godot}"
OUTPUT_DIR="builds"

echo "🎮 远行商人 v$VERSION PC 打包开始"
echo "================================"

# 清理旧版
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ---------- Windows ----------
echo "🪟 打包 Windows x86_64..."
$GODOT_BIN --headless \
    --export-release "Windows Desktop" \
    "$OUTPUT_DIR/Merchant-Game-v$VERSION-win64.exe"

# ---------- Linux ----------
echo "🐧 打包 Linux x86_64..."
$GODOT_BIN --headless \
    --export-release "Linux/X11" \
    "$OUTPUT_DIR/Merchant-Game-v$VERSION-linux.x86_64"

echo "================================"
echo "✅ 打包完成！"
echo "📦 输出目录: $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/"

# 打包成压缩包
echo "📦 打包压缩..."
cd "$OUTPUT_DIR"
zip "Merchant-Game-v$VERSION-win64.zip" "Merchant-Game-v$VERSION-win64.exe" 2>/dev/null || true
tar -czf "Merchant-Game-v$VERSION-linux.tar.gz" "Merchant-Game-v$VERSION-linux.x86_64" 2>/dev/null || true
cd ..

echo "✅ 全部完成！"
