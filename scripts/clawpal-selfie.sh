#!/bin/bash
# clawpal-selfie.sh
# Edit reference image with Grok Imagine and send it via OpenClaw
#
# Usage: ./clawpal-selfie.sh "<user_context>" "<channel>" ["<mode>"] ["<caption>"]
#
# Environment variables required:
#   FAL_KEY - Your fal.ai API key
#
# Example:
#   FAL_KEY=your_key ./clawpal-selfie.sh "wearing a leather jacket" "#general" mirror "New look!"

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check required environment variables
if [ -z "${FAL_KEY:-}" ]; then
    log_error "FAL_KEY environment variable not set"
    echo "Get your API key from: https://fal.ai/dashboard/keys"
    exit 1
fi

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
REFERENCE_IMAGE="${CLAWPAL_REFERENCE_IMAGE:-https://cdn.jsdelivr.net/gh/smartchainark/clawpal@main/assets/clawpal.png}"

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
    echo "Examples:"
    echo "  $0 'wearing a leather jacket' '#general' mirror 'New look!'"
    echo "  $0 'at a cozy cafe' '#general' direct 'Coffee time!'"
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

log_info "Mode: $MODE"
log_info "Prompt: $EDIT_PROMPT"

# Edit image via fal.ai Grok Imagine Edit API
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
jq -n --arg url "$IMAGE_URL" --arg channel "$CHANNEL" --arg mode "$MODE" \
    '{success: true, image_url: $url, channel: $channel, mode: $mode}'
