PUBLISH_SITE_URL=""

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
        ui_success "The GitHub Pages branch is already initialized."
        return
    fi

    if ! ui_run \
        "Rendering and publishing the DIWA Community Site for the first time..." \
        github_pages_publish_command "$workspace"; then
        ui_fail "The initial GitHub Pages publication failed. Review the Quarto output above, then rerun setup."
    fi

    ui_success "Published the initial site to the gh-pages branch (${UI_ELAPSED})."
}
