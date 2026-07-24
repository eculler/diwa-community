#!/usr/bin/env bash

# Shared terminal UI helpers for setup and maintenance commands.

UI_OUTPUT=""
UI_ELAPSED=""

if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  UI_BOLD=$'\033[1m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_RED=$'\033[31m'
  UI_CYAN=$'\033[36m'
  UI_RESET=$'\033[0m'
  UI_INTERACTIVE=true
else
  UI_BOLD=""
  UI_GREEN=""
  UI_YELLOW=""
  UI_RED=""
  UI_CYAN=""
  UI_RESET=""
  UI_INTERACTIVE=false
fi

ui_title() { printf '\n%s%s%s%s\n' "$UI_BOLD" "$UI_CYAN" "$*" "$UI_RESET"; }
ui_step() { printf '\n%s%sStep %s of %s · %s%s\n\n' "$UI_BOLD" "$UI_CYAN" "$1" "$2" "$3" "$UI_RESET"; }
ui_info() { printf 'ℹ  %s\n' "$*"; }
ui_success() { printf '%s✓%s %s\n' "$UI_GREEN" "$UI_RESET" "$*"; }
ui_warning() { printf '%s!%s %s%s%s\n' "$UI_YELLOW" "$UI_RESET" "$UI_BOLD" "$*" "$UI_RESET" >&2; }
ui_prompt() { printf '%s?%s %s%s%s\n' "$UI_GREEN" "$UI_RESET" "$UI_BOLD" "$*" "$UI_RESET"; }
ui_important() { printf '%s%s%s\n' "$UI_BOLD" "$*" "$UI_RESET"; }

ui_fail() {
  printf '\n%s!%s %sERROR:%s %s%s%s\n' "$UI_RED" "$UI_RESET" "$UI_BOLD" "$UI_RESET" "$UI_BOLD" "$*" "$UI_RESET" >&2
  exit 1
}

ui_format_elapsed() {
  local milliseconds="$1"
  if (( milliseconds < 1000 )); then
    printf '%d ms' "$milliseconds"
  else
    printf '%d.%d s' "$((milliseconds / 1000))" "$(((milliseconds % 1000) / 100))"
  fi
}

ui_run() {
  local message="$1"
  shift

  local output_file pid frame_index=0 status start_ms end_ms
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  output_file="$(mktemp)"
  start_ms="$(date +%s%3N)"

  if [[ "$UI_INTERACTIVE" != true ]]; then
    printf '→ %s\n' "$message"
    if "$@" >"$output_file" 2>&1; then
      status=0
    else
      status=$?
    fi
  else
    "$@" >"$output_file" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
      printf '\r%s%s%s %s' "$UI_CYAN" "${frames[$frame_index]}" "$UI_RESET" "$message"
      frame_index=$(( (frame_index + 1) % ${#frames[@]} ))
      sleep 0.08
    done

    if wait "$pid"; then
      status=0
    else
      status=$?
    fi
    printf '\r\033[2K'
  fi

  end_ms="$(date +%s%3N)"
  UI_ELAPSED="$(ui_format_elapsed "$((end_ms - start_ms))")"
  UI_OUTPUT="$(cat "$output_file")"
  rm -f "$output_file"

  if (( status != 0 )) && [[ -n "$UI_OUTPUT" ]]; then
    printf '%s\n' "$UI_OUTPUT" >&2
  fi

  return "$status"
}
