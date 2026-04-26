# ------------------------------------------------------------
# FZF Configuration
# ------------------------------------------------------------
if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow \
                                --exclude .git \
                                --exclude node_modules \
                                --exclude dist \
                                --exclude build \
                                --exclude target \
                                --exclude .next \
                                --exclude coverage'
else
    export FZF_DEFAULT_COMMAND='find . -type f 2>/dev/null'
fi

export FZF_DEFAULT_OPTS='
--height=30%
--border=rounded
--layout=reverse
--bind "ctrl-n:down"
--bind "ctrl-p:up"
--bind "ctrl-y:accept"
--bind "ctrl-d:preview-down"
--bind "ctrl-u:preview-up"
--bind "ctrl-f:preview-page-down"
--bind "ctrl-b:preview-page-up"
--bind "alt-p:toggle-preview"
--ansi
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,\
fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,\
marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8\
'
export FZF_CTRL_R_OPTS="--layout=reverse"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi
