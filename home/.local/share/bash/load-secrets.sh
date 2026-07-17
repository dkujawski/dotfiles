#!/usr/bin/env bash
# Define opt-in 1Password helpers. Sourcing this module never resolves a credential.

export DOTFILES_HUMAN_SECRETS_FILE="${DOTFILES_HUMAN_SECRETS_FILE:-${DOTFILES_CONFIG_DIR:-${HOME}/.config/dotfiles}/secrets/agent.env}"

_dotfiles_human_require_op() {
    if ! command -v op >/dev/null 2>&1; then
        printf "Error: 1Password CLI 'op' is required. Install it and configure 1Password desktop integration.\n" >&2
        return 127
    fi
}

_dotfiles_validate_human_secrets_file() {
    if [[ ! -r "${DOTFILES_HUMAN_SECRETS_FILE}" ]]; then
        printf 'Error: 1Password environment file is missing at %s. Run `make human-deploy`.\n' \
            "${DOTFILES_HUMAN_SECRETS_FILE}" >&2
        return 1
    fi
}

with-human-secrets() {
    _dotfiles_human_require_op || return
    _dotfiles_validate_human_secrets_file || return
    if [[ "${1:-}" == -- ]]; then
        shift
    fi
    if [[ $# -eq 0 ]]; then
        printf 'Usage: with-human-secrets -- command [args ...]\n' >&2
        return 2
    fi
    op run --env-file="${DOTFILES_HUMAN_SECRETS_FILE}" -- "$@"
}

load-human-secrets() {
    local secret_name secret_reference secret_value
    _dotfiles_human_require_op || return
    _dotfiles_validate_human_secrets_file || return

    while IFS='=' read -r secret_name secret_reference || [[ -n "${secret_name}" ]]; do
        [[ -z "${secret_name}" || "${secret_name}" == \#* ]] && continue
        if [[ ! "${secret_name}" =~ ^[A-Z_][A-Z0-9_]*$ || "${secret_reference}" != op://* ]]; then
            printf 'Error: invalid 1Password mapping for %s in %s.\n' \
                "${secret_name}" "${DOTFILES_HUMAN_SECRETS_FILE}" >&2
            return 2
        fi
        if ! secret_value="$(op read "${secret_reference}")"; then
            printf 'Error: could not read %s from 1Password. Check `op whoami` and vault access.\n' \
                "${secret_name}" >&2
            return 1
        fi
        printf -v "${secret_name}" '%s' "${secret_value}"
        export "${secret_name?}"
        unset secret_value
    done <"${DOTFILES_HUMAN_SECRETS_FILE}"
}

# Compatibility entry point. This is explicit and never runs during profile startup.
load-secrets() {
    load-human-secrets "$@"
}
