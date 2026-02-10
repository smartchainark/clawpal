---
name: clawpal
description: AI character with selfie, voice, and video via OpenClaw
allowed-tools: Bash(edge-tts:*) Bash(pip3:*) Bash(curl:*) Bash(openclaw:*) Read
---

# Clawpal

AI character skill with selfie generation, voice messages, and video clips. All capabilities are driven by `character.yaml` — a single file that defines the character's appearance, voice, personality, and media settings.

## Character Config

The file `character.yaml` (in the skill directory) defines everything about the character:

```yaml
name: Clawpal            # Character name
age: 22                  # Character age
emoji: "\U0001F499"      # Signature emoji

appearance:
  reference_image: "..."  # URL for selfie/video source image
  description: "..."      # Text description of appearance

voice:
  name: en-US-GuyNeural   # Edge TTS voice ID
  rate: "+0%"             # Speech rate adjustment
  pitch: "+0Hz"           # Pitch adjustment

video:
  model: kwaivgi/kling-v2.5-turbo-pro  # Replicate video model
  duration: 5                           # Default duration (5 or 10)
  aspect_ratio: "1:1"                   # Video aspect ratio

image:
  provider: auto           # replicate, fal, or auto

personality:
  vibe: "..."              # Short personality summary
  backstory: |             # Character backstory
    ...
  traits:                  # List of character traits
    - trait one
    - trait two
  speaking_style: |        # How the character communicates
    ...
```

## Capability Routing

| User Intent | Script | Env Required |
|---|---|---|
| "send a pic/selfie", "what are you doing?" | `selfie.sh` | `REPLICATE_API_TOKEN` or `FAL_KEY` |
| "send a voice message", "say this" | `voice.sh` | None (Edge TTS is free) |
| "send a video clip", "make a video" | `video.sh` | `REPLICATE_API_TOKEN` |

## Selfie Generation

**Script:** `scripts/selfie.sh "<context>" "<channel>" ["<mode>"] ["<caption>"]`

Edit the character's reference image using AI and send it via OpenClaw.

### Providers

| Provider | Model | Env Variable | Priority |
|----------|-------|-------------|----------|
| **Replicate** | Flux Kontext Pro | `REPLICATE_API_TOKEN` | 1st |
| **fal.ai** | Grok Imagine Edit | `FAL_KEY` | 2nd |

Override with `CLAWPAL_PROVIDER=replicate` or `CLAWPAL_PROVIDER=fal`.

### Selfie Modes

| Mode | Best For | Auto-detect Keywords |
|------|----------|---------------------|
| **mirror** | Full-body, outfits | wearing, outfit, clothes, hoodie, jacket, suit, fashion, full-body, mirror |
| **direct** | Close-ups, locations | cafe, restaurant, beach, park, city, close-up, portrait, face, eyes, smile |

### Prompt Templates

**Mirror mode:**
```
make a pic of this person, but [context]. the person is taking a mirror selfie
```

**Direct mode:**
```
a close-up selfie taken by himself at [context], direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible
```

### Example: Replicate API

```bash
JSON_PAYLOAD=$(jq -n \
  --arg prompt "$PROMPT" \
  --arg input_image "$REFERENCE_IMAGE" \
  '{input: {prompt: $prompt, input_image: $input_image, aspect_ratio: "1:1", output_format: "jpg"}}')

curl -s -X POST "https://api.replicate.com/v1/models/black-forest-labs/flux-kontext-pro/predictions" \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d "$JSON_PAYLOAD"
```

### Example: fal.ai API

```bash
JSON_PAYLOAD=$(jq -n \
  --arg image_url "$REFERENCE_IMAGE" \
  --arg prompt "$PROMPT" \
  '{image_url: $image_url, prompt: $prompt, num_images: 1, output_format: "jpeg"}')

curl -s -X POST "https://fal.run/xai/grok-imagine-image/edit" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD"
```

## Voice Messages

**Script:** `scripts/voice.sh "<text>" "<channel>" ["<caption>"]`

Generate speech using Edge TTS (free, no API key) and send via OpenClaw.

### Voice Configuration

Voices are configured per-character in `character.yaml`:

| Character | Voice ID | Notes |
|-----------|----------|-------|
| Clawpal (boyfriend) | `en-US-GuyNeural` | Warm male voice |
| Luna (girlfriend) | `en-US-JennyNeural` | Expressive female voice |
| Mochi (pet cat) | `en-US-AnaNeural` | Child-like, higher pitch |

### Parameters

- `voice.name` — Edge TTS voice ID (see `edge-tts --list-voices`)
- `voice.rate` — Speed adjustment: `"-10%"` slower, `"+10%"` faster
- `voice.pitch` — Pitch shift: `"+20Hz"` higher, `"-20Hz"` lower

### Flow

1. Read voice config from `character.yaml`
2. Generate MP3 via `edge-tts`
3. Upload to `0x0.st` for public URL (fallback: `transfer.sh`)
4. Send via OpenClaw

### Dependencies

- `edge-tts` — auto-installed via `pip3 install edge-tts` if missing
- Fallback: `python3 -m edge_tts` if not on PATH

## Video Clips

**Script:** `scripts/video.sh "<prompt>" "<channel>" ["<source_image>"] ["<duration>"]`

Generate short video clips using Kling v2.5 on Replicate and send via OpenClaw.

### Configuration

- `video.model` — Replicate model (default: `kwaivgi/kling-v2.5-turbo-pro`)
- `video.duration` — 5 or 10 seconds
- `video.aspect_ratio` — `"1:1"`, `"16:9"`, `"9:16"`

### Flow

1. Read video config from `character.yaml`
2. Use character's `appearance.reference_image` as start frame (or custom image)
3. Submit to Replicate Kling API
4. Poll for completion (typically 30-120 seconds, 5-minute timeout)
5. Send video URL via OpenClaw

### API Call

```bash
jq -n --arg prompt "$PROMPT" --arg start_image "$IMAGE" \
      --argjson duration $DURATION --arg aspect_ratio "$RATIO" \
  '{input: {prompt: $prompt, start_image: $start_image, duration: $duration, aspect_ratio: $aspect_ratio}}'

curl -s -X POST "https://api.replicate.com/v1/models/kwaivgi/kling-v2.5-turbo-pro/predictions" \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD"
```

**Note:** Video generation takes 30-120 seconds. The script polls every 3 seconds and times out at 5 minutes.

## Sending via OpenClaw

All scripts send media through OpenClaw:

```bash
openclaw message send \
  --action send \
  --channel "<TARGET_CHANNEL>" \
  --message "<CAPTION>" \
  --media "<MEDIA_URL>"
```

**Direct API fallback:**
```bash
curl -X POST "http://localhost:18789/message" \
  -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"send","channel":"<CHANNEL>","message":"<CAPTION>","media":"<URL>"}'
```

## Combined Examples

**Selfie + voice note:**
```bash
scripts/selfie.sh "at a cozy cafe" "#general" direct "Coffee time!"
scripts/voice.sh "Hey! Just grabbed a latte, wish you were here" "#general"
```

**Video selfie with narration:**
```bash
scripts/video.sh "waving hello with a warm smile, cozy cafe background" "#general"
scripts/voice.sh "Hey you! Just wanted to say hi" "#general"
```

## Environment Variables

| Variable | Required For | Description |
|----------|-------------|-------------|
| `REPLICATE_API_TOKEN` | selfie (option 1), video | Replicate API token |
| `FAL_KEY` | selfie (option 2) | fal.ai API key |
| `CLAWPAL_PROVIDER` | — | Force image provider: `replicate` or `fal` |
| `CLAWPAL_REFERENCE_IMAGE` | — | Override reference image URL |
| `OPENCLAW_GATEWAY_URL` | — | Gateway URL (default: `http://localhost:18789`) |
| `OPENCLAW_GATEWAY_TOKEN` | — | Gateway auth token |

## Supported Platforms

| Platform | Channel Format | Example |
|----------|----------------|---------|
| Discord | `#channel-name` or channel ID | `#general` |
| Telegram | `@username` or chat ID | `@mychannel` |
| WhatsApp | Phone number (JID) | `1234567890@s.whatsapp.net` |
| Slack | `#channel-name` | `#random` |
| Signal | Phone number | `+1234567890` |
| MS Teams | Channel reference | (varies) |

## Error Handling

- **No API key**: Set `REPLICATE_API_TOKEN` or `FAL_KEY`
- **edge-tts missing**: Auto-installed; fallback `python3 -m edge_tts`
- **Upload failed**: Tries `0x0.st` then `transfer.sh`
- **Video timeout**: Kling may take up to 2 minutes; 5-minute timeout
- **No reference image**: Selfie disabled; voice + video still work
