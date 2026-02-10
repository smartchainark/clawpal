#!/bin/bash
# video.sh — Generate a video clip via Replicate (Kling v2.6) and send it
#
# Usage: video.sh "<prompt>" "<channel>" ["<caption>"] ["<source_image>"] ["<duration>"]
#
# Reads video config from character.yaml
# Requires REPLICATE_API_TOKEN
# Generates video and sends it via OpenClaw

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_cmd jq "brew install jq (macOS) or apt install jq (Linux)"

load_character

# Read config from character.yaml
VIDEO_MODEL=$(yaml_get "$CHARACTER_FILE" "video.model")
DEFAULT_DURATION=$(yaml_get "$CHARACTER_FILE" "video.duration")
ASPECT_RATIO=$(yaml_get "$CHARACTER_FILE" "video.aspect_ratio")
REFERENCE_IMAGE=$(yaml_get "$CHARACTER_FILE" "appearance.reference_image")
CHAR_NAME=$(yaml_get "$CHARACTER_FILE" "name")

VIDEO_MODEL="${VIDEO_MODEL:-kwaivgi/kling-v2.6}"
DEFAULT_DURATION="${DEFAULT_DURATION:-5}"
ASPECT_RATIO="${ASPECT_RATIO:-16:9}"

# Parse arguments
PROMPT="${1:-}"
CHANNEL="${2:-}"
CAPTION="${3:-}"
SOURCE_IMAGE="${4:-$REFERENCE_IMAGE}"
DURATION="${5:-$DEFAULT_DURATION}"

if [ -z "$PROMPT" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <prompt> <channel> [caption] [source_image] [duration]"
    echo ""
    echo "Arguments:"
    echo "  prompt        - Video description (required)"
    echo "  channel       - Target channel (required) e.g., #general, @user"
    echo "  caption       - Message caption (optional)"
    echo "  source_image  - Start image URL (default: character reference image)"
    echo "  duration      - Duration in seconds: 5 or 10 (default: $DEFAULT_DURATION)"
    echo ""
    echo "Example:"
    echo "  $0 \"waving hello with a warm smile\" \"#general\" \"Check this out!\""
    echo ""
    echo "Requires: REPLICATE_API_TOKEN"
    exit 1
fi

if [ -z "${REPLICATE_API_TOKEN:-}" ]; then
    log_error "REPLICATE_API_TOKEN is required for video generation"
    exit 1
fi

log_info "Character: $CHAR_NAME"
log_info "Model: $VIDEO_MODEL"
log_info "Prompt: $PROMPT"
log_info "Duration: ${DURATION}s | Aspect: $ASPECT_RATIO"
[ -n "$SOURCE_IMAGE" ] && log_info "Source image: $SOURCE_IMAGE"

# Build request payload
if [ -n "$SOURCE_IMAGE" ]; then
    JSON_PAYLOAD=$(jq -n \
        --arg prompt "$PROMPT" \
        --arg start_image "$SOURCE_IMAGE" \
        --argjson duration "$DURATION" \
        --arg aspect_ratio "$ASPECT_RATIO" \
        '{input: {prompt: $prompt, start_image: $start_image, duration: $duration, aspect_ratio: $aspect_ratio, generate_audio: false}}')
else
    JSON_PAYLOAD=$(jq -n \
        --arg prompt "$PROMPT" \
        --argjson duration "$DURATION" \
        --arg aspect_ratio "$ASPECT_RATIO" \
        '{input: {prompt: $prompt, duration: $duration, aspect_ratio: $aspect_ratio, generate_audio: false}}')
fi

# Create prediction (with retry)
log_info "Submitting video generation request..."
RESPONSE=$(retry_curl 3 -X POST "https://api.replicate.com/v1/models/$VIDEO_MODEL/predictions" \
    -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

if [ $? -ne 0 ]; then
    log_error "Failed to submit video generation request"
    exit 1
fi

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
    log_info "Video generation started — this may take 30-120 seconds..."
    RESPONSE=$(poll_replicate "$POLL_URL" "$REPLICATE_API_TOKEN" 300)
fi

if [ "$(echo "$RESPONSE" | jq -r '.status')" = "failed" ]; then
    log_error "Replicate failed: $(echo "$RESPONSE" | jq -r '.error // "Unknown"')"
    exit 1
fi

VIDEO_URL=$(echo "$RESPONSE" | jq -r 'if (.output | type) == "array" then .output[0] else .output end // empty')

if [ -z "$VIDEO_URL" ]; then
    log_error "Failed to extract video URL from response"
    echo "Response: $FINAL" >&2
    exit 1
fi

log_info "Video ready: $VIDEO_URL"

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
                --media "$VIDEO_URL" \
                -m "$CAPTION"
        else
            openclaw message send \
                --channel "$OPENCLAW_PLATFORM" \
                --target "$OPENCLAW_TARGET" \
                --media "$VIDEO_URL"
        fi
    else
        if [ -n "$CAPTION" ]; then
            openclaw message send \
                --target "$OPENCLAW_TARGET" \
                --media "$VIDEO_URL" \
                -m "$CAPTION"
        else
            openclaw message send \
                --target "$OPENCLAW_TARGET" \
                --media "$VIDEO_URL"
        fi
    fi
else
    # Direct API call to local gateway
    GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"

    if [ -n "$CAPTION" ]; then
        MESSAGE_JSON=$(jq -n \
            --arg channel "$CHANNEL" \
            --arg message "$CAPTION" \
            --arg media "$VIDEO_URL" \
            '{action: "send", channel: $channel, message: $message, media: $media}')
    else
        MESSAGE_JSON=$(jq -n \
            --arg channel "$CHANNEL" \
            --arg media "$VIDEO_URL" \
            '{action: "send", channel: $channel, media: $media}')
    fi

    curl -s -X POST "$GATEWAY_URL/message" \
        -H "Content-Type: application/json" \
        ${OPENCLAW_GATEWAY_TOKEN:+-H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN"} \
        -d "$MESSAGE_JSON"
fi

log_info "Done! Video sent to $CHANNEL"

# Output JSON result for programmatic use
echo ""
echo "--- Result ---"
jq -n --arg url "$VIDEO_URL" --arg model "$VIDEO_MODEL" --argjson duration "$DURATION" --arg character "$CHAR_NAME" --arg channel "$CHANNEL" \
    '{success: true, video_url: $url, model: $model, duration: $duration, character: $character, channel: $channel}'
