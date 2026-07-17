# shellcheck shell=bash

if [[ "${DOTFILES_AGENT_PROFILE_LOADED:-0}" == 1 ]]; then
    return 0 2>/dev/null || exit 0
fi
export DOTFILES_AGENT_PROFILE_LOADED=1
export DOTFILES_PROFILE=agent

_dotfiles_path_prepend() {
    [[ -d "$1" ]] || return 0
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) PATH="$1${PATH:+:${PATH}}" ;;
    esac
}

_dotfiles_path_append() {
    [[ -d "$1" ]] || return 0
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) PATH="${PATH:+${PATH}:}$1" ;;
    esac
}

_dotfiles_path_prepend "${HOME}/.local/bin"
DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX:-/opt/homebrew}"
_dotfiles_path_append "${DOTFILES_HOMEBREW_PREFIX}/bin"
_dotfiles_path_append "${DOTFILES_HOMEBREW_PREFIX}/sbin"
export PATH
export DOTFILES_HOMEBREW_PREFIX
unset -f _dotfiles_path_prepend _dotfiles_path_append

# Automation-safe defaults: never open a pager, editor, prompt, or package update.
export PAGER=cat
export GIT_PAGER=cat
export GH_PAGER=cat
export SYSTEMD_PAGER=cat
export GIT_EDITOR=true
export GIT_SEQUENCE_EDITOR=true
export GIT_TERMINAL_PROMPT=0
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export PYTHONIOENCODING=UTF-8
export PYTHONUNBUFFERED=1
export BASH_SILENCE_DEPRECATION_WARNING=1
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

export DOTFILES_SECRETS_FILE="${DOTFILES_SECRETS_FILE:-${DOTFILES_CONFIG_DIR}/secrets/agent.env}"
export DOTFILES_OP_SSH_AUTH_SOCK="${DOTFILES_OP_SSH_AUTH_SOCK:-${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"
if [[ -S "${DOTFILES_OP_SSH_AUTH_SOCK}" ]]; then
    export SSH_AUTH_SOCK="${DOTFILES_OP_SSH_AUTH_SOCK}"
fi

_dotfiles_require_op() {
    if ! command -v op >/dev/null 2>&1; then
        printf "Error: 1Password CLI 'op' is required. Run 'make agent-install' and configure 1Password desktop integration.\n" >&2
        return 127
    fi
}

_dotfiles_validate_secrets_file() {
    if [[ ! -r "${DOTFILES_SECRETS_FILE}" ]]; then
        printf 'Error: 1Password environment file is missing at %s. Run `make agent-deploy`.\n' \
            "${DOTFILES_SECRETS_FILE}" >&2
        return 1
    fi
}

with-agent-secrets() {
    _dotfiles_require_op || return
    _dotfiles_validate_secrets_file || return
    if [[ "${1:-}" == -- ]]; then
        shift
    fi
    if [[ $# -eq 0 ]]; then
        printf 'Usage: with-agent-secrets -- command [args ...]\n' >&2
        return 2
    fi
    op run --env-file="${DOTFILES_SECRETS_FILE}" -- "$@"
}

load-agent-secrets() {
    local secret_name secret_reference secret_value
    _dotfiles_require_op || return
    _dotfiles_validate_secrets_file || return

    while IFS='=' read -r secret_name secret_reference || [[ -n "${secret_name}" ]]; do
        [[ -z "${secret_name}" || "${secret_name}" == \#* ]] && continue
        if [[ ! "${secret_name}" =~ ^[A-Z_][A-Z0-9_]*$ || "${secret_reference}" != op://* ]]; then
            printf 'Error: invalid 1Password mapping for %s in %s.\n' \
                "${secret_name}" "${DOTFILES_SECRETS_FILE}" >&2
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
    done <"${DOTFILES_SECRETS_FILE}"
}
