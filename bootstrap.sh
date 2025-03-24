#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")";

function do_it() {
	rsync -avh --no-perms ./home ~;
	source ~/.bash_profile;
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

https://stackoverflow.com/a/394247/3406946
platform='unknown'
unamestr=$(uname)
if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
   platform='darwin'
elif [[ "$unamestr" == 'FreeBSD' ]]; then
   platform='freebsd'
fi

if [[ "$unamestr" == 'Linux' ]]; then
	./os/ubuntu/apt.sh
elif [[ "$platform" == "darwin" ]]; then
   cp os/macos/.macos ~/
   source ~/.macos
   ./os/macos/brew.sh
fi
