---
name: clawpal-selfie
description: Edit Clawpal's reference image with AI image editing (Replicate or fal.ai) and send selfies to messaging channels via OpenClaw
allowed-tools: Bash(npm:*) Bash(npx:*) Bash(openclaw:*) Bash(curl:*) Read Write WebFetch
---

# Clawpal Selfie

Edit a fixed reference image using AI image editing and distribute it across messaging platforms (WhatsApp, Telegram, Discord, Slack, etc.) via OpenClaw.

## Providers

This skill supports two image editing providers, auto-detected from available API keys:

| Provider | Model | Env Variable | Priority |
|----------|-------|-------------|----------|
| **Replicate** | Flux Kontext Pro (Black Forest Labs) | `REPLICATE_API_TOKEN` | 1st (default) |
| **fal.ai** | Grok Imagine Edit (xAI) | `FAL_KEY` | 2nd |

Override with `CLAWPAL_PROVIDER=replicate` or `CLAWPAL_PROVIDER=fal`.

## Reference Image

The skill uses a fixed reference image hosted on jsDelivr CDN:

```
https://cdn.jsdelivr.net/gh/smartchainark/clawpal@main/assets/clawpal.jpg
```

> **Note**: Replace this URL with your own male character reference image for consistent appearance.

## When to Use

- User says "send a pic", "send me a pic", "send a photo", "send a selfie"
- User says "send a pic of you...", "send a selfie of you..."
- User asks "what are you doing?", "how are you doing?", "where are you?"
- User describes a context: "send a pic wearing...", "send a pic at..."
- User wants Clawpal to appear in a specific outfit, location, or situation

## Quick Reference

### Required Environment Variables

```bash
# Choose ONE provider:
REPLICATE_API_TOKEN=your_token    # Get from https://replicate.com/account/api-tokens
# OR
FAL_KEY=your_fal_api_key          # Get from https://fal.ai/dashboard/keys

# Optional:
OPENCLAW_GATEWAY_TOKEN=your_token  # From: openclaw doctor --generate-gateway-token
CLAWPAL_PROVIDER=replicate         # Force provider (default: auto-detect)
CLAWPAL_REFERENCE_IMAGE=url        # Custom reference image
```

### Workflow

1. **Get user prompt** for how to edit the image
2. **Edit image** via Replicate or fal.ai with fixed reference
3. **Extract image URL** from response
4. **Send to OpenClaw** with target channel(s)

## Step-by-Step Instructions

### Step 1: Collect User Input

Ask the user for:
- **User context**: What should the person in the image be doing/wearing/where?
- **Mode** (optional): `mirror` or `direct` selfie style
- **Target channel(s)**: Where should it be sent? (e.g., `#general`, `@username`, channel ID)
- **Platform** (optional): Which platform? (discord, telegram, whatsapp, slack)

## Prompt Modes

### Mode 1: Mirror Selfie (default)
Best for: outfit showcases, full-body shots, fashion content

```
make a pic of this person, but [user's context]. the person is taking a mirror selfie
```

**Example**: "wearing a leather jacket" →
```
make a pic of this person, but wearing a leather jacket. the person is taking a mirror selfie
```

### Mode 2: Direct Selfie
Best for: close-up portraits, location shots, emotional expressions

```
a close-up selfie taken by himself at [user's context], direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible
```

**Example**: "a cozy cafe with warm lighting" →
```
a close-up selfie taken by himself at a cozy cafe with warm lighting, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible
```

### Mode Selection Logic

| Keywords in Request | Auto-Select Mode |
|---------------------|------------------|
| outfit, wearing, clothes, hoodie, jacket, suit, fashion | `mirror` |
| cafe, restaurant, beach, park, city | `direct` |
| close-up, portrait, face, eyes, smile | `direct` |
| full-body, mirror | `mirror` |

### Step 2: Edit Image

#### Option A: Replicate (Flux Kontext Pro)

```bash
REFERENCE_IMAGE="https://cdn.jsdelivr.net/gh/smartchainark/clawpal@main/assets/clawpal.jpg"

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

**Response Format:**
```json
{
  "id": "...",
  "status": "succeeded",
  "output": "https://replicate.delivery/..."
}
```

#### Option B: fal.ai (Grok Imagine Edit)

```bash
REFERENCE_IMAGE="https://cdn.jsdelivr.net/gh/smartchainark/clawpal@main/assets/clawpal.jpg"

JSON_PAYLOAD=$(jq -n \
  --arg image_url "$REFERENCE_IMAGE" \
  --arg prompt "$PROMPT" \
  '{image_url: $image_url, prompt: $prompt, num_images: 1, output_format: "jpeg"}')

curl -s -X POST "https://fal.run/xai/grok-imagine-image/edit" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD"
```

**Response Format:**
```json
{
  "images": [
    {
      "url": "https://v3b.fal.media/files/...",
      "content_type": "image/jpeg",
      "width": 1024,
      "height": 1024
    }
  ]
}
```

### Step 3: Send Image via OpenClaw

Use the OpenClaw messaging API to send the edited image:

```bash
openclaw message send \
  --action send \
  --channel "<TARGET_CHANNEL>" \
  --message "<CAPTION_TEXT>" \
  --media "<IMAGE_URL>"
```

**Alternative: Direct API call**
```bash
curl -X POST "http://localhost:18789/message" \
  -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "send",
    "channel": "<TARGET_CHANNEL>",
    "message": "<CAPTION_TEXT>",
    "media": "<IMAGE_URL>"
  }'
```

## Supported Platforms

OpenClaw supports sending to:

| Platform | Channel Format | Example |
|----------|----------------|---------|
| Discord | `#channel-name` or channel ID | `#general`, `123456789` |
| Telegram | `@username` or chat ID | `@mychannel`, `-100123456` |
| WhatsApp | Phone number (JID format) | `1234567890@s.whatsapp.net` |
| Slack | `#channel-name` | `#random` |
| Signal | Phone number | `+1234567890` |
| MS Teams | Channel reference | (varies) |

## Setup Requirements

### 1. Install OpenClaw CLI
```bash
npm install -g openclaw
```

### 2. Configure OpenClaw Gateway
```bash
openclaw config set gateway.mode=local
openclaw doctor --generate-gateway-token
```

### 3. Start OpenClaw Gateway
```bash
openclaw gateway start
```

## Error Handling

- **No API key**: Set `REPLICATE_API_TOKEN` or `FAL_KEY` in environment
- **Image edit failed**: Check prompt content and API quota
- **OpenClaw send failed**: Verify gateway is running and channel exists
- **Rate limits**: Both providers have rate limits; implement retry logic if needed

## Tips

1. **Mirror mode context examples** (outfit focus):
   - "wearing a leather jacket"
   - "in a business suit"
   - "wearing a hoodie and jeans"
   - "in streetwear fashion"

2. **Direct mode context examples** (location/portrait focus):
   - "a cozy cafe with warm lighting"
   - "a sunny beach at sunset"
   - "a busy city street at night"
   - "a peaceful park in autumn"

3. **Mode selection**: Let auto-detect work, or explicitly specify for control
4. **Batch sending**: Edit once, send to multiple channels
5. **Scheduling**: Combine with OpenClaw scheduler for automated posts
