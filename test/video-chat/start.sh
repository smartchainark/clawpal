#!/bin/bash
# Clawpal 视频聊天 - 快速启动脚本

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💙 Clawpal 视频聊天系统启动"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查依赖
echo "🔍 检查依赖..."

if ! command -v node &>/dev/null; then
    echo "❌ 未找到 Node.js，请先安装"
    exit 1
fi

# 切换到脚本所在目录
cd "$(dirname "$0")"

# 检查是否有 node_modules
if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖（npm install）..."
    npm install
else
    echo "✅ 依赖已安装"
fi

# 检查环境变量
if [ -z "${REPLICATE_API_TOKEN:-}" ]; then
    echo "⚠️  警告: REPLICATE_API_TOKEN 未设置"
    echo "   请运行: export REPLICATE_API_TOKEN=\"your_token_here\""
    echo ""
fi

# 启动桥接服务器
echo "🚀 启动 WebSocket 桥接服务器..."
echo ""

node bridge.js
