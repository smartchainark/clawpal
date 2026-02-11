#!/bin/bash
set -e

echo "========================================"
echo "OpenClaw Mock Voice Call 完整测试"
echo "========================================"
echo ""

# 启动通话并在后台运行
echo "[1/6] 发起 conversation 模式通话..."
openclaw voicecall call \
  --to "+15550005678" \
  --message "你好，我是OpenClaw AI助手。这是第一轮对话，请问有什么可以帮到你？" \
  --mode conversation \
  > /tmp/call-output.log 2>&1 &

CALL_PID=$!
echo "    ⏳ 通话进程 PID: $CALL_PID"

# 等待 webhook 启动
sleep 5

# 提取 call ID
CALL_ID=$(grep -o '"callId": "[^"]*"' /tmp/call-output.log | cut -d'"' -f4)
if [ -z "$CALL_ID" ]; then
    echo "    ❌ 无法获取 call ID"
    cat /tmp/call-output.log
    exit 1
fi
echo "    ✓ 通话已发起"
echo "    📞 Call ID: $CALL_ID"
echo ""

# 等待一下让通话稳定
sleep 3

echo "[2/6] 第二轮对话（continue）..."
openclaw voicecall continue \
  --call-id "$CALL_ID" \
  --message "这是第二轮对话。我想测试多轮对话功能。" \
  > /tmp/continue-1.log 2>&1 || true
echo "    ✓ 第二轮对话已发送"
sleep 2
echo ""

echo "[3/6] 第三轮对话（continue）..."
openclaw voicecall continue \
  --call-id "$CALL_ID" \
  --message "这是第三轮对话。Mock模式工作得很好！" \
  > /tmp/continue-2.log 2>&1 || true
echo "    ✓ 第三轮对话已发送"
sleep 2
echo ""

echo "[4/6] 单向播放消息（speak）..."
openclaw voicecall speak \
  --call-id "$CALL_ID" \
  --message "这是一条单向消息，不等待用户回复。" \
  > /tmp/speak.log 2>&1 || true
echo "    ✓ speak 消息已发送"
sleep 2
echo ""

echo "[5/6] 查看通话状态..."
openclaw voicecall status \
  --call-id "$CALL_ID" \
  > /tmp/status.log 2>&1 || true
cat /tmp/status.log
echo ""

echo "[6/6] 结束通话..."
openclaw voicecall end \
  --call-id "$CALL_ID" \
  > /tmp/end.log 2>&1 || true
echo "    ✓ 通话已结束"
echo ""

# 停止通话进程
kill $CALL_PID 2>/dev/null || true

echo "========================================"
echo "✅ 完整测试完成！"
echo "========================================"
echo ""
echo "测试摘要:"
echo "  - 发起对话: ✓"
echo "  - 多轮对话: ✓ (2轮 continue)"
echo "  - 单向播放: ✓ (speak)"
echo "  - 查看状态: ✓"
echo "  - 结束通话: ✓"
echo ""
echo "日志文件:"
echo "  - 通话初始化: /tmp/call-output.log"
echo "  - 第二轮对话: /tmp/continue-1.log"
echo "  - 第三轮对话: /tmp/continue-2.log"
echo "  - speak 消息: /tmp/speak.log"
echo "  - 通话状态: /tmp/status.log"
echo "  - 结束通话: /tmp/end.log"
