# CachyOS's fish defaults, when they're there (not on plain Arch)
test -f /usr/share/cachyos-fish-config/cachyos-config.fish; and source /usr/share/cachyos-fish-config/cachyos-config.fish

# Greeting: the boxed specs (~/.config/fastfetch/config.jsonc) with your image
# (~/.config/fastfetch/logo.png) on the left: drawn with Kitty's image
# protocol in Kitty, as coloured text blocks (logo.ansi) in any other terminal, so it
# shows everywhere instead of text art.
function fish_greeting
    set -l logo ~/.config/fastfetch/logo.png
    if not test -f $logo
        fastfetch
    else if test "$TERM" = xterm-kitty
        fastfetch --logo-type kitty-direct --logo $logo \
            --logo-width 36 --logo-height 11 --logo-padding-top 2 --logo-padding-right 3
    else
        # logo.ansi: the picture as coloured blocks (make-logo.py), works anywhere
        test -f ~/.config/fastfetch/logo.ansi; or python3 -I ~/.config/fastfetch/make-logo.py >/dev/null
        fastfetch --logo-type file-raw --logo ~/.config/fastfetch/logo.ansi \
            --logo-padding-top 2 --logo-padding-right 3
    end
end

if status is-interactive
    command -q atuin; and atuin init fish | source
end

command -q zoxide; and zoxide init fish | source
alias vim=nvim


# fzf in the rice's style: the terminal's own 16 colours, square border,
# "search:" prompt like the launcher (THEME.md §3)
set -gx FZF_DEFAULT_OPTS "--color=16 --border=sharp --prompt='search: ' --pointer='›' --marker='*' --info=inline-right --no-scrollbar"
set -gx BAT_THEME ansi
