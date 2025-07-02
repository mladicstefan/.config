if status is-interactive
    # Commands to run in interactive sessions can go here
    set -U fish_greeting (echo -e "\033[1;32mWelcome back, \033[1;34msir\033[0m! ")
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/djamla/anaconda3/bin/conda
    eval /home/djamla/anaconda3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/home/djamla/anaconda3/etc/fish/conf.d/conda.fish"
        . "/home/djamla/anaconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/djamla/anaconda3/bin" $PATH
    end
end
# <<< conda initialize <<<

