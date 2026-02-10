#!/bin/bash
# _common.sh — Shared helpers for Clawpal v2 scripts
# Source this file: source "$(dirname "$0")/_common.sh"

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

require_cmd() {
    local cmd="$1" hint="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd is required but not installed"
        [ -n "$hint" ] && echo "  Install with: $hint"
        exit 1
    fi
}

# Lightweight YAML value extractor
# Usage: yaml_get <file> <dotted.key>
# Handles: simple values, quoted strings, 1-level nesting, | blocks, - arrays
yaml_get() {
    local file="$1" key="$2"
    local parts IFS='.' top sub
    IFS='.' read -ra parts <<< "$key"

    if [ ${#parts[@]} -eq 1 ]; then
        # Top-level key
        top="${parts[0]}"
        local val
        val=$(awk -v k="$top" '
            $0 ~ "^"k":" {
                sub("^"k":[ ]*", "")
                # Strip surrounding quotes
                gsub(/^["'\'']|["'\'']$/, "")
                # Handle | block
                if ($0 == "|") { block=1; next }
                print; exit
            }
            block && /^  [^ ]/ { gsub(/^  /, ""); buf = buf (buf ? "\n" : "") $0; next }
            block && /^[^ ]/ { print buf; exit }
            END { if (block) print buf }
        ' "$file")
        echo "$val"
    elif [ ${#parts[@]} -eq 2 ]; then
        # One-level nested key: e.g. voice.name
        top="${parts[0]}" sub="${parts[1]}"

        # Special case: personality.traits → return as comma-joined list
        if [ "$sub" = "traits" ]; then
            awk -v sec="$top" '
                $0 ~ "^"sec":" { in_sec=1; next }
                in_sec && /^[^ ]/ { exit }
                in_sec && $0 ~ "^  "sub":" { in_arr=1; next }
                in_arr && /^    - / { gsub(/^    - /, ""); items = items (items ? ", " : "") $0 }
                in_arr && !/^    - / && !/^[[:space:]]*$/ { exit }
                END { print items }
            ' sub="$sub" "$file"
            return
        fi

        local val
        val=$(awk -v sec="$top" -v k="$sub" '
            $0 ~ "^"sec":" { in_sec=1; next }
            in_sec && /^[^ ]/ { exit }
            in_sec && $0 ~ "^  "k":" {
                sub("^  "k":[ ]*", "")
                gsub(/^["'\'']|["'\'']$/, "")
                if ($0 == "|") { block=1; next }
                print; exit
            }
            block && /^    [^ ]/ { gsub(/^    /, ""); buf = buf (buf ? "\n" : "") $0; next }
            block && !/^    / && !/^[[:space:]]*$/ { print buf; exit }
            END { if (block) print buf }
        ' "$file")
        echo "$val"
    fi
}

# Find and export CHARACTER_FILE
load_character() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"

    # Search order: same dir → skill dir → parent dir
    local candidates=(
        "$script_dir/character.yaml"
        "$script_dir/../character.yaml"
        "$HOME/.openclaw/skills/clawpal/character.yaml"
    )
    for f in "${candidates[@]}"; do
        if [ -f "$f" ]; then
            CHARACTER_FILE="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
            export CHARACTER_FILE
            return 0
        fi
    done
    log_error "character.yaml not found"
    exit 1
}

# Auto-detect image provider from env vars + character.yaml
detect_provider() {
    local explicit="${CLAWPAL_PROVIDER:-}"
    if [ "$explicit" = "replicate" ] || [ "$explicit" = "fal" ]; then
        echo "$explicit"; return
    fi
    # Check character.yaml preference
    if [ -n "${CHARACTER_FILE:-}" ]; then
        local pref
        pref=$(yaml_get "$CHARACTER_FILE" "image.provider" 2>/dev/null || true)
        if [ "$pref" = "replicate" ] || [ "$pref" = "fal" ]; then
            echo "$pref"; return
        fi
    fi
    # Fallback to env var detection
    if [ -n "${REPLICATE_API_TOKEN:-}" ]; then echo "replicate"; return; fi
    if [ -n "${FAL_KEY:-}" ]; then echo "fal"; return; fi
    log_error "No API key found. Set REPLICATE_API_TOKEN or FAL_KEY"
    exit 1
}

# Retry a curl command on failure
# Usage: retry_curl <max_retries> <curl_args...>
retry_curl() {
    local max_retries="$1"; shift
    local attempt=0 response
    while [ "$attempt" -lt "$max_retries" ]; do
        attempt=$((attempt + 1))
        response=$(curl -s "$@") && {
            # Check if response is valid (non-empty and not a curl error)
            if [ -n "$response" ]; then
                echo "$response"
                return 0
            fi
        }
        log_warn "Request failed (attempt $attempt/$max_retries), retrying in ${attempt}s..."
        sleep "$attempt"
    done
    log_error "Request failed after $max_retries attempts"
    return 1
}

# Poll a Replicate prediction until terminal state
# Usage: poll_replicate <prediction_url> <token> [timeout_seconds]
poll_replicate() {
    local url="$1" token="$2" timeout="${3:-300}"
    local elapsed=0 status response

    while [ "$elapsed" -lt "$timeout" ]; do
        response=$(curl -s "$url" -H "Authorization: Bearer $token")
        status=$(echo "$response" | jq -r '.status // empty')

        case "$status" in
            succeeded)
                echo "$response"
                return 0
                ;;
            failed|canceled)
                local err
                err=$(echo "$response" | jq -r '.error // "Unknown error"')
                log_error "Replicate prediction $status: $err"
                return 1
                ;;
            *)
                log_info "Status: $status ... (${elapsed}s)"
                sleep 3
                elapsed=$((elapsed + 3))
                ;;
        esac
    done

    log_error "Replicate prediction timed out after ${timeout}s"
    return 1
}
