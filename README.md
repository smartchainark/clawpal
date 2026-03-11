# Clawpal v2

赛博陪伴，一切皆可。男友、女友、宠物、亲人——给你的 AI 一张脸、一个声音、一段视频。

> 基于 David (Dohyun) Im 的 [Clawra](https://github.com/SumeLabs/clawra) 项目。扩展了语音、视频和多角色支持。

## 快速开始

### 交互式安装

```bash
npx clawpal@latest
```

三步完成：
1. **选择角色** — 或创建你自己的
2. **输入 API 密钥** — Replicate 用于自拍 + 视频（语音免费）
3. **完成** — 开始聊天

### 自动化安装

```bash
# 带全部选项安装
npx clawpal@latest --character girlfriend --replicate-token r8_xxx --yes

# 安装到自定义工作区
npx clawpal@latest --character girlfriend --workspace ~/.openclaw/workspace-chiffon -y

# 可用参数：
#   --character <name>        boyfriend、girlfriend、pet，或 1-3
#   --replicate-token <token> Replicate API 密钥
#   --fal-key <key>          fal.ai API 密钥（Replicate 的替代方案）
#   --reference-image <url>  自定义参考图片 URL
#   --workspace <path>       自定义工作区路径
#   -y, --yes                跳过所有提示
```

## 内置角色

| 角色 | 类型 | 风格 |
|------|------|------|
| **Clawpal** | 赛博男友 | 温暖、体贴、幽默、接地气 |
| **Chiffon** | 赛博女友 | 机智、有创意、好奇心强、略带混乱 |
| **Mochi** | 赛博宠物 | 傲娇、戏精、吃货 |

这些只是起点。你可以创建任何角色——赛博家长、儿时玩伴、虚拟英雄、会说话的植物。一切由一个 `character.yaml` 文件驱动。

## 创建自定义角色

复制模板并编辑：

```bash
cp characters/boyfriend.yaml characters/my-character.yaml
```

在一个文件中定义所有内容：

```yaml
name: Your Character
age: 30
tagline: "你的自定义赛博伴侣"
emoji: "\U0001F916"

appearance:
  reference_image: "https://your-image-url.jpg"
  description: "外貌描述"

voice:
  name: zh-CN-YunxiNeural    # 任意 Edge TTS 语音
  rate: "+0%"
  pitch: "+0Hz"

personality:
  vibe: "描述风格"
  backstory: |
    角色故事...
  traits:
    - 特质一
    - 特质二
  speaking_style: |
    说话方式...
```

## 功能

### 自拍
基于参考图片的 AI 编辑自拍。镜像模式（全身）和直拍模式（特写）。

- **服务商**：Replicate (Flux Kontext Pro) / fal.ai (Grok Imagine Edit)
- **触发方式**："发张自拍给我"、"你在干嘛？"

### 语音
文本转语音消息。免费，无需 API 密钥。

- **引擎**：Microsoft Edge TTS（100+ 种语音，支持多语言）
- **触发方式**："发条语音"、"说声早安"

### 视频
从起始图片生成短视频。

- **模型**：Replicate 上的 Kling v2.6
- **触发方式**："拍个你挥手的视频"、"发个视频"

## 工作原理

```
用户："在咖啡馆发张自拍给我"
  ↓
Agent 读取 SKILL.md → 调用 selfie.sh 并传入频道
  ↓
脚本生成图片 → 通过 OpenClaw 发送 → 用户收到图片
```

脚本负责生成并发送。简单高效。

## 前置条件

- 已安装并配置 [OpenClaw](https://github.com/openclaw/openclaw)
- [Replicate](https://replicate.com) 账号（用于自拍 + 视频）或 [fal.ai](https://fal.ai)（仅自拍）
- Python 3（Edge TTS 会自动安装）

## 手动安装

```bash
# 1. 克隆仓库
git clone https://github.com/smartchainark/clawpal ~/.openclaw/skills/clawpal

# 2. 选择角色
cp characters/boyfriend.yaml ~/.openclaw/skills/clawpal/character.yaml

# 3. 配置（如果文件已存在，请手动编辑合并）
cat > ~/.openclaw/openclaw.json << 'EOF'
{"skills":{"entries":{"clawpal":{"enabled":true,"env":{"REPLICATE_API_TOKEN":"your_token"}}}}}
EOF
```

## 项目结构

```
clawpal/
├── bin/cli.js              # 三步安装器
├── characters/             # 角色模板
│   ├── boyfriend.yaml      # Clawpal — 赛博男友
│   ├── girlfriend.yaml     # Chiffon — 赛博女友
│   └── pet.yaml            # Mochi — 赛博宠物
├── scripts/
│   ├── _common.sh          # 公共工具（YAML 解析、重试、轮询）
│   ├── selfie.sh           # → {image_url}
│   ├── voice.sh            # → {file}
│   └── video.sh            # → {video_url}
├── templates/
│   ├── identity.md.tpl     # 身份模板
│   └── soul-injection.md.tpl
├── skill/                  # 安装后的副本
├── assets/clawpal.jpg      # 默认参考图片
├── SKILL.md                # 技能定义
└── package.json
```

## 致谢

基于 [SumeLabs](https://github.com/SumeLabs) 的 [Clawra](https://github.com/SumeLabs/clawra)。原始概念由 David (Dohyun) Im 设计。

## 许可证

MIT
