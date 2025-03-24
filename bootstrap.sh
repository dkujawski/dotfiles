#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")";
pwd;
echo "Installing dotfiles...";

function install_home() {
	rsync -avhc --no-perms home/ ~/
}

function source_now() {
	source ~/.bash_profile;
}

function install_brew() {
    [ -d /opt/homebrew/bin ] && export PATH=$PATH:/opt/homebrew/bin
    if ! command -v brew 2>&1 >/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "brew already installed!"
    fi
}

function do_it() {
	install_home;
  install_brew;
	source_now;
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	do_it;
else
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		do_it;
	fi;
fi;

unset do_it;
unset install_home;
unset source_now;
