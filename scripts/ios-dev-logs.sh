#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/dev-local.env"

MAC_HOST="${MAC_HOST:-}"
MAC_USER="${MAC_USER:-}"
LOG_LEVEL="${LOG_LEVEL:-info}"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

PIDS=()

cleanup() {
    echo ""
    echo -e "${BOLD}Shutting down all log streams...${RESET}"
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
    echo -e "${BOLD}All streams stopped.${RESET}"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Unified log viewer for AgentPocket cross-machine iOS development.
Multiplexes iOS Simulator logs and crash reports.

Streams:
  ${CYAN}[iOS]${RESET}    iOS Simulator logs (from Mac via SSH)
  ${RED}[CRASH]${RESET}  Crash report watcher (from Mac via SSH)

Options:
  -h, --host HOST       Mac SSH host (or set MAC_HOST)
  -u, --user USER       Mac SSH user (or set MAC_USER)
  -l, --level LEVEL     iOS log level: debug, info, error (default: info)
  --help                Show this help

Config file: scripts/dev-local.env (sourced automatically)

Examples:
  $(basename "$0")
  $(basename "$0") --level debug
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host) MAC_HOST="$2"; shift 2 ;;
        -u|--user) MAC_USER="$2"; shift 2 ;;
        -l|--level) LOG_LEVEL="$2"; shift 2 ;;
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

echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║  AgentPocket Dev Logs — Unified Stream                      ║${RESET}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${BOLD}║${RESET}  ${CYAN}[iOS]${RESET}    Simulator logs → ${MAC_USER}@${MAC_HOST}"
echo -e "${BOLD}║${RESET}  ${RED}[CRASH]${RESET}  Crash watcher  → ${MAC_USER}@${MAC_HOST}"
echo -e "${BOLD}║${RESET}  Level:   ${LOG_LEVEL}"
echo -e "${BOLD}║${RESET}  Ctrl+C to stop all streams"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""

echo -e "${CYAN}[iOS]${RESET} Connecting to ${MAC_USER}@${MAC_HOST}..."
(
    "$SCRIPT_DIR/ios-log-stream.sh" \
        --host "$MAC_HOST" \
        --user "$MAC_USER" \
        --level "$LOG_LEVEL" 2>&1 \
    | while IFS= read -r line; do
        if [[ "$line" == ╔* ]] || [[ "$line" == ║* ]] || [[ "$line" == ╠* ]] || [[ "$line" == ╚* ]]; then
            continue
        fi
        echo -e "${CYAN}[iOS]${RESET} $line"
    done
) &
PIDS+=($!)

echo -e "${RED}[CRASH]${RESET} Connecting to ${MAC_USER}@${MAC_HOST}..."
(
    "$SCRIPT_DIR/ios-crash-watch.sh" \
        --host "$MAC_HOST" \
        --user "$MAC_USER" 2>&1 \
    | while IFS= read -r line; do
        if [[ "$line" == ╔* ]] || [[ "$line" == ║* ]] || [[ "$line" == ╠* ]] || [[ "$line" == ╚* ]]; then
            continue
        fi
        echo -e "${RED}[CRASH]${RESET} $line"
    done
) &
PIDS+=($!)

echo ""
echo -e "${BOLD}All streams active. Waiting...${RESET}"
echo ""

while true; do
    for i in "${!PIDS[@]}"; do
        pid="${PIDS[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid" 2>/dev/null
            exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                echo -e "${YELLOW}[WARN] Stream (PID $pid) exited with code $exit_code${RESET}"
            fi
            unset 'PIDS[$i]'
        fi
    done
    if [[ ${#PIDS[@]} -eq 0 ]]; then
        echo -e "${RED}All streams have stopped.${RESET}"
        exit 1
    fi
    sleep 2
done
