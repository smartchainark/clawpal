#!/bin/bash
# video.sh — Generate a video clip via Replicate (Kling v2.6)
#
# Usage: video.sh "<prompt>" ["<source_image>"] ["<duration>"]
#
# Reads video config from character.yaml
# Requires REPLICATE_API_TOKEN
# Outputs the video URL — sending is handled by the agent

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
SOURCE_IMAGE="${2:-$REFERENCE_IMAGE}"
DURATION="${3:-$DEFAULT_DURATION}"

if [ -z "$PROMPT" ]; then
    echo "Usage: $0 <prompt> [source_image] [duration]"
    echo ""
    echo "Arguments:"
    echo "  prompt        - Video description (required)"
    echo "  source_image  - Start image URL (default: character reference image)"
    echo "  duration      - Duration in seconds: 5 or 10 (default: $DEFAULT_DURATION)"
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

POLL_URL=$(echo "$RESPONSE" | jq -r '.urls.get // empty')
if [ -z "$POLL_URL" ]; then
    log_error "No poll URL in response"
    echo "Response: $RESPONSE"
    exit 1
fi

log_info "Video generation started — this may take 30-120 seconds..."

# Poll until complete (5 min timeout)
FINAL=$(poll_replicate "$POLL_URL" "$REPLICATE_API_TOKEN" 300)

if [ $? -ne 0 ]; then
    log_error "Video generation failed"
    exit 1
fi

# Extract output URL
VIDEO_URL=$(echo "$FINAL" | jq -r 'if (.output | type) == "array" then .output[0] else .output end // empty')

if [ -z "$VIDEO_URL" ]; then
    log_error "Failed to extract video URL from response"
    echo "Response: $FINAL"
    exit 1
fi

log_info "Video ready: $VIDEO_URL"

# Output JSON result for the agent
jq -n --arg url "$VIDEO_URL" --arg model "$VIDEO_MODEL" --argjson duration "$DURATION" --arg character "$CHAR_NAME" \
    '{success: true, video_url: $url, model: $model, duration: $duration, character: $character}'
