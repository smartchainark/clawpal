#!/bin/bash
# selfie.sh — Generate a selfie via AI image editing
#
# Usage: selfie.sh "<context>" ["<mode>"]
#
# Reads appearance.reference_image and image.provider from character.yaml
# Supports Replicate (Flux Kontext Pro) and fal.ai (Grok Imagine Edit)
# Outputs the image URL — sending is handled by the agent

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
MODE="${2:-auto}"

if [ -z "$USER_CONTEXT" ]; then
    echo "Usage: $0 <context> [mode]"
    echo ""
    echo "Arguments:"
    echo "  context  - Scene description (required)"
    echo "  mode     - mirror, direct, or auto (default: auto)"
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
    echo "Response: $RESPONSE"
    exit 1
fi

log_info "Image ready: $IMAGE_URL"

# Output JSON result for the agent
jq -n --arg url "$IMAGE_URL" --arg mode "$MODE" --arg provider "$PROVIDER" --arg character "$CHAR_NAME" \
    '{success: true, image_url: $url, mode: $mode, provider: $provider, character: $character}'
