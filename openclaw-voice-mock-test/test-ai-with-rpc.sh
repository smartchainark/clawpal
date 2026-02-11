#!/bin/bash

# OpenClaw Voice Call - 通过 Gateway RPC 测试 AI 对话
# 使用 continue_call 工具触发 AI 自动回复

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 从配置文件读取 token
GATEWAY_TOKEN=$(jq -r '.gateway.auth.token' ~/.openclaw/openclaw.json)

if [ -z "$GATEWAY_TOKEN" ] || [ "$GATEWAY_TOKEN" = "null" ]; then
    echo -e "${RED}错误：无法从配置文件读取 Gateway token${NC}"
    exit 1
fi

echo -e "${BLUE}=== OpenClaw Voice Call - AI 对话测试 (Gateway RPC) ===${NC}"
echo ""

# 清理旧状态
echo -e "${YELLOW}[1/8]${NC} 清理旧的通话状态..."
> ~/.openclaw/voice-calls/calls.jsonl

# 清理旧的 webhook 进程
echo -e "${YELLOW}[2/8]${NC} 清理旧的 webhook 进程..."
lsof -ti :3334 | xargs kill -9 2>/dev/null || true
sleep 1

# 通过 Gateway RPC 发起通话
echo -e "${YELLOW}[3/8]${NC} 通过 Gateway RPC 发起通话..."
INIT_RESPONSE=$(curl -s -X POST http://127.0.0.1:18789/rpc \
  -H "Authorization: Bearer $GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "voicecall.initiate",
    "params": {
      "to": "+15550005678",
      "message": "你好，我是 OpenClaw AI 助手。",
      "mode": "conversation"
    },
    "id": 1
  }')

CALL_ID=$(echo "$INIT_RESPONSE" | jq -r '.result.callId')

if [ -z "$CALL_ID" ] || [ "$CALL_ID" = "null" ]; then
    echo -e "${RED}错误：无法获取 Call ID${NC}"
    echo "Response: $INIT_RESPONSE"
    exit 1
fi

echo -e "${GREEN}Call ID: $CALL_ID${NC}"
echo ""

# 等待通话建立
echo -e "${YELLOW}[4/8]${NC} 等待通话建立..."
sleep 3

# 模拟用户应答
echo -e "${YELLOW}[5/8]${NC} 模拟用户应答..."
curl -s -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.answered\",\"callId\":\"$CALL_ID\",\"timestamp\":$(date +%s)000}}" \
  -o /dev/null

sleep 2

# 第一轮对话：用户说话
echo -e "${YELLOW}[6/8]${NC} 用户说话: 你是谁？你能做什么？"
curl -s -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.speech\",\"callId\":\"$CALL_ID\",\"transcript\":\"你是谁？你能做什么？\",\"isFinal\":true,\"confidence\":0.95,\"timestamp\":$(date +%s)000}}" \
  -o /dev/null

sleep 2

# 通过 RPC 触发 AI 回复
echo -e "${YELLOW}[7/8]${NC} 触发 AI 回复（第一轮）..."
CONTINUE_RESPONSE=$(curl -s -X POST http://127.0.0.1:18789/rpc \
  -H "Authorization: Bearer $GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"voicecall.continue\",
    \"params\": {
      \"callId\": \"$CALL_ID\",
      \"message\": \"你是谁？你能做什么？\"
    },
    \"id\": 2
  }")

echo -e "${GREEN}✓ AI 正在生成回复...${NC}"
sleep 8

# 第二轮对话
echo -e "${YELLOW}[8/8]${NC} 用户说话: 今天的日期是什么？"
curl -s -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.speech\",\"callId\":\"$CALL_ID\",\"transcript\":\"今天的日期是什么？\",\"isFinal\":true,\"confidence\":0.95,\"timestamp\":$(date +%s)000}}" \
  -o /dev/null

sleep 2

# 触发第二轮 AI 回复
echo -e "${BLUE}触发 AI 回复（第二轮）...${NC}"
curl -s -X POST http://127.0.0.1:18789/rpc \
  -H "Authorization: Bearer $GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"voicecall.continue\",
    \"params\": {
      \"callId\": \"$CALL_ID\",
      \"message\": \"今天的日期是什么？\"
    },
    \"id\": 3
  }" -o /dev/null

echo -e "${GREEN}✓ AI 正在生成第二轮回复...${NC}"
sleep 8

# 结束通话
echo ""
echo -e "${YELLOW}结束通话...${NC}"
curl -s -X POST http://127.0.0.1:18789/rpc \
  -H "Authorization: Bearer $GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"voicecall.end\",
    \"params\": {
      \"callId\": \"$CALL_ID\"
    },
    \"id\": 4
  }" -o /dev/null

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
echo ""

if [ "$AI_MESSAGES" -gt 1 ]; then
    echo -e "${GREEN}✅ AI 自动回复功能正常工作！${NC}"
    echo -e "   模型: google-antigravity/gemini-3-pro-high"
else
    echo -e "${YELLOW}⚠️  AI 可能未成功回复${NC}"
    echo -e "   请检查 Gateway 日志: ~/.openclaw/logs/gateway.log"
fi

echo ""
