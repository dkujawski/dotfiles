#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")"
pwd
echo "Installing dotfiles..."

if [ "$1" == "--force" -o "$1" == "-f" ]; then
    make force
else
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/N) " -n 1
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        make all
    else
        echo "Exiting"
        exit 1
    fi
fi

HOME_DIR=$(getent passwd "$USER" | cut -d: -f6)
if [ -n "$HOME_DIR" ]; then
    export HOME="$HOME_DIR"
else
    echo "Error: Could not determine home directory."
    exit 1
fi
./os/arch/pacman.sh
