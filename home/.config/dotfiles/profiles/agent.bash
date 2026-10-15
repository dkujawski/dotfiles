# shellcheck shell=bash

if [[ "${DOTFILES_AGENT_PROFILE_LOADED:-}" == "$$" ]]; then
    return 0 2>/dev/null || exit 0
fi
# An inherited guard belongs to the parent shell and must not suppress startup here.
DOTFILES_AGENT_PROFILE_LOADED="$$"
export -n DOTFILES_AGENT_PROFILE_LOADED
export DOTFILES_PROFILE=agent
export DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-${HOME}/.config/dotfiles}"

_dotfiles_path_promote() {
    [[ -d "$1" ]] || return 0
    local dir="$1" entry rebuilt=
    while IFS= read -r -d: entry; do
        [[ -z "${entry}" || "${entry}" == "." || "${entry}" == "${dir}" ]] && continue
        rebuilt="${rebuilt:+${rebuilt}:}${entry}"
    done <<<"${PATH}:"
    PATH="${dir}${rebuilt:+:${rebuilt}}"
}

# Call in reverse-priority order so the final precedence is highest-first:
# pyenv bin/shims, ~/.local/bin, GNU gnubin dirs, Homebrew bin/sbin, then remaining PATH.
DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX:-/opt/homebrew}"
_dotfiles_path_promote "${DOTFILES_HOMEBREW_PREFIX}/sbin"
_dotfiles_path_promote "${DOTFILES_HOMEBREW_PREFIX}/bin"
for _dotfiles_gnu_pkg in coreutils findutils gnu-sed grep; do
    _dotfiles_path_promote \
        "${DOTFILES_HOMEBREW_PREFIX}/opt/${_dotfiles_gnu_pkg}/libexec/gnubin"
done
unset _dotfiles_gnu_pkg
_dotfiles_path_promote "${HOME}/.local/bin"
if [[ -d "${HOME}/.pyenv" ]]; then
    export PYENV_ROOT="${HOME}/.pyenv"
    _dotfiles_path_promote "${PYENV_ROOT}/bin"
    _dotfiles_path_promote "${PYENV_ROOT}/shims"
fi
export PATH
export DOTFILES_HOMEBREW_PREFIX
unset -f _dotfiles_path_promote

# Automation-safe defaults: never open a pager, editor, prompt, or package update.
export PAGER=cat
export GIT_PAGER=cat
export GH_PAGER=cat
export SYSTEMD_PAGER=cat
export AWS_PAGER=
export MANPAGER=cat
export EDITOR=true
export VISUAL=true
export GIT_EDITOR=true
export GIT_SEQUENCE_EDITOR=true
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=true
export SSH_ASKPASS=true
export SSH_ASKPASS_REQUIRE=never
export GIT_MERGE_AUTOEDIT=no
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export GH_NO_UPDATE_NOTIFIER=1
export GH_PROMPT_DISABLED=1
export NO_COLOR="${NO_COLOR:-1}"
export CLICOLOR=0
export PYTHONIOENCODING=UTF-8
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_INPUT=1
export NPM_CONFIG_FUND=false
export NPM_CONFIG_AUDIT=false
export NPM_CONFIG_UPDATE_NOTIFIER=false
export BASH_SILENCE_DEPRECATION_WARNING=1
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Non-login, non-interactive bash -c inherits the same agent environment.
export BASH_ENV="${DOTFILES_CONFIG_DIR}/profiles/agent.bash"

export DOTFILES_OP_SSH_AUTH_SOCK="${DOTFILES_OP_SSH_AUTH_SOCK:-${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"
if [[ -S "${DOTFILES_OP_SSH_AUTH_SOCK}" ]]; then
    export SSH_AUTH_SOCK="${DOTFILES_OP_SSH_AUTH_SOCK}"
fi

if [[ -r "${DOTFILES_CONFIG_DIR}/lib/secrets.bash" ]]; then
    # shellcheck disable=SC1091
    source "${DOTFILES_CONFIG_DIR}/lib/secrets.bash"
else
    printf 'Warning: secret helpers missing at %s/lib/secrets.bash. Run `make agent-deploy`.\n' \
        "${DOTFILES_CONFIG_DIR}" >&2
fi

with-agent-secrets() {
    _dotfiles_with_secrets with-agent-secrets 'make agent-deploy' "$@"
}

load-agent-secrets() {
    _dotfiles_load_secrets 'make agent-deploy'
}
