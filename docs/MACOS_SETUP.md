# macOS coding-agent setup

## Architecture

The account login shell is Homebrew Bash. A small dispatcher in `~/.bash_profile` selects
one of two coexisting profiles:

- `agent` (default): quiet automation environment, scoped credentials, no prompt or aliases.
- `human`: the preserved prompt, aliases, completions, runtime helpers, and interactive tools.

The focused `Brewfile.agent` installs shell and repository tooling only. Projects remain
responsible for their own language runtimes and version constraints.

## Install or update

1. Install and sign in to the 1Password desktop app.
2. In 1Password **Settings → Developer**, enable CLI integration and the SSH agent.
3. Preview and deploy:

   ```bash
   make agent-check
   make agent-install
   make configure-gh
   make agent-doctor
   ```

The installer verifies Homebrew, applies the Brewfile, installs only profile-related files,
and adds `Include ~/.ssh/config.d/*` to the existing SSH configuration. It does not replace
existing SSH hosts or `~/.gitconfig`.

`make configure-gh` is intentionally separate from deployment because it requires
1Password authorization. It authenticates `gh` with
`op://Employee/github-token/credential`, stores the token in the operating-system
credential store, sets `git_protocol=ssh` for `github.com`, and verifies that the stored
token exactly matches the 1Password value. The command does not print either token and
does not upload an SSH key. The referenced token must have the `repo`, `read:org`, and
`gist` scopes required by `gh auth login`. SSH transport is configured before token import,
so an insufficient token does not revert Git operations to HTTPS.

## Human settings

Install the legacy modules on a clean machine with `make human-deploy`. Then use
`load-human-profile` in an existing agent shell or `human-shell` for a fresh login shell.
The next ordinary shell still defaults to the agent profile. Human profile loading requires
the `op` command. It checks `op whoami`, runs `op signin` interactively when authentication
is required, then verifies `op whoami` again before sourcing human modules. Unlock
1Password and enable CLI integration in **Settings → Developer** if sign-in fails. Human
startup defines `with-human-secrets` and `load-human-secrets` but does not resolve credentials.

Agent and human deployment remove obsolete secret loader scripts and the known legacy
plaintext cache directories. Those caches are intentionally not copied into the backup.

Human shells defer optional work: NVM loads on the first `nvm`, `node`, `npm`, or `npx`
command, and the global completion framework loads on the first completion request. pyenv's
bin and shims are placed on `PATH` without running `pyenv init`. Run `load-secrets` explicitly
only when legacy human-shell credentials are required.

## Validation

`make agent-doctor` checks the operating system, required commands, deployed profile,
GitHub CLI SSH protocol, 1Password CLI state, and SSH socket without displaying keys or
secrets. A missing 1Password session is a warning because shell startup and public
repository work remain usable. An HTTPS Git protocol is an actionable failure; run
`make configure-gh`.

## Recovery

Changed startup and SSH files are copied to timestamped directories under:

```text
~/.local/state/dotfiles/backups/
```

To recover, copy the desired files from the newest backup to their original locations.
`make human-deploy` can restore all preserved human modules, while
`DOTFILES_PROFILE=human bash -l` bypasses the agent profile for one shell.

## Homebrew warning

Homebrew may report a stale installed dependency graph (for example, a `libtiff`/`webp`
cycle). This does not invalidate a successful bundle. Follow Homebrew's printed remediation
only if package installation itself fails.
