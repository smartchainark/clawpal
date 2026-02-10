# Clawpal 视频聊天 v2 - OpenClaw Agent 最佳实践

## 🎯 v2 架构（推荐）

使用 **`openclaw agent`** 命令的最佳实践架构，**无需上传图片到公共图床**。

```
浏览器摄像头 → 截图保存到本地
              ↓
      openclaw agent --json
              ↓
      Agent 处理图片并生成回复
              ↓
      返回 JSON: {payloads: [{text, mediaUrl}]}
              ↓
      浏览器显示文本/视频
```

## ✅ v2 优势

1. **隐私安全** - 图片只保存在本地，不上传到公共图床
2. **简单可靠** - 直接使用 OpenClaw agent 命令，无需额外 API
3. **统一架构** - 与 OpenClaw 生态完全集成
4. **灵活回复** - 支持文本和媒体（视频/图片）回复

## 📦 文件清单

- `bridge-v2.js` - v2 桥接服务器（使用 openclaw agent）
- `index.html` - 浏览器界面（已更新支持 v2）
- `start-v2.sh` - v2 启动脚本
- `README-v2.md` - 本文档

## 🚀 快速启动

### 1. 确保 OpenClaw Gateway 运行中

```bash
# 检查 Gateway 状态
openclaw gateway status

# 如果未运行，启动它
openclaw gateway
```

### 2. 启动 v2 桥接服务器

```bash
cd /Users/botdev/projects/mini-codes/clawpal/video-chat
./start-v2.sh
```

### 3. 打开浏览器界面

```bash
open /Users/botdev/projects/mini-codes/clawpal/video-chat/index.html
```

## 🔄 工作流程

1. **浏览器截图** → 每10秒自动或点击 📸 按钮
2. **保存到本地** → `/tmp/clawpal-snapshots/snapshot-{timestamp}.jpg`
3. **调用 agent** → `openclaw agent --to "#general" --message "..." --json`
4. **Agent 处理** → Clawpal 查看图片，生成回复（文本或视频）
5. **返回结果** → `{payloads: [{text, mediaUrl}]}`
6. **浏览器显示** → 播放视频或显示文本

## ⚙️ 配置

编辑 `bridge-v2.js`：

```javascript
const CONFIG = {
    WS_PORT: 8765,                    // WebSocket 端口
    SNAPSHOT_DIR: '/tmp/clawpal-snapshots',  // 截图目录
    AGENT_TARGET: '#general',         // Agent 目标频道
    AGENT_TIMEOUT: 120,               // Agent 超时（秒）
};
```

## 🆚 v1 vs v2 对比

| 特性 | v1 (bridge.js) | v2 (bridge-v2.js) |
|------|----------------|-------------------|
| **图片处理** | 上传到公共图床 | 保存在本地 |
| **隐私性** | ❌ 图片公开 | ✅ 图片私密 |
| **依赖** | 需要图床 API | 只需 OpenClaw |
| **稳定性** | 依赖第三方服务 | 完全本地控制 |
| **集成度** | 独立系统 | OpenClaw 原生 |
| **推荐** | ❌ 不推荐 | ✅ **推荐** |

## 🔧 故障排除

### 1. "未找到 OpenClaw CLI"

**解决**：
```bash
# 检查 OpenClaw 是否安装
openclaw --version

# 如果未安装，参考 https://docs.openclaw.ai/install
```

### 2. "OpenClaw Gateway 未运行"

**解决**：
```bash
# 启动 Gateway
openclaw gateway

# 或后台运行
openclaw gateway &
```

### 3. "Agent 未返回任何内容"

**原因**：Agent 可能没有正确处理图片

**解决**：
- 检查 Clawpal skill 是否安装
- 查看 agent 日志：`openclaw logs --follow`
- 确保 `REPLICATE_API_TOKEN` 已设置（如果使用视频生成）

## 📝 开发日志

### v2.0 (2026-02-11)
- ✅ 使用 `openclaw agent` 命令
- ✅ 本地图片处理（无需上传）
- ✅ 解析 agent JSON 输出
- ✅ 支持文本和媒体回复
- ✅ 完全隐私安全

## 💡 下一步

- [ ] 添加语音识别（配合 Talk Mode）
- [ ] 支持多轮对话历史
- [ ] 添加表情/情绪检测
- [ ] 支持多角色切换

---

💙 Made with Clawpal + OpenClaw
