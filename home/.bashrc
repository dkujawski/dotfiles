# shellcheck shell=bash

if [[ "${DOTFILES_PROFILE_LOADED:-0}" != 1 ]]; then
    # shellcheck disable=SC1090
    source "${HOME}/.bash_profile"
fi
