# ~/.bashrc: executed for interactive non-login shells.

case $- in
  *i*) ;;
  *) return ;;
esac

if [ -r /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi

source_if_exists() {
  [ -r "$1" ] && . "$1"
}

BASH_SHARE="$HOME/.local/share/bash"
source_if_exists "$BASH_SHARE/utility-functions.sh"
source_if_exists "$BASH_SHARE/paths.sh"
source_if_exists "$BASH_SHARE/exports.sh"
source_if_exists "$BASH_SHARE/.aliases"
source_if_exists "$BASH_SHARE/functions.sh"
source_if_exists "$BASH_SHARE/git-functions.sh"
source_if_exists "$HOME/.bash_prompt"

unset -f source_if_exists
unset BASH_SHARE
