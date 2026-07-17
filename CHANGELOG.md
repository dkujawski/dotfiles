# Changelog

## Unreleased

### Added

- Default quiet Bash profile optimized for local coding agents.
- Explicit `load-human-profile` and `human-shell` entry points for preserved human settings.
- Scoped and opt-in 1Password secret helpers with no startup secret loading.
- 1Password SSH-agent fragment, focused Homebrew manifest, deployment doctor, backups, and
  deterministic profile/deployment tests.

### Changed

- Default Make workflow now installs and deploys the coding-agent profile.
- Home deployment is targeted and no longer overwrites generated Git configuration.
- Live iTerm preferences are synchronized with the current laptop deployment.
- Human shell startup now defines scoped and explicit-import secret helpers instead of
  resolving all credentials eagerly.
- Agent and human profiles now share one secret mapping source and validation/loading
  implementation while retaining their profile-specific commands.

### Security

- Coding-agent startup no longer exports cached plaintext secrets or attempts interactive
  authentication.
- Removed cache-producing 1Password loaders; deployment now deletes their installed scripts
  and legacy plaintext cache directories without retaining copies.
