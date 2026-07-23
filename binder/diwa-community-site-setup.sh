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

github_authenticated() {
  gh auth status --hostname github.com >/dev/null 2>&1
}

ensure_github_auth() {
  say "Step 2: Sign in to GitHub"
  if github_authenticated; then
    gh auth status --hostname github.com
    return
  fi

  echo "GitHub CLI will open a browser-based sign-in flow."
  echo "Choose HTTPS or SSH when prompted; either is supported."
  gh auth login --hostname github.com --web
  github_authenticated || fail "GitHub authentication did not complete successfully."
}

repair_private_key_permissions() {
  say "Step 3: Validate SSH private-key permissions"
  local ssh_dir="$HOME/.ssh"
  local pub private mode repaired=0

  if [[ ! -d "$ssh_dir" ]]; then
    echo "No ~/.ssh directory exists; nothing to validate."
    return
  fi

  chmod 700 "$ssh_dir"

  while IFS= read -r -d '' pub; do
    private="${pub%.pub}"
    [[ -f "$private" ]] || continue
    mode="$(stat -c '%a' "$private")"
    if [[ "$mode" != "600" ]]; then
      echo "Restricting $private from $mode to 600."
      chmod 600 "$private"
      repaired=1
    fi
  done < <(find "$ssh_dir" -maxdepth 1 -type f -name '*.pub' -print0)

  if [[ "$repaired" -eq 0 ]]; then
    echo "Existing SSH private keys already have mode 600, or no paired private keys were found."
  fi
}

selected_git_protocol() {
  gh config get git_protocol --host github.com 2>/dev/null || printf 'https\n'
}

validate_ssh_if_selected() {
  local protocol
  protocol="$(selected_git_protocol)"
  say "Step 4: Validate the selected Git protocol ($protocol)"

  if [[ "$protocol" != "ssh" ]]; then
    echo "HTTPS is selected; SSH connectivity testing is not required."
    return
  fi

  echo "Testing SSH access to GitHub..."
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
    echo "SSH authentication is working."
  else
    echo "SSH authentication could not be confirmed automatically."
    echo "GitHub CLI may still have uploaded or generated a key during sign-in."
    echo "Run 'ssh -T git@github.com' to inspect the result before using SSH remotes."
  fi
}

ensure_fork() {
  say "Step 5: Find or create your fork"
  local login fork
  login="$(gh api user --jq .login)"
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
  say "Step 6: Clone or validate the DIWA Community Site repository"

  if git -C "$WORKSPACE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Repository already exists at $WORKSPACE."
    return
  fi

  [[ ! -e "$WORKSPACE" ]] || fail "$WORKSPACE exists but is not a Git repository. Move or remove it, then rerun setup."

  echo "Cloning $fork into $WORKSPACE..."
  gh repo clone "$fork" "$WORKSPACE"
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

  say "Step 7: Validate Git remotes"
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
  repair_private_key_permissions
  validate_ssh_if_selected

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
