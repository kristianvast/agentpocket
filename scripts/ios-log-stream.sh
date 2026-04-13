#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/dev-local.env"

MAC_HOST="${MAC_HOST:-}"
MAC_USER="${MAC_USER:-}"
LOG_LEVEL="${LOG_LEVEL:-info}"
LOG_STYLE="${LOG_STYLE:-compact}"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Stream iOS Simulator logs from Mac via SSH.
Filters for AgentPocket app (process: AgentPocket).

Options:
  -h, --host HOST       Mac SSH host (or set MAC_HOST)
  -u, --user USER       Mac SSH user (or set MAC_USER)
  -l, --level LEVEL     Log level: debug, info, default, error, fault (default: info)
  -s, --style STYLE     Output style: compact, json, syslog (default: compact)
  --errors-only         Show only error and fault messages
  --help                Show this help

Config file: scripts/dev-local.env (sourced automatically)
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host) MAC_HOST="$2"; shift 2 ;;
        -u|--user) MAC_USER="$2"; shift 2 ;;
        -l|--level) LOG_LEVEL="$2"; shift 2 ;;
        -s|--style) LOG_STYLE="$2"; shift 2 ;;
        --errors-only) LOG_LEVEL="error"; shift ;;
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

PREDICATE='processImagePath ENDSWITH "AgentPocket"'
SSH_TARGET="${MAC_USER}@${MAC_HOST}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  AgentPocket iOS Log Stream                                 ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Host:     ${SSH_TARGET}"
echo "║  Level:    ${LOG_LEVEL}"
echo "║  Style:    ${LOG_STYLE}"
echo "║  Ctrl+C to stop                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

exec ssh -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
    "${SSH_TARGET}" \
    "xcrun simctl spawn booted log stream --level ${LOG_LEVEL} --style ${LOG_STYLE} --predicate '${PREDICATE}'"
