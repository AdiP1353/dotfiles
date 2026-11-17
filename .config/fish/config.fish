source /usr/share/cachyos-fish-config/cachyos-config.fish

# Greeting: the sectioned specs (~/.config/fastfetch/config.jsonc), with an
# image on the left if ~/.config/fastfetch/logo.png exists (drawn by Kitty's
# image protocol; any PNG works, line art on a transparent background looks
# best). Without the image, just the specs.
function fish_greeting
    set -l logo ~/.config/fastfetch/logo.png
    if test -f $logo; and test "$TERM" = xterm-kitty
        fastfetch --logo-type kitty-direct --logo $logo \
            --logo-width 32 --logo-height 17 --logo-padding-top 1 --logo-padding-right 4
    else
        fastfetch
    end
end

if status is-interactive
    atuin init fish | source
end

zoxide init fish | source
alias vim=nvim

