# ============================================================================
# ZSH Configuration with Ubuntu Professional Theme
# ============================================================================

export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
source ~/.cargo/env
export ZSH="$HOME/.oh-my-zsh"

# ============================================================================
# Theme & Prompt Configuration
# ============================================================================

# Use a simple theme as base (we'll override the prompt)
ZSH_THEME="robbyrussell"

# Custom Ubuntu Professional-themed prompt
# Colors: burgundy/red theme matching terminal
autoload -U colors && colors

# Define custom colors
PROMPT_USER_COLOR="%F{196}"      # Bright red
PROMPT_DIR_COLOR="%F{213}"       # Light magenta/pink
PROMPT_GIT_COLOR="%F{220}"       # Yellow
PROMPT_SYMBOL_COLOR="%F{196}"    # Bright red
PROMPT_RESET="%f"

# Git branch display function
git_prompt_info() {
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        echo " ${PROMPT_GIT_COLOR}($branch)${PROMPT_RESET}"
    fi
}

# Set the prompt
PROMPT='${PROMPT_USER_COLOR}%n@%m${PROMPT_RESET}:${PROMPT_DIR_COLOR}%~${PROMPT_RESET}$(git_prompt_info)
${PROMPT_SYMBOL_COLOR}❯${PROMPT_RESET} '

# Right prompt with time
RPROMPT='%F{240}%*%f'

# ============================================================================
# History Configuration
# ============================================================================

HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS

# ============================================================================
# Plugins
# ============================================================================

plugins=(
    git                    # Git aliases and branch info
    zsh-autosuggestions   # Fish-like autosuggestions
    zsh-syntax-highlighting # Syntax highlighting for commands
)

source $ZSH/oh-my-zsh.sh

# ============================================================================
# Editor Configuration
# ============================================================================

if command -v nvim &> /dev/null; then
    export EDITOR='nvim'
    export VISUAL='nvim'
else
    export EDITOR='vim'
    export VISUAL='vim'
fi

export LANG=en_US.UTF-8
export CONDA_AUTO_ACTIVATE_BASE=false

# ============================================================================
# Syntax Highlighting Colors (Ubuntu Professional theme)
# ============================================================================

# Override zsh-syntax-highlighting colors to match theme
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

# ============================================================================
# Aliases - Navigation
# ============================================================================

alias sourcesh='source ~/.zshrc'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'
alias conf='cd ~/.config/'

# ============================================================================
# Aliases - Editor
# ============================================================================

alias n='nvim'
alias h='hyprland'
alias vim='nvim'
alias vi='nvim'

# Kitten SSH
alias ssh='kitten ssh'

# ============================================================================
# Aliases - Git
# ============================================================================

alias gst='git status'
alias gaa='git add .'
alias gcm='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'

# ============================================================================
# Aliases - Package Management
# ============================================================================

alias pac='sudo pacman'
alias pacs='pacman -Ss'        # Search packages
alias paci='sudo pacman -S'    # Install package
alias pacr='sudo pacman -R'    # Remove package
alias pacu='sudo pacman -Syu'  # System update

# ============================================================================
# Aliases - System Utilities
# ============================================================================

alias du='sudo du -sh'         # Show directory size with sudo
alias bt='sudo systemctl start bluetooth.service'
alias btstop='sudo systemctl stop bluetooth.service'

# ============================================================================
# Functions
# ============================================================================

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

# ============================================================================
# External Tools
# ============================================================================

# Starship prompt (commented out - using custom prompt above)
# eval "$(starship init zsh)"

# Conda initialization
if [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
fi

# Bob nvim version manager
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
