# Clawpal v2

AI character with selfie, voice, and video for OpenClaw. Pick a character, enter an API key, and go.

> Fork of [Clawra](https://github.com/SumeLabs/clawra) by David (Dohyun) Im. Extended with voice, video, and multi-character support.

## Quick Start

```bash
npx clawpal@latest
```

3-step installer:
1. **Pick a character** — Clawpal (boyfriend), Luna (girlfriend), or Mochi (cat)
2. **Enter API key** — Replicate token for selfie + video (voice is free)
3. **Done** — skill installed, character configured, ready to chat

## Characters

| Character | Type | Vibe |
|-----------|------|------|
| **Clawpal** | Boyfriend | Warm, caring, funny, down-to-earth |
| **Luna** | Girlfriend | Witty, creative, curious, slightly chaotic |
| **Mochi** | Pet cat | Sassy, dramatic, food-motivated |

Each character comes with a complete personality, backstory, speaking style, voice settings, and appearance description defined in `character.yaml`.

## Capabilities

### Selfie Generation
Generate AI-edited selfies using a reference image. Supports mirror selfies (full-body) and direct selfies (close-up).

- **Providers**: Replicate (Flux Kontext Pro) or fal.ai (Grok Imagine Edit)
- **Trigger**: "Send me a selfie", "What are you doing?"

### Voice Messages
Generate speech from text using Edge TTS. Free, no API key needed.

- **Voices**: Character-specific (male, female, child-like)
- **Trigger**: "Send a voice message", "Say hello"

### Video Clips
Generate short video clips using Kling v2.5 on Replicate.

- **Duration**: 5 or 10 seconds
- **Trigger**: "Make a video of you waving", "Send a video clip"

## Prerequisites

- [OpenClaw](https://github.com/openclaw/openclaw) installed and configured
- [Replicate](https://replicate.com) account (for selfie + video) or [fal.ai](https://fal.ai) account (selfie only)
- Python 3 (for Edge TTS voice generation — auto-installed)

## Manual Installation

### 1. Clone

```bash
git clone https://github.com/smartchainark/clawpal ~/.openclaw/skills/clawpal
```

### 2. Choose a Character

Copy one of the built-in templates:

```bash
cp characters/boyfriend.yaml ~/.openclaw/skills/clawpal/character.yaml
# or: girlfriend.yaml, pet.yaml
```

### 3. Configure OpenClaw

Add to `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "clawpal": {
        "enabled": true,
        "env": {
          "REPLICATE_API_TOKEN": "your_token_here"
        }
      }
    }
  }
}
```

## Customization

### Custom Character

Edit `character.yaml` to change any aspect — name, personality, voice, appearance, video settings. All scripts read from this single config file.

### Custom Reference Image

Set `appearance.reference_image` in `character.yaml` to your own image URL, or use the `CLAWPAL_REFERENCE_IMAGE` environment variable.

### Voice Tuning

Adjust `voice.name`, `voice.rate`, and `voice.pitch` in `character.yaml`. Run `edge-tts --list-voices` to see all available voices.

## Project Structure

```
clawpal/
├── bin/cli.js              # 3-step installer
├── characters/             # Built-in character templates
│   ├── boyfriend.yaml      # Clawpal
│   ├── girlfriend.yaml     # Luna
│   └── pet.yaml            # Mochi
├── scripts/
│   ├── _common.sh          # Shared helpers + YAML parser
│   ├── selfie.sh           # Selfie generation
│   ├── voice.sh            # Voice message generation
│   └── video.sh            # Video clip generation
├── templates/
│   ├── identity.md.tpl     # Identity template
│   └── soul-injection.md.tpl  # Persona template
├── skill/                  # Installed skill copy
├── assets/clawpal.jpg      # Default reference image
├── SKILL.md                # Skill definition
└── package.json
```

## Usage Examples

```
"Send me a selfie"
"Send a pic wearing a leather jacket"
"What are you doing right now?"
"Send a voice message saying good morning"
"Make a video of you waving"
"Send a video selfie at the beach with a voice note"
```

## Credits

Based on [Clawra](https://github.com/SumeLabs/clawra) by [SumeLabs](https://github.com/SumeLabs). Original concept by David (Dohyun) Im.

## License

MIT
