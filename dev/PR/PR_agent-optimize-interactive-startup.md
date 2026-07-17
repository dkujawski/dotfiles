## Summary

- Defer human-shell secrets, NVM, and Bash completion until explicitly needed.
- Remove startup spinner processes, redundant module loads, and eager Homebrew/pyenv calls.
- Consolidate prompt rendering into one status-preserving function with at most two Git
  commands per worktree refresh.
- Add deterministic startup and prompt-process regression coverage.

## Validation

- `make test` (25 tests, ShellCheck, syntax checks, and authentication no-hang test)
- `shellcheck --severity=warning` on all changed shell and Bats files
- `git diff --check`
- 25 prompt renders in this worktree: 3.55 seconds before, 1.21 seconds after

## Deployment and rollback

Deploy with `make human-deploy`, then open a human shell. NVM and completion incur a one-time
cost on first use; legacy secrets now require an explicit `load-secrets`. Roll back by
restoring the timestamped files from `~/.local/state/dotfiles/backups/` or reverting this
commit and running `make human-deploy` again.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [x] Maintainer review and milestone tag requested
