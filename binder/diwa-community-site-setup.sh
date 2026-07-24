#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NAME="DIWA Community Site Editor"
UPSTREAM_REPO="DigitalWaters-fi/community"
WORKSPACE="$HOME/diwa-community"
PROFILE="$HOME/.bash_profile"
BASHRC="$HOME/.bashrc"
STATE_DIR="$HOME/.config/diwa-community-site"
STATE_FILE="$STATE_DIR/setup-state.json"

say() { printf '\n%s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

ensure_profile() {
  say "Step 1: Configure the shell profile"
  touch "$BASHRC"
  if [[ ! -f "$PROFILE" ]] || ! grep -Fq '# DIWA Community Site Editor profile' "$PROFILE"; then
    cat >> "$PROFILE" <<'EOF'

# DIWA Community Site Editor profile
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
    echo "Updated $PROFILE."
  else
    echo "Profile configuration is already present."
  fi
}

active_github_login() {
  gh api user --jq .login 2>/dev/null
}

ensure_github_auth() {
  local login
  say "Step 2: Sign in to GitHub"

  if login="$(active_github_login)"; then
    echo "GitHub CLI is authenticated as $login."
    return
  fi

  echo "GitHub CLI is not authenticated with a usable active account."
  echo "A browser-based GitHub sign-in flow will open."
  echo "Choose HTTPS or SSH when prompted; either is supported."
  gh auth login --hostname github.com --web

  if ! login="$(active_github_login)"; then
    gh auth status --active --hostname github.com || true
    fail "GitHub authentication completed, but the active account could not access the GitHub API."
  fi

  echo "GitHub CLI is authenticated as $login."
}

selected_git_protocol() {
  gh config get git_protocol --host github.com 2>/dev/null || printf 'https\n'
}

ensure_fork() {
  say "Step 3: Find or create your fork"
  local login fork
  login="$(active_github_login)" || fail "The active GitHub account could not be identified."
  fork="$login/community"

  if gh repo view "$fork" >/dev/null 2>&1; then
    echo "Found fork: $fork"
  else
    echo "Creating fork of $UPSTREAM_REPO..."
    gh repo fork "$UPSTREAM_REPO" --clone=false --remote=false
  fi

  printf '%s\n' "$fork"
}

ensure_clone() {
  local fork="$1"
  local protocol
  say "Step 4: Clone or update the DIWA Community Site repository"

  if git -C "$WORKSPACE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Repository already exists at $WORKSPACE."
    echo "Pulling the latest changes to verify repository access..."
    if ! git -C "$WORKSPACE" pull --ff-only; then
      fail "The existing repository could not be updated. This may indicate broken GitHub or SSH configuration, local changes that prevent a fast-forward pull, or a changed remote. Run 'diwa-community-site-unsetup' for a guided reset, or repair the repository and rerun setup."
    fi
    return
  fi

  [[ ! -e "$WORKSPACE" ]] || fail "$WORKSPACE exists but is not a Git repository. Move or remove it, or run 'diwa-community-site-unsetup', then rerun setup."

  protocol="$(selected_git_protocol)"
  echo "Cloning $fork into $WORKSPACE using $protocol..."
  if ! gh repo clone "$fork" "$WORKSPACE"; then
    if [[ "$protocol" == "ssh" ]]; then
      fail "The repository could not be cloned over SSH. The GitHub API login may still be valid even when the SSH key is missing. Run 'diwa-community-site-unsetup' for a guided reset, verify SSH with 'ssh -T git@github.com', or switch to HTTPS with 'gh config set git_protocol https --host github.com'."
    fi

    fail "The repository could not be cloned over HTTPS. Run 'diwa-community-site-unsetup' for a guided reset or inspect 'gh auth status --active --hostname github.com'."
  fi
}

ensure_remotes() {
  local fork="$1"
  local protocol upstream_url origin_url
  protocol="$(selected_git_protocol)"

  if [[ "$protocol" == "ssh" ]]; then
    origin_url="git@github.com:${fork}.git"
    upstream_url="git@github.com:${UPSTREAM_REPO}.git"
  else
    origin_url="https://github.com/${fork}.git"
    upstream_url="https://github.com/${UPSTREAM_REPO}.git"
  fi

  say "Step 5: Validate Git remotes"
  git -C "$WORKSPACE" remote set-url origin "$origin_url"
  if git -C "$WORKSPACE" remote get-url upstream >/dev/null 2>&1; then
    git -C "$WORKSPACE" remote set-url upstream "$upstream_url"
  else
    git -C "$WORKSPACE" remote add upstream "$upstream_url"
  fi

  git -C "$WORKSPACE" remote -v
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

main() {
  command -v gh >/dev/null 2>&1 || fail "GitHub CLI is not installed."
  command -v git >/dev/null 2>&1 || fail "Git is not installed."

  say "$DISPLAY_NAME setup"
  echo "This workflow checks the current environment and resumes at each incomplete step."

  ensure_profile
  ensure_github_auth

  local fork
  fork="$(ensure_fork | tail -n 1)"
  ensure_clone "$fork"
  ensure_remotes "$fork"
  write_state

  say "Setup complete"
  echo "Open 'Open DIWA Community Site Editor' from the JupyterLab launcher."
  echo "Workspace: $WORKSPACE"
}

main "$@"
