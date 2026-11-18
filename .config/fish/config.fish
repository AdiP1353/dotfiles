source /usr/share/cachyos-fish-config/cachyos-config.fish

# Greeting: the boxed specs (~/.config/fastfetch/config.jsonc) with your
# picture on the left as ASCII art (logo.ansi), tinted from the wallpaper by
# ~/.config/fastfetch/make-logo.py (re-run on every wallpaper change).
function fish_greeting
    set -l art ~/.config/fastfetch/logo.ansi
    test -f $art; or python3 -I ~/.config/fastfetch/make-logo.py 40 >/dev/null 2>&1
    if test -f $art
        fastfetch --logo-type file-raw --logo $art --logo-padding-top 6 --logo-padding-right 3
    else
        fastfetch
    end
end

if status is-interactive
    atuin init fish | source
end

zoxide init fish | source
alias vim=nvim


# fzf in the rice's style: the terminal's own 16 colours, square border,
# "search:" prompt like the launcher (THEME.md §3)
set -gx FZF_DEFAULT_OPTS "--color=16 --border=sharp --prompt='search: ' --pointer='›' --marker='*' --info=inline-right --no-scrollbar"
set -gx BAT_THEME ansi
