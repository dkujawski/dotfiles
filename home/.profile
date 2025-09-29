# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

umask 022

path_prepend() {
    [ -d "$1" ] || return 0
    case ":${PATH:-}:" in
        *":$1:"*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

path_append() {
    [ -d "$1" ] || return 0
    case ":${PATH:-}:" in
        *":$1:"*) ;;
        *) PATH="${PATH:+$PATH:}$1" ;;
    esac
}

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"
path_append "/usr/local/go/bin"
path_append "$HOME/go/bin"
path_append "$HOME/.cargo/bin"
path_append "/opt/nzbget"

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PYENV_ROOT="$HOME/.pyenv"
path_prepend "$PYENV_ROOT/bin"
if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

export PATH

unset -f path_prepend path_append
