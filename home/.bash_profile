# ~/.bash_profile
# Login shell bootstrap used across interactive and non-interactive sessions.

source_if_exists() {
  [ -r "$1" ] && . "$1"
}

# POSIX-friendly profile overrides (if present).
source_if_exists "$HOME/.profile"

# Only run the secrets loader once per shell session.
if [[ -z ${DOTFILES_SECRETS_LOADED:-} ]]; then
  source_if_exists "$HOME/.local/share/bash/load-secrets.sh"
  export DOTFILES_SECRETS_LOADED=1
fi

case $- in
  *i*)
    source_if_exists "$HOME/.bashrc"
    ;;
  *)
    ;;
esac

unset -f source_if_exists
