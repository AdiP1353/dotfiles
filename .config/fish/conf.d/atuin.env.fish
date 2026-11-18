# atuin's own installer puts it in ~/.atuin/bin (not on PATH until this runs).
# Skipped when atuin came from pacman or isn't installed at all.
test -f "$HOME/.atuin/bin/env.fish"; and source "$HOME/.atuin/bin/env.fish"
