# OpenClaw Voice Call Mock 模式测试

测试日期：2026-02-11
测试人：Claude Sonnet 4.5

## 📁 目录内容

```
openclaw-voice-mock-test/
├── README.md                      # 本文件（快速概览）
├── AI-CONVERSATION-SUMMARY.md     # AI 对话功能完整测试总结 ⭐
├── openclaw-mock-voice-usage.md   # Mock 模式使用文档
├── test-mock-complete.sh          # ✅ Mock 基础功能测试（成功）
├── test-ai-conversation.sh        # ❌ Webhook 方式测试 AI（失败）
├── test-ai-with-cli.sh            # ❌ CLI 方式测试 AI（失败）
├── test-ai-with-rpc.sh            # ❌ RPC 方式测试 AI（失败）
├── test-openclaw-voice.sh         # 早期测试脚本
├── call.log                       # 测试日志
└── calls.jsonl.backup             # 状态文件备份
```

## ✅ 测试结果

### 已验证功能

- ✅ Mock provider 可以启动
- ✅ Webhook 服务器正常运行（端口 3334）
- ✅ 可以发起通话并获取 call-id
- ✅ 状态机正常工作（initiated→answered→listening→completed）
- ✅ Webhook 事件处理正常（7种事件类型）
- ✅ 状态持久化到 `~/.openclaw/voice-calls/calls.jsonl`
- ✅ Transcript 记录完整

### AI 对话功能测试（已配置但受架构限制）

✅ **配置已完成**：
- responseModel: `google-antigravity/gemini-3-pro-high`
- responseSystemPrompt: 已设置友好的中文语音助手提示词
- Gateway 已重启并加载新配置

❌ **Mock 模式限制**：
- AI 自动回复**只在实时音频流（streaming）中触发**
- Webhook POST 事件不会自动触发 AI 响应
- CLI 命令端口冲突（每个命令都尝试启动 webhook 服务器）
- 需要真实 Provider（Twilio/Telnyx）+ Streaming 模式才能测试 AI 对话

📖 **详细分析**：请查看 `AI-CONVERSATION-SUMMARY.md`

### 测试发现

1. **Mock 是被动模式**：需要通过 webhook POST 发送事件驱动
2. **CLI 架构限制**：每个命令尝试启动独立 webhook 服务器（端口 3334）
3. **AI 回复触发**：只在 `src/webhook.ts` 的 `onFinalTranscript` 回调中（streaming 专用）
4. **正确测试方式**：保持第一个通话的 webhook 运行，通过 curl 发送事件

## 🎯 测试的 Call ID

```
5512a4c3-d1f5-42de-a879-863f402d6882
```

## 📊 对话记录

```
[bot]  你好，Mock测试
[user] 我想了解OpenClaw
[user] 能详细介绍一下Mock模式吗？
[user] 明白了，谢谢！
```

**注意**：user 消息都是通过 webhook 模拟的，不是真实 AI 对话。

## 🔧 配置位置

- **OpenClaw 配置**：`~/.openclaw/openclaw.json`
- **状态存储**：`~/.openclaw/voice-calls/calls.jsonl`
- **插件目录**：`~/.nvm/versions/node/v24.13.0/lib/node_modules/openclaw/extensions/voice-call/`

## 📖 文档说明

详细使用方法请查看：`openclaw-mock-voice-usage.md`

包含内容：
- Mock 模式工作原理
- 3种使用方案
- 所有支持的事件类型
- 配置参考
- 常见问题解决

## 🚀 快速开始

```bash
# 1. 发起测试通话
./test-mock-complete.sh

# 2. 或手动测试
openclaw voicecall call --to "+15550005678" --message "测试" --mode conversation &

# 3. 发送 webhook 事件
curl -X POST http://127.0.0.1:3334/voice/webhook \
  -H "Content-Type: application/json" \
  -d '{"event":{"type":"call.answered","callId":"YOUR_CALL_ID","timestamp":1234567890000}}'
```

## 📝 关键结论

### Mock 模式能力

✅ **适用场景**：
- 本地开发和测试
- Webhook 事件流程验证
- 状态机逻辑测试
- 不需要真实电话服务商

❌ **不适用场景**：
- AI 自动回复功能测试（需要 streaming）
- 真实的双向 AI 对话
- 多命令交互式操作

### 测试 AI 对话的正确方式

要测试 AI 自动回复功能，需要：
1. 使用真实 Provider（Twilio/Telnyx/Plivo）
2. 启用 Streaming 模式
3. 配置实时音频流

**当前配置**（responseModel、responseSystemPrompt）已正确设置，在真实 Provider 下会正常工作。

## 🔗 相关链接

- 官方文档：https://docs.openclaw.ai/plugins/voice-call
- GitHub：https://github.com/openclaw/openclaw
