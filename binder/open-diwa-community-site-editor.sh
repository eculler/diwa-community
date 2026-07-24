#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$HOME/diwa-community"
SETUP_COMMAND="diwa-community-site-setup"
PORT=""

while (($#)); do
  case "$1" in
    --port)
      PORT="${2:?Missing value for --port}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PORT" ]]; then
  echo "A port is required." >&2
  exit 2
fi

if ! git -C "$WORKSPACE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "The DIWA Community Site Editor is not set up yet."
  echo "Starting setup..."
  exec "$SETUP_COMMAND"
fi

exec code-server \
  --auth none \
  --bind-addr "127.0.0.1:$PORT" \
  "$WORKSPACE"
