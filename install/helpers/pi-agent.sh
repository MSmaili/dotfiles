#!/usr/bin/env bash

prepare_pi_agent() {
    local agent_dir="$HOME/.pi/agent"

    # Keep mutable resource directories outside the Stow package so adding a
    # local extension, prompt, or theme does not write into the dotfiles repo.
    run_cmd mkdir -p \
        "$agent_dir/extensions" \
        "$agent_dir/prompts" \
        "$agent_dir/themes"
}

install_pi_agent() {
    echo "📦 Installing Pi..."
    run_cmd npm install -g --prefix "$HOME/.local" @earendil-works/pi-coding-agent@latest
}
