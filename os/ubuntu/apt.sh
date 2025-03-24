#!/usr/bin/bash
cd "$(dirname "${BASH_SOURCE}")";

sudo add-apt-repository -y $(cat sources)
sudo apt update
sudo apt install -y $(cat pkgs)
sudo apt autoremove