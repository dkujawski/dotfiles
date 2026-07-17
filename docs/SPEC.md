# Dotfiles specification

## Profile selection

- Homebrew Bash is the supported macOS login shell.
- `.bash_profile` and `.bashrc` dispatch to `agent` unless `DOTFILES_PROFILE=human`.
- Agent startup must be silent, deterministic, offline, noninteractive, and safe without
  optional tools, a TTY, 1Password authentication, or an SSH-agent socket.
- `load-human-profile` sources human settings into the current shell; `human-shell` starts
  a human login shell. Human configuration must not be loaded implicitly for agents.

## Agent environment

- Standard commands must not be replaced by aliases.
- Pagers and Git editors must not block automation; Git credential prompting is disabled.
- Homebrew and `~/.local/bin` are added without deleting or duplicating caller PATH entries.
- Optional tool initialization is conditional and failures include an actionable remedy.

## Credentials

- Versioned files may contain variable names and `op://` references, never secret values.
- Startup must not call `op`, load a secret cache, or export a credential.
- `with-agent-secrets` scopes `op run` values to one child command.
- `load-agent-secrets` reads only validated uppercase mappings and explicitly exports them
  into the current shell without `eval` or persistent plaintext storage.
- SSH authentication uses the 1Password agent socket through an included SSH fragment;
  deployment must preserve existing SSH hosts and settings.

## Deployment

- `agent-check` is read-only and reports planned operations.
- `agent-deploy` targets only agent-related files and backs up changed destinations.
- Repeated deployment is idempotent and never duplicates the SSH include.
- `agent-install` installs the focused Brewfile before deployment. Language runtimes remain
  owned by individual projects.
- Tests must isolate HOME, mock external state, and cover normal, missing-tool, and failure
  paths without reading real secrets.
