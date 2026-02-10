# 🚀 Clawpal Voice Chat 快速开始

## 一键启动

```bash
cd /Users/botdev/projects/mini-codes/clawpal/voice-chat
bash start.sh
```

服务器启动后会显示：
```
✨ Clawpal Video Bridge 已启动
🔌 WebSocket: ws://localhost:8765
📡 等待浏览器连接...
```

## 使用浏览器界面

### 方式 1: 直接打开文件
```bash
open index.html
```

### 方式 2: 通过 HTTP 服务器（推荐）
```bash
# 使用 Python HTTP 服务器
python3 -m http.server 8000

# 或使用 Node.js http-server
npx http-server -p 8000
```

然后访问：http://localhost:8000

## 聊天交互

### 文本输入
1. 在输入框输入消息（例如："你好"）
2. 按 Enter 或点击"发送"按钮
3. 等待 AI 回复（会显示"思考中..."状态）
4. AI 会用语音回复，自动播放

### 触发关键词
以下文本会触发不同功能：

| 输入内容 | 触发功能 | 效果 |
|---------|---------|------|
| "你好" | 语音消息 | AI 语音回复 |
| "给我讲个故事" | 语音消息 | AI 语音回复 |
| "发张自拍" | 自拍照片 | AI 发送图片（需要 Replicate API） |
| "做个视频" | 视频生成 | AI 生成视频（需要 Replicate API） |

## 工作流程示例

```
你: "早上好，今天天气怎么样？"
  ↓
【思考中...】
  ↓
AI: 🔊 语音播放 "早上好呀！今天天气很不错..."
```

## 状态指示

- 🟢 **已连接** - 可以开始聊天
- 🔵 **思考中...** - AI 正在处理
- 🔴 **说话中...** - AI 正在播放语音
- ⚫ **已断开** - 需要重启服务器

## 常见问题

### 1. WebSocket 连接失败
```bash
# 检查服务器是否运行
lsof -i:8765

# 重启服务器
pkill -f bridge.js
bash start.sh
```

### 2. 无法生成语音
检查 OpenClaw Gateway：
```bash
curl http://localhost:18789/health

# 如果未运行，启动 Gateway
openclaw gateway
```

### 3. 音频无法播放
- 检查浏览器是否允许自动播放
- 尝试手动点击音频播放按钮
- 检查 `/tmp/` 目录是否有生成的 MP3 文件

## 高级配置

### 修改 Agent 目标频道
编辑 `bridge.js`：
```javascript
const CONFIG = {
    AGENT_TARGET: '#你的频道ID',  // 默认 #general
    // ...
};
```

### 修改端口
编辑 `bridge.js`：
```javascript
const CONFIG = {
    WS_PORT: 8888,  // 默认 8765
    // ...
};
```

## 测试命令

### 测试 WebSocket 连接
```bash
node test-connection.js
```

### 手动测试 Agent
```bash
openclaw agent --to "#general" --message "send a voice message: hello" --json --timeout 60000
```

## 目录结构

```
voice-chat/
├── index.html           # 浏览器界面
├── bridge.js            # WebSocket 服务器
├── start.sh             # 启动脚本
├── package.json         # 依赖配置
├── test-connection.js   # 连接测试脚本
├── README.md            # 完整文档
└── QUICKSTART.md        # 本文档
```

## 系统架构

```
┌─────────────┐
│   Browser   │  用户界面
│ (index.html)│
└──────┬──────┘
       │ WebSocket (8765)
       │
┌──────┴──────┐
│  bridge.js  │  Node.js 服务器
└──────┬──────┘
       │ CLI
       │
┌──────┴──────┐
│   openclaw  │  Agent 平台
│    agent    │
└──────┬──────┘
       │ Skill 触发
       │
┌──────┴──────┐
│   Clawpal   │  AI 技能
│  voice.sh   │
└──────┬──────┘
       │ Edge TTS
       │
┌──────┴──────┐
│  /tmp/*.mp3 │  语音文件
└──────┬──────┘
       │ HTTP (8765/media/)
       │
┌──────┴──────┐
│   Browser   │  播放音频
│   <audio>   │
└─────────────┘
```

## 下一步

- [ ] 添加语音识别（Web Speech API）
- [ ] 支持视频回复
- [ ] 添加表情动画
- [ ] 对话历史持久化

## 支持

遇到问题？查看完整文档：[README.md](./README.md)
