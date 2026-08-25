#!/usr/bin/env bash
set -euo pipefail

GIT_DIR="${GIT_DIR:-$HOME/git}"

usage() {
    echo "Usage: $(basename "$0") [browse|rest]" >&2
    echo "  no argument: open the selected repository with codium" >&2
    echo "  browse:      open the current repository remote in the browser" >&2
    echo "  rest:        hard reset the selected repository to latest origin/main or origin/master" >&2
}

die() {
    echo "Error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

setup_status() {
    local repo="$1"
    local missing=()
    local hook_path
    local current_name current_email

    current_name="$(git -C "$repo" config --local --get user.name 2>/dev/null || true)"
    current_email="$(git -C "$repo" config --local --get user.email 2>/dev/null || true)"
    [[ -n "$current_name" ]] || missing+=("user.name")
    [[ -n "$current_email" ]] || missing+=("user.email")
    if [[ "${current_name,,}" == *fuog* || "${current_email,,}" == *fuog* ]]; then
        missing+=("stale-fuog-identity")
    fi

    if [[ -f "$repo/.pre-commit-config.yaml" ]]; then
        hook_path="$(git -C "$repo" rev-parse --git-path hooks/pre-commit)"
        [[ "$hook_path" == /* ]] || hook_path="$repo/$hook_path"
        [[ -x "$hook_path" ]] || missing+=("pre-commit")
    fi

    if ((${#missing[@]} == 0)); then
        echo "ok"
    else
        local IFS=","
        echo "missing:${missing[*]}"
    fi
}

current_branch() {
    local repo="$1"

    git -C "$repo" branch --show-current 2>/dev/null || true
}

display_branch() {
    local repo="$1"
    local branch

    branch="$(current_branch "$repo")"
    if [[ -n "$branch" ]]; then
        echo "$branch"
    else
        echo "detached"
    fi
}

repo_name() {
    local repo="$1"

    basename "$repo"
}

last_commit_message() {
    local repo="$1"

    git -C "$repo" log -1 --pretty=%s 2>/dev/null || echo "no commits"
}

is_toplevel_repo() {
    local repo="$1"
    local parent_top

    parent_top="$(git -C "$repo/.." rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -z "$parent_top" ]]
}

repo_rows() {
    [[ -d "$GIT_DIR" ]] || die "GIT_DIR does not exist: $GIT_DIR"

    find "$GIT_DIR" -name .git -print0 \
        | while IFS= read -r -d '' marker; do
            local repo
            repo="$(dirname "$marker")"
            git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
            is_toplevel_repo "$repo" || continue
            git -C "$repo" rev-parse --show-toplevel
        done \
        | sort -u \
        | while IFS= read -r repo; do
            printf "%-38s  %-24s  %s\t%s\n" \
                "$(repo_name "$repo")" \
                "$(display_branch "$repo")" \
                "$(last_commit_message "$repo")" \
                "$repo"
        done
}

select_repo() {
    local selected

    selected="$(
        repo_rows \
            | fzf \
                --delimiter=$'\t' \
                --with-nth=1 \
                --header="$(printf "%-38s  %-24s  %s" "Repository" "Branch" "Message")" \
                --preview='git -C {2} status --short --branch' \
                --preview-window=down,40%
    )"

    [[ -n "$selected" ]] || exit 1
    echo "${selected##*$'\t'}"
}

default_origin_branch() {
    local repo="$1"
    local origin_head

    origin_head="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [[ -n "$origin_head" ]]; then
        echo "${origin_head#origin/}"
        return 0
    fi

    if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main; then
        echo "main"
    elif git -C "$repo" show-ref --verify --quiet refs/remotes/origin/master; then
        echo "master"
    else
        return 1
    fi
}

open_repo() {
    local repo="$1"

    require_command codium
    codium "$repo"
}

current_repo() {
    git rev-parse --show-toplevel 2>/dev/null || die "current directory is not inside a git repository"
}

remote_web_url() {
    local repo="$1"
    local remote

    remote="$(git -C "$repo" remote get-url origin 2>/dev/null)" || die "repository has no origin remote: $repo"
    remote="${remote%.git}"

    case "$remote" in
        git@*:*)
            echo "https://${remote#git@}" | sed 's/:/\//'
            ;;
        ssh://git@*)
            echo "https://${remote#ssh://git@}"
            ;;
        http://*|https://*)
            echo "$remote"
            ;;
        *)
            die "cannot convert origin remote to browser URL: $remote"
            ;;
    esac
}

open_url() {
    local url="$1"

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 &
    elif command -v sensible-browser >/dev/null 2>&1; then
        sensible-browser "$url" >/dev/null 2>&1 &
    else
        echo "$url"
        die "no browser opener found (tried xdg-open and sensible-browser)"
    fi
}

browse_repo() {
    local repo="$1"
    local url

    ensure_git_setup "$repo"
    url="$(remote_web_url "$repo")"
    echo "Opening $url"
    open_url "$url"
}

ensure_git_setup() {
    local repo="$1"
    local status

    status="$(setup_status "$repo")"
    [[ "$status" == "ok" ]] && return 0

    echo "Running git_setup for $repo ($status)"
    require_command zsh
    zsh -ic 'cd "$1" && git_setup' git_setup_runner "$repo"

    status="$(setup_status "$repo")"
    [[ "$status" == "ok" ]] || die "git_setup is still incomplete for $repo ($status)"
}

reset_repo() {
    local repo="$1"
    local branch
    local answer

    git -C "$repo" fetch origin --prune
    branch="$(default_origin_branch "$repo")" || die "could not find origin/main or origin/master for $repo"

    echo "Repository: $repo"
    echo "Target:     origin/$branch"
    echo "This will discard local changes in the selected repository."
    read -r -p "Hard reset this repository? [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || die "aborted"

    git -C "$repo" checkout -B "$branch" "origin/$branch"
    git -C "$repo" reset --hard "origin/$branch"
}

main() {
    local mode="${1:-codium}"
    local repo

    case "$mode" in
        codium)
            require_command fzf
            repo="$(select_repo)"
            ensure_git_setup "$repo"
            open_repo "$repo"
            ;;
        rest)
            require_command fzf
            repo="$(select_repo)"
            ensure_git_setup "$repo"
            reset_repo "$repo"
            ;;
        browse)
            repo="$(current_repo)"
            browse_repo "$repo"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

main "$@"
