# Minimal prompt (THEME.md §3): one line, the short path in dim grey, a `*`
# when the git repo has changes, then `›`. The `›` turns red when the last
# command failed. Example:   ~/.c/quickshell/wallhaven * ›
function fish_prompt
    set -l last $status
    set -l dim (set_color brblack)
    set -l normal (set_color normal)

    # the path, shortened the fish way (~/.c/q/wallhaven)
    printf '%s%s%s' $dim (prompt_pwd --full-length-dirs 2) $normal

    # git: a single `*` when there are uncommitted changes
    if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        if test -n "$(command git status --porcelain --ignore-submodules 2>/dev/null | head -1)"
            printf ' %s*%s' $dim $normal
        end
    end

    # the prompt character: plain, or red after a failed command
    if test $last -ne 0
        printf ' %s›%s ' (set_color red) $normal
    else
        printf ' %s›%s ' (set_color white) $normal
    end
end
