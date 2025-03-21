#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")";

#git pull origin main;

function install_home() {
	rsync -avh --no-perms ./home ~;
	source ~/.bash_profile;
}

function source_now() {
	source ~/.bash_profile;
}

function do_it() {
	install_home;
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
