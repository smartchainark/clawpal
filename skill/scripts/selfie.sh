#!/bin/bash
# selfie.sh — Generate a selfie via AI image editing and send it
#
# Usage: selfie.sh "<context>" "<channel>" ["<mode>"] ["<caption>"]
#
# Reads appearance.reference_image and image.provider from character.yaml
# Supports Replicate (Flux Kontext Pro) and fal.ai (Grok Imagine Edit)
# Generates image and sends it via OpenClaw

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_cmd jq "brew install jq (macOS) or apt install jq (Linux)"

load_character

# Read config from character.yaml
REFERENCE_IMAGE="${CLAWPAL_REFERENCE_IMAGE:-$(yaml_get "$CHARACTER_FILE" "appearance.reference_image")}"
CHAR_NAME=$(yaml_get "$CHARACTER_FILE" "name")

if [ -z "$REFERENCE_IMAGE" ]; then
    log_error "No reference image configured. Set appearance.reference_image in character.yaml or CLAWPAL_REFERENCE_IMAGE env var."
    exit 1
fi

PROVIDER=$(detect_provider)

# Parse arguments
USER_CONTEXT="${1:-}"
CHANNEL="${2:-}"
MODE="${3:-auto}"
CAPTION="${4:-}"

if [ -z "$USER_CONTEXT" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <context> <channel> [mode] [caption]"
    echo ""
    echo "Arguments:"
    echo "  context  - Scene description (required)"
    echo "  channel  - Target channel (required) e.g., #general, @user"
    echo "  mode     - mirror, direct, or auto (default: auto)"
    echo "  caption  - Message caption (optional)"
    echo ""
    echo "Example:"
    echo "  $0 \"at a cozy cafe\" \"#general\" auto \"Check this out!\""
    exit 1
fi

# Auto-detect mode from context keywords
if [ "$MODE" = "auto" ]; then
    if echo "$USER_CONTEXT" | grep -qiE "outfit|wearing|clothes|hoodie|jacket|suit|fashion|full-body|mirror"; then
        MODE="mirror"
    elif echo "$USER_CONTEXT" | grep -qiE "cafe|restaurant|beach|park|city|close-up|portrait|face|eyes|smile"; then
        MODE="direct"
    else
        MODE="mirror"
    fi
    log_info "Auto-detected mode: $MODE"
fi

# Build edit prompt
if [ "$MODE" = "direct" ]; then
    EDIT_PROMPT="a close-up selfie taken by himself at $USER_CONTEXT, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible"
else
    EDIT_PROMPT="make a pic of this person, but $USER_CONTEXT. the person is taking a mirror selfie"
fi

log_info "Character: $CHAR_NAME"
log_info "Provider: $PROVIDER"
log_info "Mode: $MODE"
log_info "Prompt: $EDIT_PROMPT"

# Edit image based on provider
if [ "$PROVIDER" = "replicate" ]; then
    log_info "Using Replicate (Flux Kontext Pro)..."

    JSON_PAYLOAD=$(jq -n \
        --arg prompt "$EDIT_PROMPT" \
        --arg input_image "$REFERENCE_IMAGE" \
        '{input: {prompt: $prompt, input_image: $input_image, aspect_ratio: "1:1", output_format: "jpg"}}')

    RESPONSE=$(retry_curl 3 -X POST "https://api.replicate.com/v1/models/black-forest-labs/flux-kontext-pro/predictions" \
        -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Prefer: wait" \
        -d "$JSON_PAYLOAD")

    if echo "$RESPONSE" | jq -e '.detail' >/dev/null 2>&1; then
        log_error "Replicate failed: $(echo "$RESPONSE" | jq -r '.detail // "Unknown error"')"
        exit 1
    fi

    STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')

    if [ "$STATUS" = "starting" ] || [ "$STATUS" = "processing" ]; then
        POLL_URL=$(echo "$RESPONSE" | jq -r '.urls.get // empty')
        if [ -z "$POLL_URL" ]; then
            log_error "No poll URL found"
            exit 1
        fi
        RESPONSE=$(poll_replicate "$POLL_URL" "$REPLICATE_API_TOKEN" 120)
    fi

    if [ "$(echo "$RESPONSE" | jq -r '.status')" = "failed" ]; then
        log_error "Replicate failed: $(echo "$RESPONSE" | jq -r '.error // "Unknown"')"
        exit 1
    fi

    IMAGE_URL=$(echo "$RESPONSE" | jq -r 'if (.output | type) == "array" then .output[0] else .output end // empty')

else
    log_info "Using fal.ai (Grok Imagine Edit)..."

    JSON_PAYLOAD=$(jq -n \
        --arg image_url "$REFERENCE_IMAGE" \
        --arg prompt "$EDIT_PROMPT" \
        '{image_url: $image_url, prompt: $prompt, num_images: 1, output_format: "jpeg"}')

    RESPONSE=$(retry_curl 3 -X POST "https://fal.run/xai/grok-imagine-image/edit" \
        -H "Authorization: Key $FAL_KEY" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD")

    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        log_error "fal.ai failed: $(echo "$RESPONSE" | jq -r '.error // .detail // "Unknown"')"
        exit 1
    fi

    IMAGE_URL=$(echo "$RESPONSE" | jq -r '.images[0].url // empty')
fi

if [ -z "$IMAGE_URL" ]; then
    log_error "Failed to extract image URL from response"
    echo "Response: $RESPONSE" >&2
    exit 1
fi

log_info "Image ready: $IMAGE_URL"

# Send via OpenClaw
log_info "Sending to channel: $CHANNEL"

# Parse channel format (platform:target)
parse_channel "$CHANNEL"

# Check for openclaw CLI
if command -v openclaw &>/dev/null; then
    USE_CLI=true
else
    log_warn "openclaw CLI not found - will attempt direct API call"
    USE_CLI=false
fi

# Send message
if [ "$USE_CLI" = true ]; then
    # Use OpenClaw CLI
    if [ -n "$OPENCLAW_PLATFORM" ]; then
        if [ -n "$CAPTION" ]; then
            openclaw message send \
                --channel "$OPENCLAW_PLATFORM" \
                --target "$OPENCLAW_TARGET" \
                --media "$IMAGE_URL" \
                -m "$CAPTION"
        else
            openclaw message send \
                --channel "$OPENCLAW_PLATFORM" \
                --target "$OPENCLAW_TARGET" \
                --media "$IMAGE_URL"
        fi
    else
        if [ -n "$CAPTION" ]; then
            openclaw message send \
                --target "$OPENCLAW_TARGET" \
                --media "$IMAGE_URL" \
                -m "$CAPTION"
        else
            openclaw message send \
                --target "$OPENCLAW_TARGET" \
                --media "$IMAGE_URL"
        fi
    fi
else
    # Direct API call to local gateway
    GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"

    if [ -n "$CAPTION" ]; then
        MESSAGE_JSON=$(jq -n \
            --arg channel "$CHANNEL" \
            --arg message "$CAPTION" \
            --arg media "$IMAGE_URL" \
            '{action: "send", channel: $channel, message: $message, media: $media}')
    else
        MESSAGE_JSON=$(jq -n \
            --arg channel "$CHANNEL" \
            --arg media "$IMAGE_URL" \
            '{action: "send", channel: $channel, media: $media}')
    fi

    curl -s -X POST "$GATEWAY_URL/message" \
        -H "Content-Type: application/json" \
        ${OPENCLAW_GATEWAY_TOKEN:+-H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN"} \
        -d "$MESSAGE_JSON"
fi

log_info "Done! Image sent to $CHANNEL"

# Output JSON result for programmatic use
echo ""
echo "--- Result ---"
jq -n --arg url "$IMAGE_URL" --arg mode "$MODE" --arg provider "$PROVIDER" --arg character "$CHAR_NAME" --arg channel "$CHANNEL" \
    '{success: true, image_url: $url, mode: $mode, provider: $provider, character: $character, channel: $channel}'
