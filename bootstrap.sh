#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")"
pwd
echo "Installing dotfiles using Makefile..."

if [ "$1" == "--force" -o "$1" == "-f" ]; then
    make force
else
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        make all
    fi
fi

platform='unknown'
unamestr=$(uname)
if [[ "$unamestr" == 'Linux' ]]; then
    platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
    platform='darwin'
elif [[ "$unamestr" == 'FreeBSD' ]]; then
    platform='freebsd'
fi

if [[ "$platform" == 'linux' ]]; then
    ./os/ubuntu/apt.sh
elif [[ "$platform" == "darwin" ]]; then
    cp os/macos/.macos ~/
    source ~/.macos
    ./os/macos/brew.sh
fi
