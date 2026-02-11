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

### 📝 文本输入
1. 在输入框输入消息（例如："你好"）
2. 按 Enter 或点击"发送"按钮
3. 等待 AI 回复（会显示"思考中..."状态）
4. AI 会用语音回复，自动播放

### 📷 摄像头拍照（NEW!）
1. 点击"📷 打开摄像头"按钮
2. 允许浏览器访问摄像头（首次需要授权）
3. 看到自己的预览画面（镜像效果）
4. 点击"📸 拍照发送"按钮
5. 照片会立即显示在聊天中
6. AI 会看到你的照片并回复

**隐私提示**：
- 摄像头开启时会显示"摄像头已开启"状态
- 只有点击"拍照发送"才会发送照片
- 随时可以点击"❌ 关闭摄像头"

### 触发关键词
以下文本会触发不同功能：

| 输入内容 | 触发功能 | 效果 |
|---------|---------|------|
| "你好" | 语音消息 | AI 语音回复 |
| "给我讲个故事" | 语音消息 | AI 语音回复 |
| "发张自拍" | 自拍照片 | AI 发送图片（需要 Replicate API） |
| "做个视频" | 视频生成 | AI 生成视频（需要 Replicate API） |

## 工作流程示例

### 语音对话
```
你: "早上好，今天天气怎么样？"
  ↓
【思考中...】
  ↓
AI: 🔊 语音播放 "早上好呀！今天天气很不错..."
```

### 拍照交互（NEW!）
```
你: [点击"打开摄像头"]
  ↓
【摄像头预览画面】
  ↓
你: [点击"拍照发送"]
  ↓
【照片立即显示在聊天中】
  ↓
【AI 正在看你的照片...】
  ↓
AI: 🔊 "哇，你今天穿得很好看啊！这件衣服很适合你。"
```

### 组合使用
```
你: "你看我今天的妆容怎么样？"
  ↓
你: [拍照发送自拍]
  ↓
AI: 🔊 "你的妆容很自然，特别是眼影的颜色选得很棒！"
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

### 4. 摄像头无法打开（NEW!）
**问题**：点击"打开摄像头"后没有反应或报错

**解决方法**：
```bash
# 1. 检查浏览器权限
在浏览器地址栏左侧点击 🔒 或 🎥 图标
→ 网站设置 → 摄像头 → 允许

# 2. 检查摄像头是否被占用
其他应用（Zoom、Skype 等）可能正在使用摄像头
关闭其他应用后重试

# 3. 使用 HTTPS 或 localhost
摄像头需要安全上下文（HTTPS 或 localhost）
确保使用 http://localhost:8765 或 file:// 协议
```

### 5. 照片发送后 AI 没有回复
**检查**：
- 服务器日志是否有错误：`cat /tmp/voice-chat.log`
- 图床上传是否成功（可能需要翻墙）
- OpenClaw Gateway 是否正常运行

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
