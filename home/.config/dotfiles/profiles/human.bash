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
source_with_spinner "${CONF}/paths.sh" "Loading paths configuration..."
source_with_spinner "${CONF}/exports.sh" "Loading environment exports..."
source_with_spinner "${CONF}/load-secrets.sh" "Loading secret helpers..."
source_with_spinner "${CONF}/aliases.sh" "Loading aliases..."
source_with_spinner "${CONF}/functions.sh" "Loading functions..."
source_with_spinner "${CONF}/git-functions.sh" "Loading git functions..."
unset CONF

source_with_spinner "${HOME}/.bash_prompt" "Loading bash prompt..."
[[ -r "${HOME}/.cargo/env" ]] && source_with_spinner "${HOME}/.cargo/env" "Loading cargo environment..."

shopt -s nocaseglob histappend cdspell
for option in autocd globstar; do
    shopt -s "${option}" 2>/dev/null || true
done
if [[ -t 0 ]]; then
    stty -ixon 2>/dev/null || true
fi

if command -v brew >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix)"
    if [[ -r "${brew_prefix}/etc/profile.d/bash_completion.sh" ]]; then
        export BASH_COMPLETION_COMPAT_DIR="${brew_prefix}/etc/bash_completion.d"
        # shellcheck disable=SC1090
        source "${brew_prefix}/etc/profile.d/bash_completion.sh"
    fi
    unset brew_prefix
fi

if type _git >/dev/null 2>&1; then
    complete -o default -o nospace -F _git g
fi
if [[ -e "${HOME}/.ssh/config" ]]; then
    complete -o default -o nospace -W "$(awk '/^Host / && $2 !~ /[?*]/ {for (i=2;i<=NF;i++) print $i}' "${HOME}/.ssh/config")" scp sftp ssh
fi
complete -W "NSGlobalDomain" defaults
complete -o nospace -W "Contacts Calendar Dock Finder Mail Safari SystemUIServer Terminal iTerm" killall

export NVM_DIR="${HOME}/.nvm"
[[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
[[ -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"

export PYENV_ROOT="${HOME}/.pyenv"
if [[ -d "${PYENV_ROOT}/bin" ]]; then
    PATH="${PYENV_ROOT}/bin:${PATH}"
    export PATH
    command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - bash)"
fi
