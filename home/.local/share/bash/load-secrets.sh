#!/usr/bin/env bash
# Compatibility shim for callers that source the historical module directly.
# shellcheck disable=SC1091
source "${DOTFILES_CONFIG_DIR:-${HOME}/.config/dotfiles}/lib/human-secrets.bash"
