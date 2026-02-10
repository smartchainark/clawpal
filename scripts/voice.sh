#!/bin/bash
# voice.sh — Generate a voice message via Edge TTS and send it
#
# Usage: voice.sh "<text>" "<channel>" ["<caption>"]
#
# Reads voice config (name, rate, pitch) from character.yaml
# Uses edge-tts (free, no API key needed)
# Generates audio and sends it via OpenClaw

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
    echo "  text     - Text to speak (required)"
    echo "  channel  - Target channel (required) e.g., #general, @user"
    echo "  caption  - Message caption (optional)"
    echo ""
    echo "Example:"
    echo "  $0 \"Hey! Just wanted to say hi\" \"#general\" \"Voice message for you\""
    exit 1
fi

# Ensure edge-tts is installed
if ! command -v edge-tts &>/dev/null; then
    log_warn "edge-tts not found, attempting install..."
    if command -v pip3 &>/dev/null; then
        pip3 install edge-tts --quiet --break-system-packages 2>/dev/null || pip3 install edge-tts --quiet
    elif command -v pip &>/dev/null; then
        pip install edge-tts --quiet
    else
        log_error "pip3/pip not found. Install edge-tts manually: pip3 install edge-tts"
        exit 1
    fi

    if ! command -v edge-tts &>/dev/null; then
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
OUTFILE="/tmp/clawpal-voice-$(date +%s).mp3"

$EDGE_TTS_CMD \
    --voice "$VOICE" \
    --rate "$RATE" \
    --pitch "$PITCH" \
    --text "$TEXT" \
    --write-media "$OUTFILE"

if [ ! -s "$OUTFILE" ]; then
    log_error "Audio generation failed (empty file)"
    exit 1
fi

FILE_SIZE=$(wc -c < "$OUTFILE" | tr -d ' ')
log_info "Audio generated: ${FILE_SIZE} bytes → $OUTFILE"

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
    # Use OpenClaw CLI with local file path
    if [ -n "$OPENCLAW_PLATFORM" ]; then
        if [ -n "$CAPTION" ]; then
            openclaw message send \
                --channel "$OPENCLAW_PLATFORM" \
                --target "$OPENCLAW_TARGET" \
                --media "$OUTFILE" \
                -m "$CAPTION"
        else
            openclaw message send \
                --channel "$OPENCLAW_PLATFORM" \
                --target "$OPENCLAW_TARGET" \
                --media "$OUTFILE"
        fi
    else
        if [ -n "$CAPTION" ]; then
            openclaw message send \
                --target "$OPENCLAW_TARGET" \
                --media "$OUTFILE" \
                -m "$CAPTION"
        else
            openclaw message send \
                --target "$OPENCLAW_TARGET" \
                --media "$OUTFILE"
        fi
    fi
else
    # Direct API call - need to send file path
    GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"

    if [ -n "$CAPTION" ]; then
        MESSAGE_JSON=$(jq -n \
            --arg channel "$CHANNEL" \
            --arg message "$CAPTION" \
            --arg media "$OUTFILE" \
            '{action: "send", channel: $channel, message: $message, media: $media}')
    else
        MESSAGE_JSON=$(jq -n \
            --arg channel "$CHANNEL" \
            --arg media "$OUTFILE" \
            '{action: "send", channel: $channel, media: $media}')
    fi

    curl -s -X POST "$GATEWAY_URL/message" \
        -H "Content-Type: application/json" \
        ${OPENCLAW_GATEWAY_TOKEN:+-H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN"} \
        -d "$MESSAGE_JSON"
fi

log_info "Done! Audio sent to $CHANNEL"

# Output JSON result for programmatic use
echo ""
echo "--- Result ---"
jq -n --arg file "$OUTFILE" --arg voice "$VOICE" --arg character "$CHAR_NAME" --argjson size "$FILE_SIZE" --arg channel "$CHANNEL" \
    '{success: true, file: $file, voice: $voice, character: $character, size: $size, channel: $channel}'
