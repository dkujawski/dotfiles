#!/usr/bin/env bash
# Define profile-specific entry points for the shared 1Password helpers.

if [[ -z "${DOTFILES_SECRETS_FILE+x}" && -n "${DOTFILES_HUMAN_SECRETS_FILE:-}" ]]; then
    export DOTFILES_SECRETS_FILE="${DOTFILES_HUMAN_SECRETS_FILE}"
fi
# shellcheck disable=SC1091
source "${DOTFILES_CONFIG_DIR:-${HOME}/.config/dotfiles}/lib/secrets.bash"
export DOTFILES_HUMAN_SECRETS_FILE="${DOTFILES_SECRETS_FILE}"

with-human-secrets() {
    _dotfiles_with_secrets with-human-secrets 'make human-deploy' "$@"
}

load-human-secrets() {
    _dotfiles_load_secrets 'make human-deploy'
}

# Compatibility entry point. This is explicit and never runs during profile startup.
load-secrets() {
    load-human-secrets "$@"
}
