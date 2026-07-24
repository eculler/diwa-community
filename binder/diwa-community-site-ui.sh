#!/usr/bin/env bash

# Shared terminal UI helpers for DIWA Community Site setup commands.

SPINNER_OUTPUT=""
SPINNER_ELAPSED=""

if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  BOLD=$'\033[1m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RED=$'\033[31m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
  INTERACTIVE_OUTPUT=true
else
  BOLD=""
  GREEN=""
  YELLOW=""
  RED=""