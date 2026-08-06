# Dave's dotfiles

This repository manages shell and development-tool configuration for macOS and Linux.
On the current macOS laptop, a quiet Bash profile for local coding agents is the default;
the previous interactive configuration remains available as the human profile.

## Quick start

```bash
make agent-check       # preview targeted home-directory changes
make agent-install     # install required tools and deploy the agent profile
make configure-gh      # sync gh auth from 1Password and select SSH for Git
make agent-doctor      # validate the deployed environment
```

`agent-deploy` deliberately installs only startup dispatch, profile, secret-reference,
and SSH integration files. It does not replace `~/.gitconfig` or bulk-sync the home
directory. Changed files are backed up under `~/.local/state/dotfiles/backups/`.

## Profiles

Homebrew Bash (`/opt/homebrew/bin/bash`) remains the login shell. New shells load the
`agent` profile by default. It is silent, performs no network or secret operations during
startup, avoids command-changing aliases, and configures noninteractive pagers/editors.

Load the human settings into the current shell when needed:

```bash
load-human-profile
```

Or start a nested human-configured login shell:

```bash
human-shell
```

`DOTFILES_PROFILE=human bash -l` is also supported. Run `make human-deploy` on a clean
machine to install the prompt, aliases, functions, and opt-in secret helpers without
changing the default profile. Loading the human profile requires `op`, checks the current
session with `op whoami`, and runs `op signin` for the user when authentication is required.
Human modules load only after a successful follow-up verification. Startup does not resolve
or export credentials, and NVM and global Bash completion load on first use.

## Secrets and SSH

Shell startup never exports secrets. Use a profile-specific scoped form whenever possible:

```bash
with-agent-secrets -- gh auth status
with-human-secrets -- terraform plan
```

When a tool requires variables in the existing shell, explicitly run:

```bash
load-agent-secrets
load-human-secrets
```

Both commands read only the versioned `op://` references through the 1Password CLI.
Private keys remain in 1Password and are exposed through its SSH agent socket. See
[`docs/SECRETS_MANAGEMENT.md`](docs/SECRETS_MANAGEMENT.md) for setup and failure handling.

`make configure-gh` is the explicit one-time GitHub CLI setup. It reads
`op://Employee/github-token/credential`, stores that token through `gh auth login`, selects
SSH for Git operations, and verifies both settings without printing the token. It skips
GitHub SSH-key upload because the existing 1Password SSH agent supplies the key. The token
must have at least the `repo`, `read:org`, and `gist` scopes required by `gh auth login`.

## Development

```bash
make test
```

Tests use temporary home directories and mocked external commands. See
[`docs/SPEC.md`](docs/SPEC.md) for behavioral requirements and
[`docs/MACOS_SETUP.md`](docs/MACOS_SETUP.md) for installation and recovery.

## License

MIT License. See [`LICENSE-MIT.txt`](LICENSE-MIT.txt).
