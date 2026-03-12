# Clawpal v2

Your AI companion — boyfriend, girlfriend, pet, or anyone you want. Give your AI a face, a voice, and presence.

Cyber companion skill for OpenClaw with selfie, voice, and video capabilities.

> Fork of [Clawra](https://github.com/SumeLabs/clawra) by David (Dohyun) Im. Extended with voice, video, and multi-character support.

## Quick Start

### Interactive Installation

```bash
npx clawpal@latest
```

3 steps:
1. **Pick a character** — or create your own
2. **Choose model** — Tencent Hunyuan / Replicate / fal.ai
3. **Done** — start chatting

### Automated Installation

```bash
# Tencent Hunyuan
npx clawpal@latest --character girlfriend --tencent-id AKIDxxx --tencent-key xxx --yes

# Replicate
npx clawpal@latest --character girlfriend --replicate-token r8_xxx --yes

# Custom workspace
npx clawpal@latest --character girlfriend --workspace ~/.openclaw/workspace-chiffon -y

# Available flags:
#   --character <name>        boyfriend, girlfriend, pet, or 1-3
#   --tencent-id <id>        Tencent Cloud SecretId (selfie)
#   --tencent-key <key>      Tencent Cloud SecretKey
#   --replicate-token <token> Replicate API token (selfie + video)
#   --fal-key <key>          fal.ai API key (selfie)
#   --reference-image <url>  Custom reference image URL
#   --workspace <path>       Custom workspace path
#   -y, --yes                Skip all prompts
```

## Built-in Characters

| Character | Type | Vibe |
|-----------|------|------|
| **Clawpal** | Cyber Boyfriend | Warm, caring, funny, down-to-earth |
| **Chiffon** | Cyber Girlfriend | Witty, creative, curious, slightly chaotic |
| **Mochi** | Cyber Pet | Sassy, dramatic, food-motivated |

These are just starting points. Create any character you want — a cyber parent, a childhood friend, a fictional hero, a talking plant. Everything is driven by one `character.yaml` file.

## Create Your Own Character

Copy a template and edit:

```bash
cp characters/boyfriend.yaml characters/my-character.yaml
```

Define everything in one file:

```yaml
name: Your Character
age: 30
tagline: "Your custom cyber companion"
emoji: "\U0001F916"

appearance:
  reference_image: "https://your-image-url.jpg"
  description: "How they look"

voice:
  name: en-US-GuyNeural    # Any Edge TTS voice
  rate: "+0%"
  pitch: "+0Hz"

personality:
  vibe: "describe the vibe"
  backstory: |
    Their story...
  traits:
    - trait one
    - trait two
  speaking_style: |
    How they talk...
```

## Capabilities

### Selfie
AI-edited selfies from a reference image. Mirror mode (full-body) and direct mode (close-up).

- **Providers**: Tencent Hunyuan 3.0 / Replicate (Flux Kontext Pro) / fal.ai (Grok Imagine Edit)
- **Trigger**: "Send me a selfie", "What are you doing?"

### Voice
Text-to-speech voice messages. Free, no API key needed.

- **Engine**: Microsoft Edge TTS (100+ voices, multilingual)
- **Trigger**: "Send a voice message", "Say good morning"

### Video
Short video clips from a start image.

- **Model**: Kling v2.6 on Replicate
- **Trigger**: "Make a video of you waving", "Send a video clip"

## How It Works

```
User: "Send me a selfie at a cafe"
  ↓
Agent reads SKILL.md → calls selfie.sh with channel
  ↓
Script generates image → sends via OpenClaw → user receives it
```

Scripts generate AND send. Direct and efficient.

## Prerequisites

- [OpenClaw](https://github.com/openclaw/openclaw) installed and configured
- Image provider (choose one):
  - [Tencent Cloud](https://console.cloud.tencent.com/cam/capi) — Hunyuan 3.0 (selfie)
  - [Replicate](https://replicate.com) — selfie + video
  - [fal.ai](https://fal.ai) — selfie only
- Python 3 (Edge TTS auto-installs)

## Manual Installation

```bash
# 1. Clone
git clone https://github.com/smartchainark/clawpal ~/.openclaw/skills/clawpal

# 2. Pick a character
cp characters/boyfriend.yaml ~/.openclaw/skills/clawpal/character.yaml

# 3. Configure (add to your openclaw.json)
```

Add this to `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "clawpal": {
        "enabled": true,
        "env": {
          "TENCENT_SECRET_ID": "your_id",
          "TENCENT_SECRET_KEY": "your_key"
        }
      }
    }
  }
}
```

Or for overseas users:

```json
{
  "skills": {
    "entries": {
      "clawpal": {
        "enabled": true,
        "env": {
          "REPLICATE_API_TOKEN": "your_token"
        }
      }
    }
  }
}
```

## Project Structure

```
clawpal/
├── bin/cli.js              # 3-step installer
├── characters/             # Character templates
│   ├── boyfriend.yaml      # Clawpal — cyber boyfriend
│   ├── girlfriend.yaml     # Chiffon — cyber girlfriend
│   └── pet.yaml            # Mochi — cyber pet
├── skill/scripts/
│   ├── _common.sh          # Shared helpers (YAML parser, retry, polling)
│   ├── selfie.sh           # → {image_url}
│   ├── voice.sh            # → {file}
│   ├── video.sh            # → {video_url}
│   └── hunyuan-selfie.mjs  # Tencent Hunyuan API
├── templates/
│   ├── identity.md.tpl     # Identity template
│   └── soul-injection.md.tpl
├── skill/                  # Installed copy
├── assets/clawpal.jpg      # Default reference image
├── SKILL.md                # Skill definition
└── package.json
```

## Credits

Based on [Clawra](https://github.com/SumeLabs/clawra) by [SumeLabs](https://github.com/SumeLabs). Original concept by David (Dohyun) Im.

## License

MIT
