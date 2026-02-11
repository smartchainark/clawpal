#!/bin/bash

# OpenClaw Voice Call - 通过 CLI 命令测试 AI 对话
# 使用 continue 命令触发 AI 响应

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OpenClaw Voice Call - AI 对话测试 (CLI) ===${NC}"
echo ""

# 清理旧状态
echo -e "${YELLOW}[1/7]${NC} 清理旧的通话状态..."
> ~/.openclaw/voice-calls/calls.jsonl

# 清理旧的 webhook 进程
echo -e "${YELLOW}[2/7]${NC} 清理旧的 webhook 进程..."
lsof -ti :3334 | xargs kill -9 2>/dev/null || true
sleep 1

# 发起通话（后台运行）
echo -e "${YELLOW}[3/7]${NC} 发起测试通话..."
LOG_FILE="/tmp/call-ai-cli-test.log"
openclaw voicecall call \
  --to "+15550005678" \
  --message "你好，我是 OpenClaw AI 助手。" \
  --mode conversation \
  > "$LOG_FILE" 2>&1 &

CALL_PID=$!
echo "通话进程 PID: $CALL_PID"

# 等待 webhook 服务器启动
echo -e "${YELLOW}[4/7]${NC} 等待 webhook 服务器启动..."
sleep 5

# 提取 Call ID
CALL_ID=$(grep -o '"callId": "[^"]*"' "$LOG_FILE" | head -1 | cut -d'"' -f4)

if [ -z "$CALL_ID" ]; then
    echo -e "${RED}错误：无法获取 Call ID${NC}"
    cat "$LOG_FILE"
    exit 1
fi

echo -e "${GREEN}Call ID: $CALL_ID${NC}"
echo ""

# 模拟用户应答
echo -e "${YELLOW}[5/7]${NC} 模拟用户应答..."
curl -s -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.answered\",\"callId\":\"$CALL_ID\",\"timestamp\":$(date +%s)000}}" \
  -o /dev/null

sleep 2

# 第一轮对话：用户说话 + AI 回复
echo -e "${YELLOW}[6/7]${NC} 第一轮对话"
echo -e "用户: 你是谁？你能做什么？"

# 通过 CLI 命令触发 AI 响应
openclaw voicecall continue \
  --call-id "$CALL_ID" \
  --message "你是谁？你能做什么？" \
  > /tmp/ai-response-1.log 2>&1

echo -e "${GREEN}✓ AI 已生成回复${NC}"
sleep 3

# 第二轮对话
echo -e "${YELLOW}[7/7]${NC} 第二轮对话"
echo -e "用户: 今天的日期是什么？"

openclaw voicecall continue \
  --call-id "$CALL_ID" \
  --message "今天的日期是什么？" \
  > /tmp/ai-response-2.log 2>&1

echo -e "${GREEN}✓ AI 已生成第二轮回复${NC}"
sleep 3

# 结束通话
echo ""
echo -e "${YELLOW}结束通话...${NC}"
openclaw voicecall end --call-id "$CALL_ID" > /dev/null 2>&1 || true

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

# 统计 AI 回复数量
AI_MESSAGES=$(grep "$CALL_ID" ~/.openclaw/voice-calls/calls.jsonl | tail -1 | jq '[.transcript[]? | select(.speaker == "bot")] | length')

echo "Call ID: $CALL_ID"
echo "AI 回复数量: $AI_MESSAGES"
echo "详细日志: $LOG_FILE"
echo ""

if [ "$AI_MESSAGES" -gt 1 ]; then
    echo -e "${GREEN}✅ AI 自动回复功能正常工作！${NC}"
    echo -e "   模型: google-antigravity/gemini-3-pro-high"

    # 显示 AI 回复内容
    echo ""
    echo -e "${BLUE}=== AI 回复内容 ===${NC}"
    grep "$CALL_ID" ~/.openclaw/voice-calls/calls.jsonl | tail -1 | jq -r '.transcript[]? | select(.speaker == "bot") | .text'
else
    echo -e "${YELLOW}⚠️  AI 可能未成功回复${NC}"
    echo -e "   请检查日志"
fi

echo ""
