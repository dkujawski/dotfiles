# Ubuntu dotfiles

These dotfiles manage my interactive shell configuration on Ubuntu desktops. The branch is Ubuntu-only; all previous macOS-specific logic has been removed.

## Installation

Clone the repository and run the bootstrap script. The script copies configuration files into your home directory via the `Makefile` and then runs the Ubuntu package bootstrap:

```bash
git clone https://github.com/dkujawski/dotfiles.git
cd dotfiles
source bootstrap.sh
```

You can skip the confirmation prompt by forcing the install:

```bash
set -- -f; source bootstrap.sh
```

## Make targets

The `Makefile` exposes a few helpers that are safe to run directly:

- `make install-dotfiles` – sync the contents of `home/` into `$HOME`
- `make install-packages` – install the apt repositories and packages defined in `os/ubuntu`
- `make check` – preview the rsync changes without modifying your home directory
- `make clean` – remove build artefacts produced by the secrets tooling

## Secrets loader

The repository includes a Rust binary (`load-secrets`) used to pull environment secrets from 1Password. `make install-dotfiles` builds and deploys the tool automatically. The shell startup scripts source `~/.local/share/bash/load-secrets.sh`, which shells out to that binary and exports the resulting values.

## Customisation

Drop additional overrides in `~/.extra` or `~/.path` and they will be sourced as part of shell startup. Add binaries to `~/.local/bin` or `~/bin` and they will be placed on `$PATH` ahead of the system defaults.
