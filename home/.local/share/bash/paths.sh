#!/usr/bin/env bash
# Standard Paths

# shellcheck source=/dev/null


source "${HOME}/.local/share/bash/utility-functions.sh"


# --------------------------------------------------------------------------------------
# Standard Paths
# --------------------------------------------------------------------------------------

# Homebrew
if command_exists brew; then
    eval "$(brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi


# Visual Studio Code (code)
path_append "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"


# pyenv
if [[ -d "${HOME}/.pyenv" ]]; then
    export PYENV_ROOT="${HOME}/.pyenv"
    path_append "${PYENV_ROOT}/shims"
fi


# Go
if command_exists go && [[ -d "${HOME}/.go" ]]; then
    export GOPATH="${HOME}/.go"
    [[ -d "${GOPATH}/bin" ]] && export GOBIN="${HOME}/.go/bin"
    path_prepend "${GOBIN}"
fi


# Local user bin
path_prepend "${HOME}/.local/bin"


export PATH
