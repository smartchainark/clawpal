#!/bin/bash
# voice.sh — Generate and send a voice message via Edge TTS
#
# Usage: voice.sh "<text>" "<channel>" ["<caption>"]
#
# Reads voice config (name, rate, pitch) from character.yaml
# Uses edge-tts (free, no API key needed)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

load_character

# Read voice config from character.yaml
VOICE=$(yaml_get "$CHARACTER_FILE" "voice.name")
RATE=$(yaml_get "$CHARACTER_FILE" "voice.rate")
PITCH=$(yaml_get "$CHARACTER_FILE" "voice.pitch")
CHAR_NAME=$(yaml_get "$CHARACTER_FILE" "name")

VOICE="${VOICE:-en-US-GuyNeural}"
RATE="${RATE:-+0%}"
PITCH="${PITCH:-+0Hz}"

# Parse arguments
TEXT="${1:-}"
CHANNEL="${2:-}"
CAPTION="${3:-}"

if [ -z "$TEXT" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <text> <channel> [caption]"
    echo ""
    echo "Arguments:"
    echo "  text      - Text to speak (required)"
    echo "  channel   - Target channel (required)"
    echo "  caption   - Message caption (optional)"
    exit 1
fi

# Ensure edge-tts is installed
if ! command -v edge-tts &>/dev/null; then
    log_warn "edge-tts not found, attempting install..."
    if command -v pip3 &>/dev/null; then
        pip3 install edge-tts --quiet
    elif command -v pip &>/dev/null; then
        pip install edge-tts --quiet
    else
        log_error "pip3/pip not found. Install edge-tts manually: pip3 install edge-tts"
        exit 1
    fi

    # Verify installation
    if ! command -v edge-tts &>/dev/null; then
        # Fallback: try as python module
        if python3 -m edge_tts --help &>/dev/null 2>&1; then
            EDGE_TTS_CMD="python3 -m edge_tts"
        else
            log_error "edge-tts installation failed"
            exit 1
        fi
    fi
fi

EDGE_TTS_CMD="${EDGE_TTS_CMD:-edge-tts}"

log_info "Character: $CHAR_NAME"
log_info "Voice: $VOICE (rate=$RATE, pitch=$PITCH)"
log_info "Text: $TEXT"

# Generate audio
TMPFILE=$(mktemp /tmp/clawpal-voice-XXXXXX.mp3)
trap "rm -f '$TMPFILE'" EXIT

$EDGE_TTS_CMD \
    --voice "$VOICE" \
    --rate "$RATE" \
    --pitch "$PITCH" \
    --text "$TEXT" \
    --write-media "$TMPFILE"

if [ ! -s "$TMPFILE" ]; then
    log_error "Audio generation failed (empty file)"
    exit 1
fi

FILE_SIZE=$(wc -c < "$TMPFILE" | tr -d ' ')
log_info "Audio generated: ${FILE_SIZE} bytes"

# Upload to 0x0.st for public URL
log_info "Uploading audio..."
AUDIO_URL=$(curl -s -F "file=@$TMPFILE" https://0x0.st)

if [ -z "$AUDIO_URL" ] || ! echo "$AUDIO_URL" | grep -q "^https\?://"; then
    # Fallback: try transfer.sh
    log_warn "0x0.st upload failed, trying transfer.sh..."
    AUDIO_URL=$(curl -s --upload-file "$TMPFILE" "https://transfer.sh/voice.mp3")
fi

if [ -z "$AUDIO_URL" ] || ! echo "$AUDIO_URL" | grep -q "^https\?://"; then
    log_error "Failed to upload audio file"
    exit 1
fi

log_info "Audio uploaded: $AUDIO_URL"

# Send via OpenClaw
SEND_CAPTION="${CAPTION:-Voice message from $CHAR_NAME}"
log_info "Sending to $CHANNEL"

if command -v openclaw &>/dev/null; then
    openclaw message send \
        --action send \
        --channel "$CHANNEL" \
        --message "$SEND_CAPTION" \
        --media "$AUDIO_URL"
else
    GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"
    GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

    curl -s -X POST "$GATEWAY_URL/message" \
        -H "Content-Type: application/json" \
        ${GATEWAY_TOKEN:+-H "Authorization: Bearer $GATEWAY_TOKEN"} \
        -d "$(jq -n \
            --arg channel "$CHANNEL" \
            --arg message "$SEND_CAPTION" \
            --arg media "$AUDIO_URL" \
            '{action: "send", channel: $channel, message: $message, media: $media}')"
fi

log_info "Done!"

jq -n --arg url "$AUDIO_URL" --arg channel "$CHANNEL" --arg voice "$VOICE" \
    '{success: true, audio_url: $url, channel: $channel, voice: $voice}'
