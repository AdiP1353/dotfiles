# git for the dotfiles: everything lives in one normal git repo (usually
# ~/dotfiles); the configs in your home folder are links into it. `dots push`,
# `dots status`... work from anywhere. The repo is found from this file's own
# link, so it works wherever you cloned it.
function dots --wraps git --description 'git for the dotfiles repo'
    set -l self (path resolve (functions --details dots))
    set -l repo (string replace -r '/\.config/fish/functions/dots\.fish$' '' -- $self)
    if test "$repo" = "$self"; or not test -d "$repo/.git"
        set repo $HOME/dotfiles
    end
    git -C $repo $argv
end
