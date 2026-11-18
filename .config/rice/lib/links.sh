# Shared by ~/dotfiles/install and `rice` (its "links" part): sourced, never
# run. One place for which repo files get linked into your home folder, so the
# two never disagree.

# Repo files that are not configs: never linked into ~.
dots_skip() {
    case "$1" in install|.gitignore|packages/*|.github/*) return 0 ;; esac
    return 1
}

# The dotfiles repo: the one this file lives in (wherever it was cloned),
# else ~/dotfiles.
dots_dir() {
    local self d
    self=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null) || self=
    d=${self%/.config/rice/lib/links.sh}
    if [ -n "$self" ] && [ "$d" != "$self" ] && [ -d "$d/.git" ]; then
        printf '%s' "$d"
    else
        printf '%s' "$HOME/dotfiles"
    fi
}

# Prints the first folder on the way to ~/<path> that is itself a link (a
# stow-style ~/.config/hypr -> another repo, say). Linking through it would
# put our links and backups inside that other folder, so callers skip it.
dots_parent_link() {
    local rel=${1%/*} p="$HOME" c
    [ "$rel" = "$1" ] && return 1          # directly in ~
    local IFS=/
    for c in $rel; do
        p="$p/$c"
        [ -L "$p" ] && { printf '%s' "$p"; return 0; }
    done
    return 1
}
