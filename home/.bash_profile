# shellcheck shell=bash

# Profile dispatcher. Coding agents are the default; humans opt in explicitly.
export DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-${HOME}/.config/dotfiles}"
export DOTFILES_PROFILE="${DOTFILES_PROFILE:-agent}"
export DOTFILES_HUMAN_PROFILE="${DOTFILES_HUMAN_PROFILE:-${DOTFILES_CONFIG_DIR}/profiles/human.bash}"

load-human-profile() {
    if [[ ! -r "${DOTFILES_HUMAN_PROFILE}" ]]; then
        printf 'Error: human shell profile not found at %s. Run `make human-deploy`.\n' \
            "${DOTFILES_HUMAN_PROFILE}" >&2
        return 1
    fi
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
        load-human-profile
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
