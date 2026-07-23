#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$HOME/diwa-community"
SETUP_COMMAND="diwa-community-site-setup"

if ! git -C "$WORKSPACE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "The DIWA Community Site Editor is not set up yet."
  echo "Starting setup..."
  exec "$SETUP_COMMAND"
fi

exec code-server --auth none "$WORKSPACE"
