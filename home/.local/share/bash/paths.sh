#!/usr/bin/env bash
# Standard Paths

# shellcheck source=/dev/null


if ! type path_append >/dev/null 2>&1; then
    source "${HOME}/.local/share/bash/utility-functions.sh"
fi


# --------------------------------------------------------------------------------------
# Standard Paths
# --------------------------------------------------------------------------------------

# Homebrew's stable macOS paths do not require running `brew shellenv` in every shell.
homebrew_prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
path_append "${homebrew_prefix}/bin"
path_append "${homebrew_prefix}/sbin"
unset homebrew_prefix


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
