export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
source ~/.cargo/env
export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

#tmux
if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
    tmux attach-session -t main || tmux new-session -s main
fi

ZSH_THEME="robbyrussell"

autoload -U colors && colors

PROMPT_USER_COLOR="%F{196}"      # Bright red
PROMPT_DIR_COLOR="%F{213}"       # Light magenta/pink
PROMPT_GIT_COLOR="%F{220}"       # Yellow
PROMPT_SYMBOL_COLOR="%F{196}"    # Bright red
PROMPT_RESET="%f"

git_prompt_info() {
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        echo " ${PROMPT_GIT_COLOR}($branch)${PROMPT_RESET}"
    fi
}

PROMPT='${PROMPT_USER_COLOR}%n@%m${PROMPT_RESET}:${PROMPT_DIR_COLOR}%~${PROMPT_RESET}$(git_prompt_info)
${PROMPT_SYMBOL_COLOR}❯${PROMPT_RESET} '

RPROMPT='%F{240}%*%f'
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
export CONDA_AUTO_ACTIVATE_BASE=false


ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green'
ZSH_HIGHLIGHT_STYLES[function]='fg=blue'
ZSH_HIGHLIGHT_STYLES[command-substitution]='fg=magenta'
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=blue,bold'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=yellow'

alias sourcesh='source ~/.zshrc'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'
alias conf='cd ~/.config/'
alias n='nvim'
alias h='hyprland'
alias vim='nvim'
alias vi='nvim'
alias ssh='kitten ssh' #for proper TTY upon ssh
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
alias du='sudo du -sh'         # Show directory size with sudo
alias bt='sudo systemctl start bluetooth.service'
alias btstop='sudo systemctl stop bluetooth.service'
#mkdir & cd
mkcd() {
    mkdir -p "$1" && cd "$1"
}
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
if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
fi
