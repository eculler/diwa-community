#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NAME="DIWA Community Site Editor"
UPSTREAM_REPO="DigitalWaters-fi/community"
WORKSPACE="$HOME/diwa-community"
PROFILE="$HOME/.bash_profile"
BASHRC="$HOME/.bashrc"
STATE_DIR="$HOME/.config/diwa-community-site"
STATE_FILE="$STATE_DIR/setup-state.json"
FORK=""
SPINNER_OUTPUT=""

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
  CYAN=""
  RESET=""
  INTERACTIVE_OUTPUT=false
fi

heading() {
  printf '\n%s%s############################################################%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s## Step %s of 5 — %s%s\n' "$BOLD" "$CYAN" "$1" "$2" "$RESET"
  printf '%s%s############################################################%s\n\n' "$BOLD" "$CYAN" "$RESET"
}

info() { printf 'ℹ  %s\n' "$*"; }
success() { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warning() { printf '%s!%s %s%s%s\n' "$YELLOW" "$RESET" "$BOLD" "$*" "$RESET" >&2; }
prompt_note() { printf '%s?%s %s%s%s\n' "$GREEN" "$RESET" "$BOLD" "$*" "$RESET"; }
important() { printf '%s%s%s\n' "$BOLD" "$*" "$RESET"; }

fail() {
  printf '\n%s!%s %sERROR:%s %s%s%s\n' "$RED" "$RESET" "$BOLD" "$RESET" "$BOLD" "$*" "$RESET" >&2
  exit 1
}

run_with_spinner() {
  local message="$1"
  shift

  local output_file pid frame_index=0 status
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  output_file="$(mktemp)"

  if [[ "$INTERACTIVE_OUTPUT" != true ]]; then
    printf '→ %s\n' "$message"
    if "$@" >"$output_file" 2>&1; then
      SPINNER_OUTPUT="$(cat "$output_file")"
      rm -f "$output_file"
      return 0
    fi
    status=$?
    cat "$output_file" >&2
    rm -f "$output_file"
    return "$status"
  fi

  "$@" >"$output_file" 2>&1 &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s%s%s %s' "$CYAN" "${frames[$frame_index]}" "$RESET" "$message"
    frame_index=$(( (frame_index + 1) % ${#frames[@]} ))
    sleep 0.08
  done

  if wait "$pid"; then
    status=0
  else
    status=$?
  fi

  printf '\r\033[2K'
  SPINNER_OUTPUT="$(cat "$output_file")"
  rm -f "$output_file"

  if (( status != 0 )); then
    [[ -z "$SPINNER_OUTPUT" ]] || printf '%s\n' "$SPINNER_OUTPUT" >&2
  fi

  return "$status"
}

ensure_profile() {
  heading 1 "Configure the shell"
  info "JupyterLab terminals use your shell profile. This step makes sure interactive terminals load your normal Bash configuration."

  touch "$BASHRC"
  if [[ ! -f "$PROFILE" ]] || ! grep -Fq '# DIWA Community Site Editor profile' "$PROFILE"; then
    cat >> "$PROFILE" <<'EOF'

# DIWA Community Site Editor profile
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
    success "Updated $PROFILE to load $BASHRC."
  else
    success "Shell profile is already configured."
  fi
}

active_github_login() {
  gh api user --jq .login 2>/dev/null
}

ensure_github_auth() {
  local login
  heading 2 "Connect to GitHub"
  info "The editor needs GitHub access so it can find your fork and synchronize your work."

  if run_with_spinner "Checking the active GitHub CLI login..." active_github_login; then
    login="$SPINNER_OUTPUT"
    success "Authenticated with GitHub as ${BOLD}${login}${RESET}."
    return
  fi

  warning "No usable active GitHub login was found."
  prompt_note "GitHub CLI will open a browser and ask you to sign in."
  important "Complete the browser authorization, then return to this terminal."
  echo
  gh auth login --hostname github.com --web

  if ! run_with_spinner "Verifying the new GitHub login..." active_github_login; then
    gh auth status --active --hostname github.com || true
    fail "GitHub sign-in finished, but the active account still cannot access the GitHub API."
  fi

  login="$SPINNER_OUTPUT"
  success "Authenticated with GitHub as ${BOLD}${login}${RESET}."
}

selected_git_protocol() {
  gh config get git_protocol --host github.com 2>/dev/null || printf 'https\n'
}

ensure_fork() {
  local login
  heading 3 "Find your GitHub fork"
  info "Your fork is your personal copy of the DIWA Community Site. It lets you edit safely without changing the main project directly."

  login="$(active_github_login)" || fail "The active GitHub account could not be identified."
  FORK="$login/community"

  if run_with_spinner "Looking for ${BOLD}${FORK}${RESET}..." gh repo view "$FORK"; then
    success "Found your existing fork: ${BOLD}${FORK}${RESET}."
  else
    warning "No fork was found for this account."
    if ! run_with_spinner "Creating a fork of ${BOLD}${UPSTREAM_REPO}${RESET}..." gh repo fork "$UPSTREAM_REPO" --clone=false --remote=false; then
      fail "GitHub could not create your fork. Review the error above, then rerun setup."
    fi
    success "Created your fork: ${BOLD}${FORK}${RESET}."
  fi
}

ensure_clone() {
  local fork="$1"
  local protocol
  heading 4 "Synchronize the site files"
  info "The editor works from a local Git repository. Existing files are updated; otherwise, your fork is cloned into the workspace."

  if git -C "$WORKSPACE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    success "Found the local repository at ${BOLD}${WORKSPACE}${RESET}."
    if ! run_with_spinner "Pulling the latest changes and verifying GitHub access..." git -C "$WORKSPACE" pull --ff-only; then
      warning "The local repository could not be updated."
      fail "GitHub or SSH access may be broken, the remote may have changed, or local history may prevent a fast-forward pull. Run 'diwa-community-site-unsetup' for a guided reset, or repair the repository and rerun setup."
    fi
    success "Local repository is up to date and GitHub access is working."
    return
  fi

  [[ ! -e "$WORKSPACE" ]] || fail "$WORKSPACE exists but is not a Git repository. Move or remove it, or run 'diwa-community-site-unsetup', then rerun setup."

  protocol="$(selected_git_protocol)"
  if ! run_with_spinner "Cloning ${BOLD}${fork}${RESET} into ${BOLD}${WORKSPACE}${RESET} using ${BOLD}${protocol}${RESET}..." gh repo clone "$fork" "$WORKSPACE"; then
    if [[ "$protocol" == "ssh" ]]; then
      warning "GitHub API authentication can remain valid even when an SSH key is missing."
      fail "The repository could not be cloned over SSH. Run 'diwa-community-site-unsetup' for a guided reset, verify SSH with 'ssh -T git@github.com', or switch to HTTPS with 'gh config set git_protocol https --host github.com'."
    fi

    fail "The repository could not be cloned over HTTPS. Run 'diwa-community-site-unsetup' for a guided reset or inspect 'gh auth status --active --hostname github.com'."
  fi
  success "Cloned the repository successfully."
}

configure_remotes() {
  local origin_url="$1"
  local upstream_url="$2"

  git -C "$WORKSPACE" remote set-url origin "$origin_url"
  if git -C "$WORKSPACE" remote get-url upstream >/dev/null 2>&1; then
    git -C "$WORKSPACE" remote set-url upstream "$upstream_url"
  else
    git -C "$WORKSPACE" remote add upstream "$upstream_url"
  fi
}

ensure_remotes() {
  local fork="$1"
  local protocol upstream_url origin_url
  protocol="$(selected_git_protocol)"

  heading 5 "Configure Git remotes"
  info "The origin remote points to your fork, while upstream points to the main DIWA Community Site repository."

  if [[ "$protocol" == "ssh" ]]; then
    origin_url="git@github.com:${fork}.git"
    upstream_url="git@github.com:${UPSTREAM_REPO}.git"
  else
    origin_url="https://github.com/${fork}.git"
    upstream_url="https://github.com/${UPSTREAM_REPO}.git"
  fi

  if ! run_with_spinner "Setting origin and upstream using ${BOLD}${protocol}${RESET}..." configure_remotes "$origin_url" "$upstream_url"; then
    fail "Git remotes could not be configured. Review the error above, then rerun setup."
  fi

  success "Git remotes are configured."
  printf '  origin:   %s\n' "$origin_url"
  printf '  upstream: %s\n' "$upstream_url"
}

write_state() {
  mkdir -p "$STATE_DIR"
  cat > "$STATE_FILE" <<EOF
{
  "version": 1,
  "display_name": "$DISPLAY_NAME",
  "workspace": "$WORKSPACE",
  "complete": true
}
EOF
}

print_summary() {
  printf '\n%s%sSetup summary%s\n\n' "$BOLD" "$CYAN" "$RESET"
  success "Shell configured"
  success "GitHub connected"
  success "Fork ready"
  success "Repository synchronized"
  success "Git remotes configured"

  printf '\n%s%s🎉 You’re all set!%s\n\n' "$BOLD" "$GREEN" "$RESET"
  important "Open 'Open DIWA Community Site Editor' from the JupyterLab launcher."
  printf 'Workspace: %s\n' "$WORKSPACE"
}

main() {
  command -v gh >/dev/null 2>&1 || fail "GitHub CLI is not installed."
  command -v git >/dev/null 2>&1 || fail "Git is not installed."

  printf '\n%s%s%s setup%s\n' "$BOLD" "$CYAN" "$DISPLAY_NAME" "$RESET"
  info "Setup checks the current environment and only performs actions that are needed."

  ensure_profile
  ensure_github_auth
  ensure_fork
  ensure_clone "$FORK"
  ensure_remotes "$FORK"
  write_state
  print_summary
}

main "$@"
