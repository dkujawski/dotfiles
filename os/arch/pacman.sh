#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ ${ID:-} != arch && ${ID_LIKE:-} != *arch* ]]; then
        echo "Warning: expected Arch Linux, but detected ${NAME:-an unknown distro}." >&2
    fi
else
    echo "Warning: /etc/os-release missing; continuing without OS verification." >&2
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: pacman not found. This installer only supports Arch-based systems." >&2
    exit 1
fi

sudo pacman -Syu --noconfirm

readarray -t packages < <(grep -Ev '^\s*(#|$)' pkgs 2>/dev/null || true)
if ((${#packages[@]})); then
    sudo pacman -S --needed --noconfirm "${packages[@]}"
fi
