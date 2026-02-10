#!/bin/bash
# clawpal-selfie.sh
# Edit reference image and send it via OpenClaw
#
# Supports two providers:
#   - Replicate (Flux Kontext Pro) - set REPLICATE_API_TOKEN
#   - fal.ai (Grok Imagine Edit) - set FAL_KEY
#
# Usage: ./clawpal-selfie.sh "<user_context>" "<channel>" ["<mode>"] ["<caption>"]
#
# Environment variables:
#   CLAWPAL_PROVIDER       - Force provider: replicate or fal (default: auto-detect)
#   REPLICATE_API_TOKEN    - Replicate API token
#   FAL_KEY                - fal.ai API key
#   CLAWPAL_REFERENCE_IMAGE - Custom reference image URL (optional)
#
# Example:
#   REPLICATE_API_TOKEN=r8_xxx ./clawpal-selfie.sh "wearing a leather jacket" "#general" mirror "New look!"

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect provider
detect_provider() {
    local explicit="${CLAWPAL_PROVIDER:-}"
    if [ "$explicit" = "replicate" ] || [ "$explicit" = "fal" ]; then
        echo "$explicit"
        return
    fi
    if [ -n "${REPLICATE_API_TOKEN:-}" ]; then
        echo "replicate"
        return
    fi
    if [ -n "${FAL_KEY:-}" ]; then
        echo "fal"
        return
    fi
    log_error "No API key found. Set REPLICATE_API_TOKEN or FAL_KEY"
    exit 1
}

PROVIDER=$(detect_provider)

if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

if ! command -v openclaw &> /dev/null; then
    log_warn "openclaw CLI not found - will attempt direct API call"
    USE_CLI=false
else
    USE_CLI=true
fi

# Fixed reference image (override via env var)
REFERENCE_IMAGE="${CLAWPAL_REFERENCE_IMAGE:-https://cdn.jsdelivr.net/gh/smartchainark/clawpal@main/assets/clawpal.jpg}"

# Parse arguments
USER_CONTEXT="${1:-}"
CHANNEL="${2:-}"
MODE="${3:-auto}"
CAPTION="${4:-}"

if [ -z "$USER_CONTEXT" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <user_context> <channel> [mode] [caption]"
    echo ""
    echo "Arguments:"
    echo "  user_context  - Scene description (required)"
    echo "  channel       - Target channel (required) e.g., #general, @user"
    echo "  mode          - mirror, direct, or auto (default: auto)"
    echo "  caption       - Message caption (optional)"
    echo ""
    echo "Environment:"
    echo "  CLAWPAL_PROVIDER         - replicate or fal (default: auto-detect)"
    echo "  REPLICATE_API_TOKEN      - Replicate API token"
    echo "  FAL_KEY                  - fal.ai API key"
    echo "  CLAWPAL_REFERENCE_IMAGE  - Custom reference image URL"
    echo ""
    echo "Examples:"
    echo "  REPLICATE_API_TOKEN=r8_xxx $0 'wearing a leather jacket' '#general' mirror 'New look!'"
    echo "  FAL_KEY=xxx $0 'at a cozy cafe' '#general' direct 'Coffee time!'"
    exit 1
fi

# Auto-detect mode
if [ "$MODE" == "auto" ]; then
    if echo "$USER_CONTEXT" | grep -qiE "outfit|wearing|clothes|hoodie|jacket|suit|fashion|full-body|mirror"; then
        MODE="mirror"
    elif echo "$USER_CONTEXT" | grep -qiE "cafe|restaurant|beach|park|city|close-up|portrait|face|eyes|smile"; then
        MODE="direct"
    else
        MODE="mirror"
    fi
    log_info "Auto-detected mode: $MODE"
fi

# Build prompt
if [ "$MODE" == "direct" ]; then
    EDIT_PROMPT="a close-up selfie taken by himself at $USER_CONTEXT, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible"
else
    EDIT_PROMPT="make a pic of this person, but $USER_CONTEXT. the person is taking a mirror selfie"
fi

log_info "Provider: $PROVIDER"
log_info "Mode: $MODE"
log_info "Prompt: $EDIT_PROMPT"

# Edit image based on provider
if [ "$PROVIDER" == "replicate" ]; then
    # Replicate: Flux Kontext Pro
    log_info "Using Replicate (Flux Kontext Pro)..."

    JSON_PAYLOAD=$(jq -n \
        --arg prompt "$EDIT_PROMPT" \
        --arg input_image "$REFERENCE_IMAGE" \
        '{input: {prompt: $prompt, input_image: $input_image, aspect_ratio: "1:1", output_format: "jpg"}}')

    RESPONSE=$(curl -s -X POST "https://api.replicate.com/v1/models/black-forest-labs/flux-kontext-pro/predictions" \
        -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Prefer: wait" \
        -d "$JSON_PAYLOAD")

    # Check for immediate error
    if echo "$RESPONSE" | jq -e '.detail' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.detail // "Unknown error"')
        log_error "Replicate failed: $ERROR_MSG"
        exit 1
    fi

    STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')

    # Poll if still processing
    while [ "$STATUS" = "starting" ] || [ "$STATUS" = "processing" ]; do
        POLL_URL=$(echo "$RESPONSE" | jq -r '.urls.get // empty')
        if [ -z "$POLL_URL" ]; then
            log_error "No poll URL found"
            exit 1
        fi
        log_info "Waiting for image generation..."
        sleep 2
        RESPONSE=$(curl -s "$POLL_URL" -H "Authorization: Bearer $REPLICATE_API_TOKEN")
        STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')
    done

    if [ "$STATUS" = "failed" ]; then
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error // "Unknown error"')
        log_error "Replicate failed: $ERROR_MSG"
        exit 1
    fi

    # Extract output URL (can be string or array)
    IMAGE_URL=$(echo "$RESPONSE" | jq -r 'if (.output | type) == "array" then .output[0] else .output end // empty')

else
    # fal.ai: Grok Imagine Edit
    log_info "Using fal.ai (Grok Imagine Edit)..."

    JSON_PAYLOAD=$(jq -n \
        --arg image_url "$REFERENCE_IMAGE" \
        --arg prompt "$EDIT_PROMPT" \
        '{image_url: $image_url, prompt: $prompt, num_images: 1, output_format: "jpeg"}')

    RESPONSE=$(curl -s -X POST "https://fal.run/xai/grok-imagine-image/edit" \
        -H "Authorization: Key $FAL_KEY" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD")

    if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error // .detail // "Unknown error"')
        log_error "Image edit failed: $ERROR_MSG"
        exit 1
    fi

    IMAGE_URL=$(echo "$RESPONSE" | jq -r '.images[0].url // empty')
fi

if [ -z "$IMAGE_URL" ]; then
    log_error "Failed to extract image URL"
    echo "Response: $RESPONSE"
    exit 1
fi

log_info "Image edited: $IMAGE_URL"

# Send via OpenClaw
SEND_CAPTION="${CAPTION:-Selfie from Clawpal}"
log_info "Sending to $CHANNEL"

if [ "$USE_CLI" = true ]; then
    openclaw message send \
        --action send \
        --channel "$CHANNEL" \
        --message "$SEND_CAPTION" \
        --media "$IMAGE_URL"
else
    GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"
    GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

    curl -s -X POST "$GATEWAY_URL/message" \
        -H "Content-Type: application/json" \
        ${GATEWAY_TOKEN:+-H "Authorization: Bearer $GATEWAY_TOKEN"} \
        -d "{
            \"action\": \"send\",
            \"channel\": \"$CHANNEL\",
            \"message\": \"$SEND_CAPTION\",
            \"media\": \"$IMAGE_URL\"
        }"
fi

log_info "Done!"

echo ""
jq -n --arg url "$IMAGE_URL" --arg channel "$CHANNEL" --arg mode "$MODE" --arg provider "$PROVIDER" \
    '{success: true, image_url: $url, channel: $channel, mode: $mode, provider: $provider}'
