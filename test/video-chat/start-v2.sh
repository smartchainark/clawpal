#!/bin/bash
# Clawpal 视频聊天 v2 - 使用 OpenClaw agent 最佳实践

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💙 Clawpal 视频聊天系统 v2 启动"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查依赖
echo "🔍 检查依赖..."

if ! command -v node &>/dev/null; then
    echo "❌ 未找到 Node.js，请先安装"
    exit 1
fi

if ! command -v openclaw &>/dev/null; then
    echo "❌ 未找到 OpenClaw CLI，请先安装"
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

# 检查 OpenClaw Gateway
if ! curl -s http://localhost:18789/health >/dev/null 2>&1; then
    echo "⚠️  警告: OpenClaw Gateway 未运行"
    echo "   请先启动: openclaw gateway"
    echo ""
fi

# 启动桥接服务器 v2
echo "🚀 启动 WebSocket 桥接服务器 v2..."
echo ""

node bridge-v2.js
