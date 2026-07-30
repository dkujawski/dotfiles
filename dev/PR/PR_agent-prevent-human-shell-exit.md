## Summary

- Load human secret entry points from a config-managed library during profile startup.
- Retain the historical `load-secrets.sh` path as a compatibility shim for explicit callers.
- Cover deployment drift where a stale legacy secret loader would exit the current shell.

## Validation

- `make test`
- Manual isolated-home reproduction with a stale `load-secrets.sh` that calls `exit 42`

## Deployment and rollback

Run `make human-deploy` to install the config library and updated human profile. The
deployer backs up changed files under `~/.local/state/dotfiles/backups/`. Restore those
files from the generated backup directory to roll back.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [x] Maintainer review and milestone tag requested
