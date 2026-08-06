# Dotfiles specification

## Profile selection

- Homebrew Bash is the supported macOS login shell.
- `.bash_profile` and `.bashrc` dispatch to `agent` unless `DOTFILES_PROFILE=human`.
- Profile-loaded guards are local to one Bash process; nested shells must run their own
  profile initialization even when the parent shell has already loaded it.
- Agent startup must be silent, deterministic, offline, noninteractive, and safe without
  optional tools, a TTY, 1Password authentication, or an SSH-agent socket.
- `load-human-profile` sources human settings into the current shell; `human-shell` starts
  a human login shell. Human configuration must not be loaded implicitly for agents.
- Human startup must require an available, authenticated 1Password CLI. It checks
  `op whoami`, runs foreground `op signin` when authentication is required, and verifies
  `op whoami` again before sourcing human modules. Failure must leave the current agent
  profile unchanged and provide an actionable remedy.

## Agent environment

- Standard commands must not be replaced by aliases.
- Pagers and Git editors must not block automation; Git credential prompting is disabled.
- Homebrew and `~/.local/bin` are added without deleting or duplicating caller PATH entries.
- Optional tool initialization is conditional and failures include an actionable remedy.

## Human interactive performance

- Opening a human shell may verify 1Password CLI authentication but must not resolve secrets
  or eagerly initialize NVM, pyenv, or the global Bash completion framework. Secrets stay
  behind `load-secrets`; NVM and completion initialize on first use; pyenv is available
  through its bin and shims directories.
- Startup modules are sourced directly without background spinner processes, and Homebrew
  paths are derived without invoking `brew` during startup.
- A prompt render in a Git worktree uses no more than two Git commands while preserving the
  branch, dirty state, upstream divergence, repository-relative path, terminal title, and
  previous command status. A prompt outside Git uses no more than one Git command.

## Credentials

- Versioned files may contain variable names and `op://` references, never secret values.
- Both profiles must use the shared `DOTFILES_SECRETS_FILE` mapping source and shared
  validation/loading implementation; profile-specific commands are compatibility wrappers.
- The shared secret-helper load guard is local to one Bash process; nested shells must
  initialize their own helper implementations.
- Agent startup must not call `op`, load a secret cache, or export a credential. Human
  startup may call only `op whoami` and `op signin` for authentication and must not read
  secrets. Sign-in stdout must be discarded to avoid displaying a manual session token.
- `with-agent-secrets` scopes `op run` values to one child command.
- `load-agent-secrets` reads only validated uppercase mappings and explicitly exports them
  into the current shell without `eval` or persistent plaintext storage.
- `with-human-secrets` and `load-human-secrets` provide the same scoped and explicit-import
  boundaries for the human profile; `load-secrets` remains an explicit compatibility alias.
- Human startup must load those entry points from the config-managed library and must not
  source the historical `~/.local/share/bash/load-secrets.sh` compatibility shim.
- No profile may create or consume a plaintext secret cache.
- GitHub CLI authentication is an explicit operation that reads
  `op://Employee/github-token/credential`, stores it through `gh`, verifies exact token
  equality without printing it, and configures `github.com` Git operations for SSH before
  token import so insufficient token scopes cannot leave Git transport on HTTPS.
- GitHub CLI credential-store validation must ignore inherited `GH_TOKEN` and
  `GITHUB_TOKEN` values so environment overrides cannot produce a false match.
- SSH authentication uses the 1Password agent socket through an included SSH fragment;
  deployment must preserve existing SSH hosts and settings.

## Deployment

- `agent-check` is read-only and reports planned operations.
- `agent-deploy` targets only agent-related files and backs up changed destinations.
- Repeated deployment is idempotent and never duplicates the SSH include.
- Deployment removes the known legacy plaintext cache directories and cache-producing
  loader scripts; dry-run reports those removals without changing them.
- `agent-install` installs the focused Brewfile before deployment. Language runtimes remain
  owned by individual projects.
- `configure-gh` remains separate from installation because 1Password authorization may be
  interactive; it must fail with remediation when `gh`, `op`, token access, or SSH protocol
  configuration is unavailable.
- Tests must isolate HOME, mock external state, and cover normal, missing-tool, and failure
  paths without reading real secrets.
