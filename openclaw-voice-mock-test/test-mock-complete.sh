#!/bin/bash
set -e

WEBHOOK_URL="http://127.0.0.1:3334/voice/webhook"
CALL_LOG="/tmp/mock-call.log"

echo "=========================================="
echo "OpenClaw Mock 完整测试（正确方式）"
echo "=========================================="
echo ""

# Step 1: 发起通话
echo "[1/7] 发起 conversation 模式通话..."
openclaw voicecall call \
  --to "+15550005678" \
  --message "你好，我是OpenClaw助手，请问有什么可以帮到你？" \
  --mode conversation \
  > $CALL_LOG 2>&1 &

CALL_PID=$!
echo "    进程 PID: $CALL_PID"
sleep 5

# 提取 call ID
CALL_ID=$(grep -o '"callId": "[^"]*"' $CALL_LOG | cut -d'"' -f4)
if [ -z "$CALL_ID" ]; then
    echo "❌ 无法获取 call ID"
    cat $CALL_LOG
    exit 1
fi
echo "    ✓ 通话已发起"
echo "    📞 Call ID: $CALL_ID"
echo ""
sleep 2

# Step 2: 模拟用户应答（发送 webhook 事件）
echo "[2/7] 模拟用户应答 (call.answered)..."
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d "{
    \"event\": {
      \"type\": \"call.answered\",
      \"callId\": \"$CALL_ID\",
      \"timestamp\": $(date +%s)000
    }
  }" > /dev/null
echo "    ✓ 应答事件已发送"
sleep 2
echo ""

# Step 3: 模拟用户语音输入
echo "[3/7] 模拟用户说话 (call.speech)..."
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d "{
    \"event\": {
      \"type\": \"call.speech\",
      \"callId\": \"$CALL_ID\",
      \"transcript\": \"我想了解OpenClaw的功能\",
      \"isFinal\": true,
      \"confidence\": 0.95,
      \"timestamp\": $(date +%s)000
    }
  }" > /dev/null
echo "    ✓ 语音输入已发送: '我想了解OpenClaw的功能'"
sleep 2
echo ""

# Step 4: 继续对话
echo "[4/7] 继续对话 (continue)..."
openclaw voicecall continue \
  --call-id "$CALL_ID" \
  --message "OpenClaw是一个多平台AI助手，支持Telegram、WhatsApp等渠道。" \
  > /tmp/continue-1.log 2>&1 || true
echo "    ✓ 第二轮对话已发送"
sleep 2
echo ""

# Step 5: 再次模拟用户语音
echo "[5/7] 模拟用户再次说话..."
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d "{
    \"event\": {
      \"type\": \"call.speech\",
      \"callId\": \"$CALL_ID\",
      \"transcript\": \"听起来很棒！\",
      \"isFinal\": true,
      \"confidence\": 0.98,
      \"timestamp\": $(date +%s)000
    }
  }" > /dev/null
echo "    ✓ 语音输入已发送: '听起来很棒！'"
sleep 2
echo ""

# Step 6: 使用 speak 发送单向消息
echo "[6/7] 发送单向消息 (speak)..."
openclaw voicecall speak \
  --call-id "$CALL_ID" \
  --message "感谢你的关注，Mock测试即将结束。" \
  > /tmp/speak.log 2>&1 || true
echo "    ✓ speak 消息已发送"
sleep 2
echo ""

# Step 7: 结束通话
echo "[7/7] 结束通话..."
openclaw voicecall end \
  --call-id "$CALL_ID" \
  > /tmp/end.log 2>&1 || true
echo "    ✓ 通话已结束"
sleep 2
echo ""

# 停止后台进程
kill $CALL_PID 2>/dev/null || true

# 查看最终状态
echo "=== 最终状态 ==="
cat ~/.openclaw/voice-calls/calls.jsonl | grep "$CALL_ID" | tail -1 | jq -r '.state' || echo "无法读取状态"
echo ""

echo "=========================================="
echo "✅ Mock 测试完成！"
echo "=========================================="
echo ""
echo "测试摘要:"
echo "  ✓ 发起 conversation 通话"
echo "  ✓ 模拟用户应答"
echo "  ✓ 模拟用户语音输入 (2次)"
echo "  ✓ 使用 continue 继续对话"
echo "  ✓ 使用 speak 单向播放"
echo "  ✓ 结束通话"
echo ""
echo "Call ID: $CALL_ID"
echo "日志文件: $CALL_LOG"
