# Enable/disable debug logging
if [ -z "$DEBUG" ]; then
    DEBUG=0
fi

# Debug logging function
debug_log() {
    if [ "$DEBUG" = "1" ] || [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] $1"
    fi
}

CONF="$HOME/.local/share/bash"
debug_log "Loading configuration from: $CONF"

source "${CONF}/utility-functions.sh"
debug_log "Loaded utility functions"

source_with_spinner "${CONF}/paths.sh" "Loading paths configuration..."
debug_log "Loaded paths"
source_with_spinner "${CONF}/exports.sh" "Loading environment exports..."
debug_log "Loaded exports"
source_with_spinner "${CONF}/load-secrets.sh" "Loading secrets..."
debug_log "Loaded secrets"
source_with_spinner "${CONF}/aliases.sh" "Loading aliases..."
debug_log "Loaded aliases"
source_with_spinner "${CONF}/functions.sh" "Loading functions..."
debug_log "Loaded functions"
source_with_spinner "${CONF}/git-functions.sh" "Loading git functions..."
debug_log "Loaded git functions"
unset CONF;

source_with_spinner "${HOME}/.bash_prompt" "Loading bash prompt..."
debug_log "Loaded bash prompt"

source_with_spinner "${HOME}/.cargo/env" "Loading cargo environment..."
debug_log "Loaded cargo env"

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob;
debug_log "Enabled case-insensitive globbing"

# Append to the Bash history file, rather than overwriting it
shopt -s histappend;
debug_log "Enabled history append mode"

# Autocorrect typos in path names when using `cd`
shopt -s cdspell;
debug_log "Enabled cd spell correction"

# trying to fix history scroll issues. XON/XOFF flow control is disabled
stty -ixon
debug_log "Disabled XON/XOFF flow control"

# Enable some Bash 4 features when possible:
# * `autocd`, e.g. `**/qux` will enter `./foo/bar/baz/qux`
# * Recursive globbing, e.g. `echo **/*.txt`
for option in autocd globstar; do
	shopt -s "$option" 2> /dev/null;
	debug_log "Enabled bash option: $option"
done;

# Add tab completion for many Bash commands
if which brew &> /dev/null && [ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]; then
	debug_log "Loading Homebrew bash completion"
	# Ensure existing Homebrew v1 completions continue to work
	export BASH_COMPLETION_COMPAT_DIR="$(brew --prefix)/etc/bash_completion.d";
	source "$(brew --prefix)/etc/profile.d/bash_completion.sh";
elif [ -f /etc/bash_completion ]; then
	debug_log "Loading system bash completion"
	source /etc/bash_completion;
fi;

# Enable tab completion for `g` by marking it as an alias for `git`
if type _git &> /dev/null; then
	complete -o default -o nospace -F _git g;
	debug_log "Enabled git tab completion for 'g' alias"
fi;

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh;
debug_log "Enabled SSH hostname completion"

# Add tab completion for `defaults read|write NSGlobalDomain`
# You could just use `-g` instead, but I like being explicit
complete -W "NSGlobalDomain" defaults;
debug_log "Enabled defaults command completion"

# Add `killall` tab completion for common apps
complete -o "nospace" -W "Contacts Calendar Dock Finder Mail Safari iTunes SystemUIServer Terminal Twitter" killall;
debug_log "Enabled killall command completion"

eval "$(/opt/homebrew/bin/brew shellenv)"
debug_log "Loaded Homebrew shell environment"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
debug_log "Loaded NVM environment"


export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
