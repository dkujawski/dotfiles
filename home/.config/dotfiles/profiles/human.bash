# shellcheck shell=bash

export DOTFILES_PROFILE=human
export DEBUG="${DEBUG:-0}"
shopt -s checkwinsize

debug_log() {
    if [[ "${DEBUG}" == 1 || "${DEBUG}" == true ]]; then
        printf '[DEBUG] %s\n' "$1"
    fi
}

CONF="${HOME}/.local/share/bash"
if [[ ! -r "${CONF}/utility-functions.sh" ]]; then
    printf 'Error: human shell modules are missing from %s. Run `make human-deploy`.\n' "${CONF}" >&2
    return 1
fi

# shellcheck disable=SC1091
source "${CONF}/utility-functions.sh"
source "${CONF}/paths.sh"
source "${CONF}/exports.sh"
source "${CONF}/load-secrets.sh"
source "${CONF}/aliases.sh"
source "${CONF}/functions.sh"
source "${CONF}/git-functions.sh"
unset CONF

source "${HOME}/.bash_prompt"
[[ -r "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"

shopt -s nocaseglob histappend cdspell
for option in autocd globstar; do
    shopt -s "${option}" 2>/dev/null || true
done
if [[ -t 0 ]]; then
    stty -ixon 2>/dev/null || true
fi

complete -W "NSGlobalDomain" defaults
complete -o nospace -W "Contacts Calendar Dock Finder Mail Safari SystemUIServer Terminal iTerm" killall

export NVM_DIR="${HOME}/.nvm"
if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    _dotfiles_load_nvm() {
        unset -f nvm node npm npx _dotfiles_load_nvm
        # shellcheck disable=SC1090
        source "${NVM_DIR}/nvm.sh"
        [[ -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"
    }
    nvm() { _dotfiles_load_nvm && nvm "$@"; }
    node() { _dotfiles_load_nvm && command node "$@"; }
    npm() { _dotfiles_load_nvm && command npm "$@"; }
    npx() { _dotfiles_load_nvm && command npx "$@"; }
fi

DOTFILES_BASH_COMPLETION_FILE="${HOMEBREW_PREFIX:-/opt/homebrew}/etc/profile.d/bash_completion.sh"
if [[ -r "${DOTFILES_BASH_COMPLETION_FILE}" ]]; then
    _dotfiles_load_completion() {
        local command_name="${1:-}"
        complete -r -D 2>/dev/null || true
        # shellcheck disable=SC1090
        source "${DOTFILES_BASH_COMPLETION_FILE}"
        type _git >/dev/null 2>&1 && complete -o default -o nospace -F _git g
        type _completion_loader >/dev/null 2>&1 && _completion_loader "${command_name}"
    }
    complete -D -F _dotfiles_load_completion 2>/dev/null || true
fi

export PYENV_ROOT="${HOME}/.pyenv"
path_prepend "${PYENV_ROOT}/shims"
path_prepend "${PYENV_ROOT}/bin"
export PATH
