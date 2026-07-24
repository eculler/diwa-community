#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NAME="DIWA Community Site Editor"
UPSTREAM_REPO="DigitalWaters-fi/community"
WORKSPACE="$HOME/diwa-community"
PROFILE="$HOME/.bash_profile"
BASHRC="$HOME/.bashrc"
STATE_DIR="$HOME/.config/diwa-community-site"
STATE_FILE="$STATE_DIR/setup-state.json"

say() { printf '\n%s\n' "$