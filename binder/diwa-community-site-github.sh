#!/usr/bin/env bash

# Reusable GitHub CLI helpers for setup scripts.
# Requires diwa-community-site-ui.sh (ui_run, ui_success, ui_warning, ui_fail).

GITHUB_LOGIN=""
GITHUB_FORK=""

 github_active_login() {
  gh api user --jq .login 2>/dev/null
}

github_selected_protocol() {
  gh config get git_protocol --host github.com 2>/dev/null || printf 'https\n'
}

github_require_tools() {
  command -v gh >/dev/null 2>&1 || ui_fail "GitHub CLI is not installed."
  command -v git >/dev/null 2>&1 || ui_fail "Git is not installed."
}

github_ensure_auth() {
  if ui_run "Checking the active GitHub CLI login..." github_active_login; then
    GITHUB_LOGIN="$UI_OUTPUT"
    ui_success "Authenticated with GitHub as ${UI_BOLD}${GITHUB_LOGIN}${UI_RESET} (${UI_ELAPSED})."
    return
  fi

  ui_warning "No usable active GitHub login was found."
  ui_prompt "GitHub CLI will open a browser and ask you to sign in."
  ui_important "Complete the browser authorization, then return to this terminal."
  echo
  gh auth login --hostname github.com --web

  if ! ui_run "Verifying the new GitHub login..." github_active_login; then
    gh auth status --active --hostname github.com || true
    ui_fail "GitHub sign-in finished, but the active account still cannot access the GitHub API."
  fi

  GITHUB_LOGIN="$UI_OUTPUT"
  ui_success "Authenticated with GitHub as ${UI_BOLD}${GITHUB_LOGIN}${UI_RESET} (${UI_ELAPSED})."
}

github_ensure_fork() {
  local upstream_repo="$1"
  local fork_name="${2:-${upstream_repo##*/}}"

  [[ -n "$GITHUB_LOGIN" ]] || GITHUB_LOGIN="$(github_active_login)" || ui_fail "The active GitHub account could not be identified."
  GITHUB_FORK="${GITHUB_LOGIN}/${fork_name}"

  if ui_run "Looking for ${UI_BOLD}${GITHUB_FORK}${UI_RESET}..." gh repo view "$GITHUB_FORK"; then
    ui_success "Found your existing fork: ${UI_BOLD}${GITHUB_FORK}${UI_RESET} (${UI_ELAPSED})."
    return
  fi

  ui_warning "No fork was found for this account."
  if ! ui_run "Creating a fork of ${UI_BOLD}${upstream_repo}${UI_RESET}..." gh repo fork "$upstream_repo" --clone=false; then
    ui_fail "GitHub could not create your fork. Review the error above, then rerun setup."
  fi
  ui_success "Created your fork: ${UI_BOLD}${GITHUB_FORK}${UI_RESET} (${UI_ELAPSED})."
}

github_sync_clone() {
  local fork="$1"
  local workspace="$2"
  local reset_command="${3:-}"
  local protocol recovery

  recovery="Repair the repository and rerun setup."
  [[ -z "$reset_command" ]] || recovery="Run '${reset_command}' for a guided reset, or repair the repository and rerun setup."

  if git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ui_success "Found the local repository at ${UI_BOLD}${workspace}${UI_RESET}."
    if ! ui_run "Pulling the latest changes and verifying GitHub access..." git -C "$workspace" pull --ff-only; then
      ui_warning "The local repository could not be updated."
      ui_fail "GitHub or SSH access may be broken, the remote may have changed, or local history may prevent a fast-forward pull. ${recovery}"
    fi
    ui_success "Local repository is up to date and GitHub access is working (${UI_ELAPSED})."
    return
  fi

  [[ ! -e "$workspace" ]] || ui_fail "$workspace exists but is not a Git repository. ${recovery}"

  protocol="$(github_selected_protocol)"
  if ! ui_run "Cloning ${UI_BOLD}${fork}${UI_RESET} into ${UI_BOLD}${workspace}${UI_RESET} using ${UI_BOLD}${protocol}${UI_RESET}..." gh repo clone "$fork" "$workspace"; then
    if [[ "$protocol" == "ssh" ]]; then
      ui_warning "GitHub API authentication can remain valid even when an SSH key is missing."
      ui_fail "The repository could not be cloned over SSH. Verify SSH with 'ssh -T git@github.com', switch to HTTPS with 'gh config set git_protocol https --host github.com', or ${recovery}"
    fi
    ui_fail "The repository could not be cloned over HTTPS. Inspect 'gh auth status --active --hostname github.com', or ${recovery}"
  fi
  ui_success "Cloned the repository successfully (${UI_ELAPSED})."
}

github_configure_remotes_command() {
  local workspace="$1"
  local origin_url="$2"
  local upstream_url="$3"

  git -C "$workspace" remote set-url origin "$origin_url"
  if git -C "$workspace" remote get-url upstream >/dev/null 2>&1; then
    git -C "$workspace" remote set-url upstream "$upstream_url"
  else
    git -C "$workspace" remote add upstream "$upstream_url"
  fi
}

github_configure_remotes() {
  local fork="$1"
  local upstream_repo="$2"
  local workspace="$3"
  local protocol origin_url upstream_url

  protocol="$(github_selected_protocol)"
  if [[ "$protocol" == "ssh" ]]; then
    origin_url="git@github.com:${fork}.git"
    upstream_url="git@github.com:${upstream_repo}.git"
  else
    origin_url="https://github.com/${fork}.git"
    upstream_url="https://github.com/${upstream_repo}.git"
  fi

  if ! ui_run "Setting origin and upstream using ${UI_BOLD}${protocol}${UI_RESET}..." github_configure_remotes_command "$workspace" "$origin_url" "$upstream_url"; then
    ui_fail "Git remotes could not be configured. Review the error above, then rerun setup."
  fi

  ui_success "Git remotes are configured (${UI_ELAPSED})."
  printf '  origin:   %s\n' "$origin_url"
  printf '  upstream: %s\n' "$upstream_url"
}
