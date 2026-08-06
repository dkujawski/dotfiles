# shellcheck shell=bash

# Profile dispatcher. Coding agents are the default; humans opt in explicitly.
export DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-${HOME}/.config/dotfiles}"
export DOTFILES_PROFILE="${DOTFILES_PROFILE:-agent}"
export DOTFILES_HUMAN_PROFILE="${DOTFILES_HUMAN_PROFILE:-${DOTFILES_CONFIG_DIR}/profiles/human.bash}"

_dotfiles_require_1password_cli() {
    if ! command -v op >/dev/null 2>&1; then
        printf "Error: 1Password CLI 'op' is required. Install it and enable desktop integration.\n" >&2
        return 127
    fi
    if op whoami >/dev/null 2>&1; then
        return 0
    fi
    printf 'Signing in to 1Password CLI...\n' >&2
    if ! op signin >/dev/null; then
        printf 'Error: 1Password CLI sign-in failed. Unlock 1Password, enable CLI integration in Settings > Developer, then retry.\n' >&2
        return 1
    fi
    if ! op whoami >/dev/null 2>&1; then
        printf 'Error: 1Password CLI authentication could not be verified after sign-in. Run `op whoami`, then retry.\n' >&2
        return 1
    fi
}

load-human-profile() {
    if [[ ! -r "${DOTFILES_HUMAN_PROFILE}" ]]; then
        printf 'Error: human shell profile not found at %s. Run `make human-deploy`.\n' \
            "${DOTFILES_HUMAN_PROFILE}" >&2
        return 1
    fi
    _dotfiles_require_1password_cli || return $?
    export DOTFILES_PROFILE=human
    # shellcheck disable=SC1090
    source "${DOTFILES_HUMAN_PROFILE}"
}

human-shell() {
    local human_shell_path="${SHELL:-/opt/homebrew/bin/bash}"
    if [[ ! -x "${human_shell_path}" ]]; then
        printf 'Error: configured shell %s is not executable.\n' "${human_shell_path}" >&2
        return 1
    fi
    DOTFILES_PROFILE=human "${human_shell_path}" -l
}

case "${DOTFILES_PROFILE}" in
    agent)
        # shellcheck disable=SC1090
        source "${DOTFILES_CONFIG_DIR}/profiles/agent.bash"
        ;;
    human)
        load-human-profile || {
            return 1 2>/dev/null || exit 1
        }
        ;;
    *)
        printf 'Error: unknown DOTFILES_PROFILE %q; expected agent or human.\n' \
            "${DOTFILES_PROFILE}" >&2
        return 2 2>/dev/null || exit 2
        ;;
esac

# Keep the guard local to this Bash process so nested shells initialize themselves.
DOTFILES_PROFILE_LOADED="$$"
export -n DOTFILES_PROFILE_LOADED
