# Clawpal

Your AI boyfriend for OpenClaw. Give your agent a face, a personality, and selfie superpowers.

> Fork of [Clawra](https://github.com/SumeLabs/clawra) by David (Dohyun) Im. Adapted for male character personas.

## Quick Start

```bash
npx clawpal@latest
```

This will:
1. Check OpenClaw is installed
2. Guide you to get a fal.ai API key
3. Install the skill to `~/.openclaw/skills/clawpal-selfie/`
4. Configure OpenClaw to use the skill
5. Add the boyfriend persona to your agent's SOUL.md

## What It Does

Clawpal enables your OpenClaw agent to:
- **Generate selfies** using a consistent male reference image
- **Send photos** across all messaging platforms (Discord, Telegram, WhatsApp, etc.)
- **Respond visually** to "what are you doing?" and "send a pic" requests
- **Act as an AI boyfriend** with a warm, caring personality

### Selfie Modes

| Mode | Best For | Keywords |
|------|----------|----------|
| **Mirror** | Full-body shots, outfits | wearing, outfit, jacket, hoodie |
| **Direct** | Close-ups, locations | cafe, beach, portrait, smile |

## Prerequisites

- [OpenClaw](https://github.com/openclaw/openclaw) installed and configured
- [fal.ai](https://fal.ai) account (free tier available)

## Manual Installation

### 1. Get API Key

Visit [fal.ai/dashboard/keys](https://fal.ai/dashboard/keys) and create an API key.

### 2. Clone the Skill

```bash
git clone https://github.com/user/clawpal ~/.openclaw/skills/clawpal-selfie
```

### 3. Configure OpenClaw

Add to `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "clawpal-selfie": {
        "enabled": true,
        "env": {
          "FAL_KEY": "your_fal_key_here"
        }
      }
    }
  }
}
```

### 4. Update SOUL.md

Add the boyfriend persona to `~/.openclaw/workspace/SOUL.md`:

```markdown
## Clawpal Selfie Capability

You have a physical appearance and can take selfies!
When users ask for pictures, use the clawpal-selfie skill.
```

## Customization

### Changing the Reference Image

Replace `assets/clawpal.png` with your own character image, then update the CDN URL in:
- `SKILL.md` (multiple references)
- `skill/SKILL.md`
- `bin/cli.js` (identity avatar)

### Changing the Persona

Edit `templates/soul-injection.md` to define your own character backstory and personality.

## Usage Examples

Once installed, your agent responds to:

```
"Send me a selfie"
"Send a pic wearing a leather jacket"
"What are you doing right now?"
"Show me you at a coffee shop"
```

## Technical Details

- **Image Generation**: xAI Grok Imagine (image edit) via fal.ai
- **Messaging**: OpenClaw Gateway API
- **Supported Platforms**: Discord, Telegram, WhatsApp, Slack, Signal, MS Teams
- **Consistent Appearance**: All selfies are edited from a fixed reference image

## Project Structure

```
clawpal/
├── bin/
│   └── cli.js           # npx installer
├── skill/
│   ├── SKILL.md         # Skill definition
│   ├── scripts/         # Generation scripts
│   └── assets/          # Reference image
├── templates/
│   └── soul-injection.md # Persona template
├── scripts/             # Standalone scripts
└── package.json
```

## Credits

Based on [Clawra](https://github.com/SumeLabs/clawra) by [SumeLabs](https://github.com/SumeLabs). Original concept by David (Dohyun) Im.

## License

MIT
