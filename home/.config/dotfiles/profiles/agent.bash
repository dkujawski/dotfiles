# shellcheck shell=bash

if [[ "${DOTFILES_AGENT_PROFILE_LOADED:-}" == "$$" ]]; then
    return 0 2>/dev/null || exit 0
fi
# An inherited guard belongs to the parent shell and must not suppress startup here.
DOTFILES_AGENT_PROFILE_LOADED="$$"
export -n DOTFILES_AGENT_PROFILE_LOADED
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

export DOTFILES_OP_SSH_AUTH_SOCK="${DOTFILES_OP_SSH_AUTH_SOCK:-${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"
if [[ -S "${DOTFILES_OP_SSH_AUTH_SOCK}" ]]; then
    export SSH_AUTH_SOCK="${DOTFILES_OP_SSH_AUTH_SOCK}"
fi

# shellcheck disable=SC1091
source "${DOTFILES_CONFIG_DIR}/lib/secrets.bash"

with-agent-secrets() {
    _dotfiles_with_secrets with-agent-secrets 'make agent-deploy' "$@"
}

load-agent-secrets() {
    _dotfiles_load_secrets 'make agent-deploy'
}
