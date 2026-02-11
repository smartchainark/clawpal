# OpenClaw Mock 模式完整使用指南

## ✅ 测试验证结果

Mock 模式已**完全测试通过**，所有功能正常工作。

## 🏗️ 架构理解

### Mock 模式工作原理

1. **Webhook 驱动**：Mock provider 是被动的，所有事件通过 webhook POST 驱动
2. **状态持久化**：通话状态保存在 `~/.openclaw/voice-calls/calls.jsonl`
3. **并发限制**：默认 `maxConcurrentCalls = 1`

### 状态机流程

```
initiated → answered → speaking/listening → completed
```

## 📖 正确使用方式

### 方案 1：通过 Webhook 手动测试（已验证成功）

```bash
# 步骤 1: 发起通话（保持后台运行）
openclaw voicecall call \
  --to "+15550005678" \
  --message "你好，我是AI助手" \
  --mode conversation \
  > /tmp/call.log 2>&1 &

# 等待 webhook 服务器启动
sleep 5

# 提取 Call ID
CALL_ID=$(grep -o '"callId": "[^"]*"' /tmp/call.log | cut -d'"' -f4)
echo "Call ID: $CALL_ID"

# 步骤 2: 模拟用户应答
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.answered\",\"callId\":\"$CALL_ID\",\"timestamp\":$(date +%s)000}}"

# 步骤 3: 模拟用户语音输入
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.speech\",\"callId\":\"$CALL_ID\",\"transcript\":\"你好\",\"isFinal\":true,\"confidence\":0.95,\"timestamp\":$(date +%s)000}}"

# 步骤 4: 模拟 AI 说话
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.speaking\",\"callId\":\"$CALL_ID\",\"text\":\"很高兴为你服务\",\"timestamp\":$(date +%s)000}}"

# 步骤 5: 结束通话
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"call.ended\",\"callId\":\"$CALL_ID\",\"reason\":\"completed\",\"timestamp\":$(date +%s)000}}"

# 步骤 6: 查看结果
grep "$CALL_ID" ~/.openclaw/voice-calls/calls.jsonl | tail -1 | jq '.'
```

### 方案 2：通过 Gateway RPC（生产推荐）

```bash
# 启动 Gateway
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 通过 Gateway HTTP API 调用 RPC
curl -X POST http://127.0.0.1:18789/rpc \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "voicecall.initiate",
    "params": {
      "to": "+15550005678",
      "message": "你好",
      "mode": "conversation"
    },
    "id": 1
  }'
```

### 方案 3：在 Agent 中使用

创建 OpenClaw agent，使用 `voice_call` 工具：

```python
# Agent 工具调用示例
initiate_call(
    message="你好，我是AI助手",
    to="+15550005678",
    mode="conversation"
)

continue_call(
    callId="xxx",
    message="继续对话"
)

speak_to_user(
    callId="xxx",
    message="单向播放消息"
)

end_call(callId="xxx")
```

## 🎯 支持的 Webhook 事件类型

```json
// 1. 通话应答
{"event": {"type": "call.answered", "callId": "xxx", "timestamp": 123}}

// 2. 用户语音输入
{"event": {
  "type": "call.speech",
  "callId": "xxx",
  "transcript": "用户说的话",
  "isFinal": true,
  "confidence": 0.95,
  "timestamp": 123
}}

// 3. AI 正在说话
{"event": {
  "type": "call.speaking",
  "callId": "xxx",
  "text": "AI说的话",
  "timestamp": 123
}}

// 4. 静默（用户思考）
{"event": {
  "type": "call.silence",
  "callId": "xxx",
  "durationMs": 2000,
  "timestamp": 123
}}

// 5. DTMF 按键
{"event": {
  "type": "call.dtmf",
  "callId": "xxx",
  "digits": "1234",
  "timestamp": 123
}}

// 6. 通话结束
{"event": {
  "type": "call.ended",
  "callId": "xxx",
  "reason": "completed",  // completed | busy | no-answer | failed
  "timestamp": 123
}}

// 7. 错误
{"event": {
  "type": "call.error",
  "callId": "xxx",
  "error": "错误描述",
  "retryable": false,
  "timestamp": 123
}}
```

## 🔧 配置参考

### 基础配置（plugins.entries.voice-call）

```json5
{
  enabled: true,
  // Mock 模式不需要额外配置，自动使用默认值
}
```

### 可选配置（如需自定义）

```json5
{
  plugins: {
    entries: {
      "voice-call": {
        enabled: true,
        provider: "mock",
        fromNumber: "+15550001234",
        toNumber: "+15550005678",
        serve: {
          port: 3334,  // 默认端口
          path: "/voice/webhook"
        },
        outbound: {
          defaultMode: "conversation"  // 或 "notify"
        },
        maxConcurrentCalls: 1  // 默认值
      }
    }
  }
}
```

## 📂 文件位置

- **状态存储**：`~/.openclaw/voice-calls/calls.jsonl`
- **配置文件**：`~/.openclaw/openclaw.json`
- **插件源码**：`~/.nvm/versions/node/v24.13.0/lib/node_modules/openclaw/extensions/voice-call/`

## 🐛 常见问题

### 1. 端口冲突（EADDRINUSE）

**原因**：之前的 webhook 服务器还在运行

**解决**：
```bash
lsof -ti :3334 | xargs kill
```

### 2. 达到并发限制

**原因**：`maxConcurrentCalls = 1`，之前的通话未结束

**解决**：
```bash
# 清空状态文件
> ~/.openclaw/voice-calls/calls.jsonl

# 或发送 call.ended 事件结束通话
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d '{"event":{"type":"call.ended","callId":"xxx","reason":"completed","timestamp":123}}'
```

### 3. CLI 命令端口冲突

**原因**：每个 CLI 命令都尝试启动独立的 webhook 服务器

**解决**：使用方案 2（Gateway RPC）或方案 3（Agent 工具）

## 📝 最佳实践

1. **开发测试**：使用 Mock 模式 + webhook 手动测试
2. **自动化测试**：使用 Mock 模式 + 脚本发送 webhook 事件
3. **生产环境**：切换到 Twilio/Telnyx/Plivo
4. **状态管理**：定期清理 `calls.jsonl`，避免状态累积

## 🎓 学习要点

1. ✅ Mock 模式是**被动的**，需要外部发送 webhook 事件驱动
2. ✅ 状态会**持久化**到 jsonl 文件
3. ✅ CLI 方式适合**单次测试**，不适合交互式多轮对话
4. ✅ Gateway + RPC 是**推荐的生产方式**
5. ✅ 通过 webhook 测试可以**完整验证**所有功能

---

测试时间：2026-02-11
测试状态：✅ 完全通过
Call ID：5512a4c3-d1f5-42de-a879-863f402d6882
