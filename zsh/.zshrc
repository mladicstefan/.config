# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
source ~/.cargo/env
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS

plugins=(
    git                    # Git aliases and branch info
    zsh-autosuggestions   # Fish-like autosuggestions
    zsh-syntax-highlighting # Syntax highlighting for commands
)

source $ZSH/oh-my-zsh.sh

if command -v nvim &> /dev/null; then
    export EDITOR='nvim'
    export VISUAL='nvim'
else
    export EDITOR='vim'
    export VISUAL='vim'
fi

export LANG=en_US.UTF-8
#shell
alias sourcesh='source ~/.config/zsh/.zshrc'
export CONDA_AUTO_ACTIVATE_BASE=false
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'
alias conf='cd ~/.config/'
# Editor shortcuts
alias n='nvim'
alias h='hyprland'
alias vim='nvim'
alias vi='nvim'


# Git shortcuts
alias gst='git status'
alias gaa='git add .'
alias gcm='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'

alias pac='sudo pacman'
alias pacs='pacman -Ss'        # Search packages
alias paci='sudo pacman -S'    # Install package
alias pacr='sudo pacman -R'    # Remove package
alias pacu='sudo pacman -Syu'  # System update

# System utilities
alias du='sudo du -sh'         # Show directory size with sudo

# Create directory and cd into it
# Usage: mkcd my-new-folder
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract any archive format
# Usage: extract archive.tar.gz
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

eval "$(starship init zsh)"

if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
fi
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
