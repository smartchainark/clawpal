# 🎙️ Clawpal Voice Chat

**AI 语音聊天系统** - 通过浏览器与 Clawpal AI 男友进行实时语音交互。

## ✨ 功能特性

- 🗣️ **实时语音交互** - 文本输入，AI 语音回复
- 🎭 **角色扮演** - Clawpal AI 男友人格
- 🔊 **Edge TTS 语音合成** - 自然流畅的语音回复
- 💬 **聊天历史** - 记录对话内容
- 🎨 **现代 UI** - 简洁美观的聊天界面
- 📸 **可选截图上下文** - 支持发送截图给 AI（开发中）

## 🏗️ 架构

```
Browser (index.html)
    ↕️ WebSocket
bridge.js (Node.js)
    ↕️ CLI
openclaw agent
    ↕️ 触发
Clawpal skill (voice.sh)
    ↕️ 生成
Edge TTS → MP3 文件
    ↕️ HTTP
Browser 播放
```

## 📦 依赖

### 必需
- **Node.js** v16+
- **OpenClaw CLI** (`npm install -g openclaw`)
- **Clawpal Skill** (已安装在 `~/.openclaw/skills/clawpal/`)

### 自动安装
- `ws` (WebSocket 库) - start.sh 自动安装
- `edge-tts` (Edge TTS Python 库) - Clawpal skill 自动安装

## 🚀 快速开始

### 1. 启动服务器

```bash
cd /Users/botdev/projects/mini-codes/clawpal/voice-chat
bash start.sh
```

服务器启动后会显示：

```
🚀 Clawpal Voice Chat 启动
🔌 WebSocket: ws://localhost:8765
🌐 Web UI: http://localhost:8765
```

### 2. 打开浏览器

访问：http://localhost:8765

或直接打开 `index.html` 文件（需要确保 WebSocket 服务在 8765 端口）

### 3. 开始聊天

- **方式 1**：在输入框输入文字，按回车或点击"发送"
- **方式 2**：点击"按住说话"按钮录制语音（开发中）

## 📝 工作流程

1. **用户输入** → 浏览器发送文本到 bridge.js
2. **AI 处理** → bridge.js 调用 `openclaw agent` CLI
3. **触发技能** → OpenClaw 识别"send a voice message"触发 Clawpal skill
4. **生成语音** → Clawpal 的 `voice.sh` 调用 Edge TTS 生成 MP3
5. **返回结果** → Agent 返回 JSON 包含音频路径（格式：`MEDIA: /tmp/xxx.mp3`）
6. **提取路径** → bridge.js 解析路径，转换为 HTTP URL
7. **播放音频** → 浏览器接收 URL，自动播放语音

## 🔧 配置

### 环境变量

在 `~/.openclaw/openclaw.json` 或环境变量中配置：

```bash
# Telegram 频道（可选）
export CLAWPAL_CHANNEL="#general"

# Replicate API（视频功能需要）
export REPLICATE_API_TOKEN="your_token_here"
```

### bridge.js 配置

```javascript
const CONFIG = {
    WS_PORT: 8765,              // WebSocket 端口
    AGENT_TARGET: '#general',   // OpenClaw agent 目标频道
    AGENT_TIMEOUT: 60000,       // Agent 超时时间（毫秒）
    SNAPSHOT_DIR: '/tmp/clawpal-snapshots'  // 截图保存目录
};
```

## 📂 文件结构

```
voice-chat/
├── bridge.js         # WebSocket + HTTP 服务器
├── index.html        # 浏览器前端界面
├── package.json      # Node.js 依赖
├── start.sh          # 启动脚本
└── README.md         # 本文档
```

## 🐛 故障排查

### 问题 1：WebSocket 连接失败

**解决方法**：
```bash
# 检查服务器是否运行
lsof -i:8765

# 重启服务器
pkill -f bridge.js
bash start.sh
```

### 问题 2：无法生成语音

**检查**：
- OpenClaw Gateway 是否运行：`openclaw gateway status`
- Clawpal skill 是否安装：`openclaw skills list | grep clawpal`
- Edge TTS 是否安装：`pip3 list | grep edge-tts`

**手动测试**：
```bash
# 测试 agent 调用
openclaw agent --to "#general" --message "send a voice message: hello" --json --timeout 60000

# 应返回类似：
# {"status":"ok","result":{"payloads":[{"text":"MEDIA: /tmp/hello-voice.mp3"}]}}
```

### 问题 3：音频无法播放

**检查**：
- 音频文件是否存在：`ls /tmp/*.mp3`
- HTTP 服务器是否正常：访问 `http://localhost:8765/media/xxx.mp3`
- 浏览器控制台是否有错误

## 🎯 触发关键词

以下关键词会触发 Clawpal 的不同功能：

- **语音消息** - "send a voice message", "say", "tell me"
- **视频生成** - "make a video", "create a video"
- **自拍照片** - "send a pic", "send a selfie"

## 🔮 未来功能

- [ ] 实时语音识别（Web Speech API）
- [ ] 视频回复功能（Replicate Kling）
- [ ] 截图上下文感知
- [ ] 表情动画
- [ ] 对话历史持久化
- [ ] 多语言支持

## 📜 许可证

MIT License

---

**技术栈**：Node.js · WebSocket · Edge TTS · OpenClaw · Clawpal
