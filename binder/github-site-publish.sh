#!/usr/bin/env bash

# Reusable GitHub Pages publishing helpers for setup scripts.
# Requires shell-ui-utils.sh (ui_run, ui_success, ui_warning, ui_fail).

PUBLISH_SITE_URL=""


github_pages_require_tools() {
  command -v quarto >/dev/null 2>&1 || ui_fail "Quarto is not installed."
}


github_pages_branch_exists() {
  local workspace="$1"

  git -C "$workspace" \
    ls-remote \
    --exit-code \
    --heads origin gh-pages \
    >/dev/null 2>&1
}


github_pages_publish_command() {
  local workspace="$1"

  (
    cd "$workspace"
    quarto publish gh-pages --no-prompt --no-browser
  )
}


github_pages_initial_publish() {
  local workspace="$1"

  if github_pages_branch_exists "$workspace"; then
    ui_success "Found existing published site content on the gh-pages branch."
    return
  fi

  if ! ui_run \
    "Rendering and publishing the DIWA Community Site for the first time..." \
    github_pages_publish_command "$workspace"; then
    ui_fail "The initial GitHub Pages publication failed. Review the Quarto output above, then rerun setup."
  fi

  ui_success "Published the initial site to the gh-pages branch (${UI_ELAPSED})."
}


github_pages_get_info_command() {
  local fork="$1"

  gh api \
    -H "Accept: application/vnd.github+json" \
    "repos/${fork}/pages" \
    --jq '[.source.branch // "", .source.path // "", .html_url // ""] | @tsv'
}


github_pages_probe_info_command() {
  local fork="$1"

  # GitHub returns 404 when the branch exists but Pages has not yet been enabled.
  # Suppress that expected diagnostic during the initial configuration check.
  github_pages_get_info_command "$fork" 2>/dev/null
}


github_pages_enable_command() {
  local fork="$1"

  gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    "repos/${fork}/pages" \
    -F build_type=legacy \
    -F 'source[branch]=gh-pages' \
    -F 'source[path]=/' \
    --silent
}


github_pages_update_source_command() {
  local fork="$1"

  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "repos/${fork}/pages" \
    -F build_type=legacy \
    -F 'source[branch]=gh-pages' \
    -F 'source[path]=/' \
    --silent
}


github_pages_wait_for_info_command() {
  local fork="$1"
  local attempts="${2:-10}"
  local delay_seconds="${3:-2}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if github_pages_get_info_command "$fork" 2>/dev/null; then
      return 0
    fi

    if ((attempt < attempts)); then
      sleep "$delay_seconds"
    fi
  done

  return 1
}


github_pages_capture_info() {
  local fork="$1"
  local branch path site_url

  if ! ui_run \
    "Waiting for GitHub Pages to finish provisioning..." \
    github_pages_wait_for_info_command "$fork"; then
    ui_fail "GitHub Pages was configured, but setup could not confirm the resulting site. Review the GitHub repository settings, then rerun setup."
  fi

  IFS=$'\t' read -r branch path site_url <<<"$UI_OUTPUT"

  if [[ "$branch" != "gh-pages" || "$path" != "/" ]]; then
    ui_fail "GitHub Pages is not publishing from the gh-pages branch root as expected. Review the repository's Pages settings, then rerun setup."
  fi

  PUBLISH_SITE_URL="$site_url"
}


github_pages_ensure_enabled() {
  local fork="$1"
  local branch path site_url

  if ui_run "Checking whether GitHub Pages is enabled..." github_pages_probe_info_command "$fork"; then
    IFS=$'\t' read -r branch path site_url <<<"$UI_OUTPUT"

    if [[ "$branch" == "gh-pages" && "$path" == "/" ]]; then
      PUBLISH_SITE_URL="$site_url"
      ui_success "GitHub Pages is already configured to publish from the gh-pages branch (${UI_ELAPSED})."
      return
    fi

    ui_warning "GitHub Pages is enabled, but it is not publishing from the gh-pages branch root."
    if ! ui_run "Updating the GitHub Pages source..." github_pages_update_source_command "$fork"; then
      ui_fail "The GitHub Pages source could not be updated. Review the error above, then rerun setup."
    fi
    ui_success "Updated the GitHub Pages source (${UI_ELAPSED})."
  else
    ui_info "The gh-pages branch exists, but GitHub Pages has not yet been enabled for this fork."
    if ! ui_run "Enabling GitHub Pages from the gh-pages branch..." github_pages_enable_command "$fork"; then
      ui_fail "GitHub Pages could not be enabled. Review the error above, then rerun setup."
    fi
    ui_success "Enabled GitHub Pages (${UI_ELAPSED})."
  fi

  github_pages_capture_info "$fork"
}


github_pages_site_url() {
  local fork="$1"

  if [[ -n "$PUBLISH_SITE_URL" ]]; then
    printf '%s\n' "$PUBLISH_SITE_URL"
    return
  fi

  gh api \
    -H "Accept: application/vnd.github+json" \
    "repos/${fork}/pages" \
    --jq .html_url
}
