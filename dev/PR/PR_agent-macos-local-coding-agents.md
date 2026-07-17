## Summary

- Reconciles the current macOS deployment and live iTerm settings with updated `main`.
- Makes a quiet, deterministic Bash profile the default for local coding agents while
  preserving an explicitly loadable human profile.
- Adds scoped 1Password secrets, 1Password SSH-agent integration, focused dependencies,
  safe targeted deployment, backups, diagnostics, and tests.

## Validation

- `make test`
- `make agent-check`
- `brew bundle check --file Brewfile.agent`
- Fresh noninteractive Bash startup with no unsolicited output or 1Password lookup
- Local deployment and `make agent-doctor` (to be recorded after deployment)

## Deployment and rollback

Run `make agent-check`, then `make agent-install`. The installer backs up replaced startup
and SSH files under `~/.local/state/dotfiles/backups/`. Restore those files or load the human
profile to roll back shell behavior.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [ ] Maintainer review and milestone tag requested
