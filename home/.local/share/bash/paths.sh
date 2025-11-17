#!/usr/bin/env bash
# Standard Paths

# shellcheck source=/dev/null


source "${HOME}/.local/share/bash/utility-functions.sh"


# --------------------------------------------------------------------------------------
# Standard Paths
# --------------------------------------------------------------------------------------

# Local user bins
path_prepend "${HOME}/.local/bin"
path_prepend "${HOME}/bin"


# Cargo
if [[ -d "${HOME}/.cargo/bin" ]]; then
    path_prepend "${HOME}/.cargo/bin"
fi


# Poetry
if [[ -d "${HOME}/.poetry/bin" ]]; then
    path_prepend "${HOME}/.poetry/bin"
fi


# pyenv
if [[ -d "${HOME}/.pyenv" ]]; then
    export PYENV_ROOT="${HOME}/.pyenv"
    path_append "${PYENV_ROOT}/shims"
fi


# Go workspace
if [[ -d "${HOME}/go/bin" ]]; then
    export GOPATH="${HOME}/go"
    path_prepend "${GOPATH}/bin"
fi


# Snap binaries
if [[ -d "/snap/bin" ]]; then
    path_append "/snap/bin"
fi

# Android Studio
if [[ -d "/opt/android-studio/bin" ]]; then
    path_append "/opt/android-studio/bin"
fi


export PATH
