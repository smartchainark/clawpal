#!/bin/bash
# voice.sh — Generate a voice message via Edge TTS
#
# Usage: voice.sh "<text>" ["<output_file>"]
#
# Reads voice config (name, rate, pitch) from character.yaml
# Uses edge-tts (free, no API key needed)
# Outputs the generated MP3 file path — sending is handled by the agent

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
OUTPUT="${2:-}"

if [ -z "$TEXT" ]; then
    echo "Usage: $0 <text> [output_file]"
    echo ""
    echo "Arguments:"
    echo "  text         - Text to speak (required)"
    echo "  output_file  - Output MP3 path (optional, auto-generated if omitted)"
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
OUTFILE="${OUTPUT:-/tmp/clawpal-voice-$(date +%s).mp3}"

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

# Output JSON result for the agent
jq -n --arg file "$OUTFILE" --arg voice "$VOICE" --arg character "$CHAR_NAME" --argjson size "$FILE_SIZE" \
    '{success: true, file: $file, voice: $voice, character: $character, size: $size}'
