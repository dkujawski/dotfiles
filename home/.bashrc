# shellcheck shell=bash

if [[ "${DOTFILES_PROFILE_LOADED:-}" != "$$" ]]; then
    # shellcheck disable=SC1090
    source "${HOME}/.bash_profile"
fi
