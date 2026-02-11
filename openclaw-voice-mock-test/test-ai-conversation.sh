#!/bin/bash

# OpenClaw Voice Call - AI 真实对话测试脚本
# 测试 AI 自动回复功能（使用 Gemini 3 Pro High）

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OpenClaw Voice Call - AI 真实对话测试 ===${NC}"
echo ""

# 清理旧状态
echo -e "${YELLOW}[1/7]${NC} 清理旧的通话状态..."
> ~/.openclaw/voice-calls/calls.jsonl

# 清理旧的 webhook 进程
echo -e "${YELLOW}[2/7]${NC} 清理旧的 webhook 进程..."
lsof -ti :3334 | xargs kill -9 2>/dev/null || true
sleep 1

# 启动通话（后台运行）
echo -e "${YELLOW}[3/7]${NC} 发起测试通话..."
LOG_FILE="/tmp/call-ai-test.log"
openclaw voicecall call \
  --to "+15550005678" \
  --message "你好，我是 OpenClaw AI 助手，有什么可以帮你的吗？" \
  --mode conversation \
  > "$LOG_FILE" 2>&1 &

CALL_PID=$!
echo "通话进程 PID: $CALL_PID"

# 等待 webhook 服务器启动
echo -e "${YELLOW}[4/7]${NC} 等待 webhook 服务器启动..."
sleep 5

# 提取 Call ID
CALL_ID=$(grep -o '"callId": "[^"]*"' "$LOG_FILE" | head -1 | cut -d'"' -f4)
echo -e "${GREEN}Call ID: $CALL_ID${NC}"
echo ""

# 模拟用户应答
echo -e "${YELLOW}[5/7]${NC} 模拟用户应答..."
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.answered\",\"callId\":\"$CALL_ID\",\"timestamp\":$(date +%s)000}}" \
  -s -o /dev/null

sleep 2

# 模拟用户说话（第一轮）
echo -e "${YELLOW}[6/7]${NC} 用户说话: 你是谁？你能做什么？"
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.speech\",\"callId\":\"$CALL_ID\",\"transcript\":\"你是谁？你能做什么？\",\"isFinal\":true,\"confidence\":0.95,\"timestamp\":$(date +%s)000}}" \
  -s -o /dev/null

echo -e "${GREEN}✓ 已发送用户输入${NC}"
echo ""

# 等待 AI 响应
echo -e "${BLUE}等待 AI 自动回复...${NC}"
sleep 8

# 模拟用户说话（第二轮）
echo -e "${YELLOW}[7/7]${NC} 用户说话: 告诉我今天的日期"
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.speech\",\"callId\":\"$CALL_ID\",\"transcript\":\"告诉我今天的日期\",\"isFinal\":true,\"confidence\":0.95,\"timestamp\":$(date +%s)000}}" \
  -s -o /dev/null

echo -e "${GREEN}✓ 已发送第二个用户输入${NC}"
echo ""

# 等待第二轮 AI 响应
echo -e "${BLUE}等待 AI 第二轮回复...${NC}"
sleep 8

# 结束通话
echo ""
echo -e "${YELLOW}结束通话...${NC}"
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.ended\",\"callId\":\"$CALL_ID\",\"reason\":\"completed\",\"timestamp\":$(date +%s)000}}" \
  -s -o /dev/null

sleep 2

# 显示完整对话记录
echo ""
echo -e "${GREEN}=== 对话记录 ===${NC}"
TRANSCRIPT=$(grep "$CALL_ID" ~/.openclaw/voice-calls/calls.jsonl | tail -1 | jq -r '.transcript[]? | "[\(.speaker)] \(.text)"')

if [ -z "$TRANSCRIPT" ]; then
    echo -e "${YELLOW}⚠️  未找到对话记录，查看原始数据：${NC}"
    grep "$CALL_ID" ~/.openclaw/voice-calls/calls.jsonl | tail -1 | jq '.'
else
    echo "$TRANSCRIPT"
fi

echo ""
echo -e "${GREEN}=== 测试完成 ===${NC}"
echo ""
echo "详细日志: $LOG_FILE"
echo "状态文件: ~/.openclaw/voice-calls/calls.jsonl"
echo ""

# 检查是否有 AI 回复
AI_MESSAGES=$(grep "$CALL_ID" ~/.openclaw/voice-calls/calls.jsonl | tail -1 | jq -r '[.transcript[]? | select(.speaker == "bot")] | length')

if [ "$AI_MESSAGES" -gt 1 ]; then
    echo -e "${GREEN}✅ AI 自动回复功能正常工作！${NC}"
    echo -e "   发现 $AI_MESSAGES 条 AI 回复"
else
    echo -e "${YELLOW}⚠️  AI 可能未自动回复${NC}"
    echo -e "   只有初始消息，检查配置：responseModel 和 responseSystemPrompt"
fi

echo ""
