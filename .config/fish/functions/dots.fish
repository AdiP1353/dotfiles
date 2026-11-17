# git for the dotfiles repo (bare repo in ~/.dotfiles, work tree = $HOME)
function dots --wraps git --description 'git for the dotfiles repo'
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
end
