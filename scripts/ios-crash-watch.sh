#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/dev-local.env"

MAC_HOST="${MAC_HOST:-}"
MAC_USER="${MAC_USER:-}"
POLL_INTERVAL="${POLL_INTERVAL:-5}"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Watch for AgentPocket crash reports on Mac via SSH.
Monitors ~/Library/Logs/DiagnosticReports/ for new crash files.

Options:
  -h, --host HOST           Mac SSH host (or set MAC_HOST)
  -u, --user USER           Mac SSH user (or set MAC_USER)
  -i, --interval SECONDS    Poll interval in seconds (default: 5, used if fswatch unavailable)
  --help                    Show this help

Config file: scripts/dev-local.env (sourced automatically)
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host) MAC_HOST="$2"; shift 2 ;;
        -u|--user) MAC_USER="$2"; shift 2 ;;
        -i|--interval) POLL_INTERVAL="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$MAC_HOST" ]]; then
    echo "Error: MAC_HOST not set. Use --host or set MAC_HOST in scripts/dev-local.env"
    exit 1
fi
if [[ -z "$MAC_USER" ]]; then
    echo "Error: MAC_USER not set. Use --user or set MAC_USER in scripts/dev-local.env"
    exit 1
fi

SSH_TARGET="${MAC_USER}@${MAC_HOST}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  AgentPocket Crash Watcher                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Host:     ${SSH_TARGET}"
echo "║  Ctrl+C to stop                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

REMOTE_SCRIPT=$(cat <<'REMOTE_EOF'
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
POLL_INTERVAL=__POLL_INTERVAL__

mkdir -p "$CRASH_DIR"

MARKER_FILE=$(mktemp)
touch "$MARKER_FILE"

check_new_crashes() {
    find "$CRASH_DIR" -newer "$MARKER_FILE" \( -name "*.crash" -o -name "*.ips" \) 2>/dev/null | while read -r crash_file; do
        filename=$(basename "$crash_file")
        if echo "$filename" | grep -qi "agentpocket"; then
            echo ""
            echo "════════════════════════════════════════════════════"
            echo "  CRASH DETECTED: $filename"
            echo "  Time: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "════════════════════════════════════════════════════"
            cat "$crash_file"
            echo ""
            echo "════════════════════════════ END OF CRASH ════════════════════════════"
        fi
    done
    touch "$MARKER_FILE"
}

if command -v fswatch &>/dev/null; then
    echo "[crash-watch] Using fswatch for real-time monitoring"
    echo "[crash-watch] Watching: $CRASH_DIR"
    echo ""
    fswatch -m fsevents_monitor --event Created "$CRASH_DIR" | while read -r event; do
        filename=$(basename "$event")
        if echo "$filename" | grep -qi "agentpocket"; then
            sleep 1
            echo ""
            echo "════════════════════════════════════════════════════"
            echo "  CRASH DETECTED: $filename"
            echo "  Time: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "════════════════════════════════════════════════════"
            cat "$event"
            echo ""
            echo "════════════════════════════ END OF CRASH ════════════════════════════"
        fi
    done
else
    echo "[crash-watch] fswatch not found, using polling (every ${POLL_INTERVAL}s)"
    echo "[crash-watch] Install fswatch for real-time: brew install fswatch"
    echo "[crash-watch] Watching: $CRASH_DIR"
    echo ""
    while true; do
        check_new_crashes
        sleep "$POLL_INTERVAL"
    done
fi

rm -f "$MARKER_FILE"
REMOTE_EOF
)

REMOTE_SCRIPT="${REMOTE_SCRIPT//__POLL_INTERVAL__/$POLL_INTERVAL}"

exec ssh -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
    "${SSH_TARGET}" \
    "bash -c $(printf '%q' "$REMOTE_SCRIPT")"
