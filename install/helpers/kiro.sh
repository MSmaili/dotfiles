#!/usr/bin/env bash

prepare_kiro() {
    run_cmd mkdir -p \
        "$HOME/.kiro/agents" \
        "$HOME/.kiro/settings" \
        "$HOME/.kiro/steering" \
        "$HOME/.kiro/sessions"
}
