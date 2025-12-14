# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------
# LazyGit with lock file handling
lg() {
    if ! command -v lazygit >/dev/null 2>&1; then
        echo "lazygit not installed"
        return 1
    fi

    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local lock_file="${git_dir}/index.lock"
        if [[ -f "$lock_file" ]]; then
            echo "Removing stale lock file: $lock_file"
            rm "$lock_file"
        fi
    fi
    command lazygit "$@"
}

# Git diff with fzf preview
gdiff() {
    local args="$*"
    local preview_cmd
    if command -v delta >/dev/null 2>&1; then
        preview_cmd="git diff $args --color=always -- {-1} | delta --side-by-side --width \${FZF_PREVIEW_COLUMNS:-\$COLUMNS}"
    else
        preview_cmd="git diff $args --color=always -- {-1}"
    fi
    git diff "$@" --name-only | fzf -m --ansi --preview "$preview_cmd" \
        --layout=reverse --height=100% --preview-window=down:90%
}

# CD to git root
cdg() {
    local root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$root" ]]; then
        cd "$root"
    else
        echo "Not in a git repository"
    fi
}

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.Z)       uncompress "$1" ;;
            *.7z)      7z x "$1" ;;
            *.rar)     unrar x "$1" ;;
            *)         echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Compress a file/folder to a desired archive
compress() {
    if (( $# < 2 )); then
        echo "Usage: compress file_or_dir... archive"
        return 1
    fi

    archive="${argv[-1]}"
    inputs=("${(@)argv[1,-2]}")

    case "$archive" in
        *.tar.bz2|*.tbz2) tar cjf "$archive" -- "${inputs[@]}" ;;
        *.tar.gz|*.tgz)   tar czf "$archive" -- "${inputs[@]}" ;;
        *.tar.xz)        tar cJf "$archive" -- "${inputs[@]}" ;;
        *.tar)           tar cf  "$archive" -- "${inputs[@]}" ;;
        *.zip)           zip -r  "$archive" -- "${inputs[@]}" ;;
        *)
            echo "'$archive' has an unsupported format"
            return 1
            ;;
    esac
}

# Fuzzy find and kill process
fkill() {
    command -v fzf >/dev/null 2>&1 || { echo "Install fzf first!"; exit 1; }
    local pid
    pid=$(ps -ef | sed 1d | fzf -m --height=60% --layout=reverse \
            --header='Select process to kill' \
            --preview 'ps -fp {2}' \
        --preview-window=down:40% | awk '{print $2}')

    if [ -n "$pid" ]; then
        echo "$pid" | xargs kill -"${1:-9}"
        echo "Killed process(es): $pid"
    fi
}

ovi() {
    command -v fzf >/dev/null 2>&1 || { echo "Install fzf first!"; exit 1; }
    local file
    file=$(fzf --preview="bat --style=numbers --color=always {}" --height=40% --reverse)
    [[ -n "$file" ]] && nvim "$file"
}
