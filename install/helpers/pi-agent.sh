#!/usr/bin/env bash

prepare_pi_agent() {
    local agent_dir="$HOME/.pi/agent"
    local vault_policy="$HOME/.vaults/personal/ai/project-vault-policy.md"
    local global_context="$agent_dir/AGENTS.md"

    # Keep mutable resource directories outside the Stow package so adding a
    # local extension, prompt, or theme does not write into the dotfiles repo.
    run_cmd mkdir -p \
        "$agent_dir/extensions" \
        "$agent_dir/prompts" \
        "$agent_dir/themes"

    # Pi loads this file in every session. Keep the vault copy canonical while
    # preserving any existing user-owned global context file.
    if [[ ! -e "$global_context" && ! -L "$global_context" ]]; then
        run_cmd ln -s "$vault_policy" "$global_context"
    elif [[ ! -L "$global_context" ]]; then
        echo "Pi global context already exists; leaving $global_context unchanged."
    fi
}
