# Changelog

## Unreleased

### Added

- Default quiet Bash profile optimized for local coding agents.
- Explicit `load-human-profile` and `human-shell` entry points for preserved human settings.
- Scoped and opt-in 1Password secret helpers with no startup secret loading.
- Explicit GitHub CLI setup that synchronizes the 1Password token, selects SSH for Git
  operations, and verifies persistent authentication without exposing credentials.
- 1Password SSH-agent fragment, focused Homebrew manifest, deployment doctor, backups, and
  deterministic profile/deployment tests.

### Changed

- Default Make workflow now installs and deploys the coding-agent profile.
- Home deployment is targeted and no longer overwrites generated Git configuration.
- Live iTerm preferences are synchronized with the current laptop deployment.
- Human shell startup now defines scoped and explicit-import secret helpers instead of
  resolving all credentials eagerly.
- Human profile loading now verifies 1Password CLI authentication, runs `op signin` for the
  user when required, and sources human modules only after successful verification.
- Agent and human profiles now share one secret mapping source and validation/loading
  implementation while retaining their profile-specific commands.
- Bash profile guards are process-local so nested shells initialize the selected profile.
- The shared secret-helper guard is process-local so fresh nested shells retain working
  scoped and explicit-import commands.
- Human interactive startup now defers secrets, NVM, and Bash completion, avoids redundant
  Homebrew and spinner subprocesses, and exposes pyenv through `PATH` without eager init.
- Git prompt rendering now preserves command status while collecting branch, worktree,
  upstream, path, and iTerm title state with at most two Git commands per refresh.
- Deployment diagnostics now reject GitHub CLI HTTPS Git transport with an actionable
  `make configure-gh` remediation.
- Human startup now bypasses the historical secret-loader shim so a stale deployed copy
  cannot terminate the current shell.

### Security

- Coding-agent startup no longer exports cached plaintext secrets or attempts interactive
  authentication.
- Removed cache-producing 1Password loaders; deployment now deletes their installed scripts
  and legacy plaintext cache directories without retaining copies.
