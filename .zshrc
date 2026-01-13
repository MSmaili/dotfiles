# PATH management
typeset -U path  # Keep unique entries
path=(
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/.config/scripts"
    $path
)
export PATH

# ------------------------------------------------------------
# mise
# ------------------------------------------------------------
[[ -f /etc/os-release ]] && grep -q 'ubuntu' /etc/os-release && export MISE_ENV=ubuntu

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

# System-specific configs
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# ------------------------------------------------------------
# Zsh Options & Environment Variables
# ------------------------------------------------------------
setopt autocd              # Type directory name to cd
setopt correct             # Auto-correct minor typos
setopt no_beep             # Disable beep
setopt interactive_comments # Allow comments in interactive shell

HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTTIMEFORMAT="%F %T "
setopt sharehistory        # share across sessions
setopt appendhistory       # append instead of overwrite
setopt hist_ignore_space   # ignore commands starting with space
setopt hist_ignore_dups    # ignore all duplicates
setopt hist_find_no_dups   # ignore duplicates during search
setopt hist_reduce_blanks  # remove extra blanks

# Remove slash, equals, and hyphen from WORDCHARS
WORDCHARS="${WORDCHARS//[\/=\-]/}"

# Basic environment
export EDITOR=nvim
export TERM=xterm-256color
[[ -z "$DISPLAY" ]] && export DISPLAY=localhost:10.0

export XDG_CONFIG_HOME="$HOME/.config"

# ------------------------------------------------------------
# Zinit
# ------------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

ZSH_AUTOSUGGEST_USE_ASYNC=true
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# --- Plugins ---
zinit light agkozak/zsh-z                # Fast directory jump
zinit light zsh-users/zsh-completions    # Completions

# Load these with wait for faster startup
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light Aloxaf/fzf-tab               # FZF tab completion

zinit ice wait lucid atinit'zpcompinit; zpcdreplay'
zinit snippet OMZ::plugins/git/git.plugin.zsh

# Load syntax highlighting
zinit light zsh-users/zsh-syntax-highlighting

# Pure prompt
zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light sindresorhus/pure            # Prompt

# Create cache dir if it doesn't exist
[[ ! -d "$HOME/.zsh/cache" ]] && mkdir -p "$HOME/.zsh/cache"
autoload -Uz compinit
compinit -C -d "$HOME/.zsh/cache/zcompdump-${ZSH_VERSION}"
zinit cdreplay -q

# ------------------------------------------------------------
# Modular Configs
# ------------------------------------------------------------
for file in ~/.config/zsh/*.zsh(N); do
    [[ -r "$file" ]] && source "$file"
done

# Completion styles
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls -1 $realpath'
zstyle ':fzf-tab:*' fzf-flags --height=60%

# Lazy-load kubectl completion
if command -v kubectl >/dev/null 2>&1; then
    kubectl() {
        unfunction kubectl
        source <(command kubectl completion zsh)
        kubectl "$@"
    }
fi

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# ------------------------------------------------------------
# Aliases
# ------------------------------------------------------------
alias vi="nvim"
alias vim="nvim"
alias grep='grep --color=auto'
alias t="tmux attach || tmux"

#open btop if exists
if command -v btop >/dev/null 2>&1; then
    alias top="btop"
fi

# ls/eza aliases
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --group-directories-first'
    alias la='eza -lah --icons --group-directories-first'
    alias tree='eza --tree --icons'
else
    alias ls='ls --color'
    alias ll='ls -lh'
    alias la='ls -lah'
fi

# Docker aliases
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods | fzf'
alias kgs='kubectl get svc | fzf'
alias kgd='kubectl get deployments | fzf'
alias kl='kubectl logs -f'
alias kpf='kubectl port-forward'

# Hash directories for quick movement
hash -d dotfiles="$HOME/dotfiles"
hash -d nvim="$HOME/.config/nvim"

# Conditional aliases
command -v lazydocker >/dev/null 2>&1 && alias ld="lazydocker"
command -v bat >/dev/null 2>&1 && alias cat='bat -pp'
