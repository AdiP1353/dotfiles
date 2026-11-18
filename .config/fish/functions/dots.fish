# git for the dotfiles: everything lives in ~/dotfiles (a normal git repo);
# the configs in your home folder are links into it. `dots push`, `dots status`...
# work from anywhere.
function dots --wraps git --description 'git for ~/dotfiles'
    git -C $HOME/dotfiles $argv
end
