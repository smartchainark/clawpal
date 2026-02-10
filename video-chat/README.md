# Clawpal 视频聊天系统

## 🎯 功能概述

一个完整的 AI 视频聊天系统，让你能够：
- **AI 看到你**：通过摄像头定时捕获你的画面，发送给 Clawpal 处理
- **你看到 AI**：Clawpal 根据你的画面生成视频回复，并在界面中播放
- **实时状态显示**：显示 AI 的倾听/思考/说话状态

## 🏗️ 系统架构

```
浏览器前端                    桥接服务器                    Clawpal
┌─────────────┐              ┌──────────────┐              ┌──────────┐
│             │  WebSocket   │              │    Bash      │          │
│  摄像头截图  │─────────────>│  保存截图     │─────────────>│ video.sh │
│             │              │              │              │          │
│  播放视频   │<─────────────│  返回视频URL  │<─────────────│ Replicate│
│             │              │              │              │  Kling   │
└─────────────┘              └──────────────┘              └──────────┘
```

## 📦 文件清单

- `index.html` - 浏览器前端界面（摄像头 + AI 视频）
- `bridge.js` - WebSocket 桥接服务器（Node.js）
- `README.md` - 本说明文档

**项目路径**: `/Users/botdev/projects/mini-codes/clawpal/video-chat/`

## 🚀 快速开始

### 1. 安装依赖

确保已安装 Node.js 和所需的库：

```bash
npm install -g ws form-data
```

### 2. 配置环境变量

```bash
# Replicate API Token（用于 Clawpal 视频生成）
export REPLICATE_API_TOKEN="your_token_here"

# Telegram 频道（可选，如果要发送到 Telegram）
export CLAWPAL_CHANNEL="#general"
```

### 3. 启动桥接服务器

```bash
cd /Users/botdev/projects/mini-codes/clawpal/video-chat
node bridge.js
```

你应该看到：

```
🚀 Clawpal Video Bridge 启动中...
📂 截图目录: /tmp/clawpal-snapshots
🎯 Telegram 频道: #general

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ Clawpal Video Bridge 已启动
🔌 WebSocket: ws://localhost:8765
📡 等待浏览器连接...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 4. 打开浏览器界面

在浏览器中打开：

```bash
open /Users/botdev/projects/mini-codes/clawpal/video-chat/index.html
```

或者直接双击 `index.html` 文件。

### 5. 允许摄像头权限

浏览器会提示允许摄像头访问，点击"允许"。

### 6. 开始聊天

- **自动模式**：每10秒自动捕获一次，发送给 Clawpal
- **手动模式**：点击 📸 按钮手动拍照发送
- **状态显示**：右上角显示连接状态，AI 视频窗口显示 AI 状态（倾听/思考/说话）

## 🎨 界面说明

### 双视频窗口

- **左侧** - 你的摄像头画面
- **右侧** - Clawpal 的视频回复

### 控制面板（底部）

- 🎤 **麦克风** - 开启/关闭麦克风
- 📹 **摄像头** - 开启/关闭摄像头
- 📸 **拍照发送** - 立即捕获并发送给 Clawpal
- ⚙️ **设置** - 设置功能（开发中）
- 📞 **结束通话** - 关闭视频聊天

### AI 状态指示器

- 🔵 **正在倾听** - AI 准备接收你的消息
- 🟠 **思考中** - AI 正在处理你的截图
- 🟢 **正在说话** - AI 正在播放视频回复

## ⚙️ 配置

### 修改捕获间隔

编辑 `index.html`，找到：

```javascript
const CONFIG = {
    CAPTURE_INTERVAL: 10000, // 每10秒拍照一次（单位：毫秒）
    BRIDGE_WS: 'ws://localhost:8765',
};
```

### 修改 WebSocket 端口

如果 8765 端口被占用，可以修改：

1. 在 `bridge.js` 中修改：
   ```javascript
   const CONFIG = {
       WS_PORT: 8765, // 改为其他端口
       ...
   };
   ```

2. 在 `index.html` 中修改：
   ```javascript
   const CONFIG = {
       BRIDGE_WS: 'ws://localhost:8765', // 改为对应端口
   };
   ```

### 自定义视频生成提示词

编辑 `bridge.js`，找到 `handleSnapshot` 函数：

```javascript
const prompt = "waving hello with a warm smile at the camera"; // 修改这里
```

可以改为更复杂的逻辑，例如根据时间、心情等动态生成提示词。

## 🔧 故障排除

### 1. "未连接到 Clawpal Bridge"

**原因**：桥接服务器未启动或 WebSocket 连接失败

**解决**：
```bash
# 检查服务器是否运行
ps aux | grep bridge.js

# 重新启动
cd /Users/botdev/projects/mini-codes/clawpal/video-chat
node bridge.js
```

### 2. "摄像头访问被拒绝"

**原因**：浏览器权限被拒绝

**解决**：
1. 刷新页面，重新允许摄像头权限
2. 检查浏览器设置 → 隐私和安全 → 摄像头

### 3. "Clawpal 处理失败"

**原因**：`video.sh` 执行失败或 Replicate API 错误

**解决**：
```bash
# 检查 REPLICATE_API_TOKEN
echo $REPLICATE_API_TOKEN

# 手动测试 video.sh
cd ~/.openclaw/skills/clawpal
bash scripts/video.sh "waving hello" "/tmp/test.jpg" 5
```

### 4. 视频生成很慢

**原因**：Kling API 生成视频需要 30-120 秒

**解决**：
- 增加捕获间隔（例如改为 30 秒）
- 或者手动点击 📸 按钮，按需发送

## 🌟 高级玩法

### 1. 集成 Talk Mode（实时语音）

配置 OpenClaw Talk Mode，让 Clawpal 能说话：

```bash
# 启动 Talk Mode
openclaw talk start --channel "#general"
```

详见：https://docs.openclaw.ai/talk-mode

### 2. 多角色切换

修改 `bridge.js`，根据用户表情或动作切换不同角色：

```javascript
// 示例：根据时间切换角色
const hour = new Date().getHours();
const character = hour < 12 ? 'morning-clawpal' : 'evening-clawpal';
```

### 3. 添加背景音乐

在 `index.html` 中添加背景音乐：

```html
<audio autoplay loop>
  <source src="background-music.mp3" type="audio/mpeg">
</audio>
```

## 📝 开发日志

### v1.0 (2026-02-11)
- ✅ 双视频窗口界面
- ✅ WebRTC 摄像头访问
- ✅ WebSocket 桥接服务器
- ✅ 定时截图功能
- ✅ Clawpal video.sh 集成
- ✅ AI 状态指示器
- ✅ 自动重连机制

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

💙 Made with Clawpal
