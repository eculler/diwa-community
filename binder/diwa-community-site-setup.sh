#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/diwa-community-site-ui.sh"
source "$SCRIPT_DIR/diwa-community-site-github.sh"

DISPLAY_NAME="DIWA Community Site Editor"
UPSTREAM_REPO="DigitalWaters-fi/community"
FORK_NAME="community"
WORKSPACE="$HOME/diwa-community"
PROFILE="$HOME/.bash_profile"
BASHRC="$HOME/.bashrc"
STATE_DIR="$HOME/.config/diwa-community-site"
STATE_FILE="$STATE_DIR/setup-state.json"
RESET_COMMAND="diwa-community-site-unsetup"
TOTAL_STEPS=5

ensure_profile() {
  ui_step 1 "$TOTAL_STEPS" "Configure the shell"
  ui_info "JupyterLab terminals use your shell profile. This step makes sure interactive terminals load your normal Bash configuration."
  touch "$BASHRC"
  if [[ ! -f "$PROFILE" ]] || ! grep -Fq '# DIWA Community Site Editor profile' "$PROFILE"; then
    cat >> "$PROFILE" <<'EOF'

# DIWA Community Site Editor profile
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
    ui_success "Updated $PROFILE to load $BASHRC."
  else
    ui_success "Shell profile is already configured."
  fi
}

write_state() { mkdir -p "$STATE_DIR"; cat > "$STATE_FILE" <<EOF
{"version":1,"display_name":"$DISPLAY_NAME","upstream_repository":"$UPSTREAM_REPO","fork_repository":"$GITHUB_FORK","workspace":"$WORKSPACE","complete":true}
EOF
}

print_summary() {
  ui_title "Setup summary"
  ui_success "Shell configured"
  ui_success "GitHub connected as ${UI_BOLD}${GITHUB_LOGIN}${UI_RESET}"
  ui_success "Fork ready: ${UI_BOLD}${GITHUB_FORK}${UI_RESET}"
  ui_success "Repository synchronized"
  ui_success "Git remotes configured"
  printf '\n%s%s🎉 You’re all set!%s\n\n' "$UI_BOLD" "$UI_GREEN" "$UI_RESET"
  ui_important "Open 'Open DIWA Community Site Editor' from the JupyterLab launcher."
}

main() {
 github_require_tools; ui_title "$DISPLAY_NAME setup"; ui_info "Setup checks the current environment and only performs actions that are needed."; ensure_profile; ui_step 2 "$TOTAL_STEPS" "Connect to GitHub"; ui_info "The editor needs GitHub access so it can find your fork and synchronize your work."; github_ensure_auth; ui_step 3 "$TOTAL_STEPS" "Find your GitHub fork"; ui_info "Your fork is your personal copy of the DIWA Community Site. It lets you edit safely without changing the main project directly."; github_ensure_fork "$UPSTREAM_REPO" "$FORK_NAME"; ui_step 4 "$TOTAL_STEPS" "Synchronize the site files"; ui_info "The editor works from a local Git repository. Existing files are updated; otherwise, your fork is cloned into the workspace."; github_sync_clone "$GITHUB_FORK" "$WORKSPACE" "$RESET_COMMAND"; ui_step 5 "$TOTAL_STEPS" "Configure Git remotes"; ui_info "The origin remote points to your fork, while upstream points to the main DIWA Community Site repository."; github_configure_remotes "$GITHUB_FORK" "$UPSTREAM_REPO" "$WORKSPACE"; write_state; print_summary; }

main "$@"
