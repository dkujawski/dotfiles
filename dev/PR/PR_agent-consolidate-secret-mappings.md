## Summary

- Consolidate agent and human 1Password mapping validation and loading in one shared module.
- Use `DOTFILES_SECRETS_FILE` as the mapping source for both profiles while preserving the
  older human-only override as a compatibility fallback.
- Retain the existing agent and human helper command names as profile-specific wrappers.
- Add deterministic coverage for the shared mapping override.

## Validation

- `bats tests/agent_profile.bats tests/human_secrets.bats`
- `make test`

## Deployment and rollback

Run `make agent-deploy` or `make human-deploy` to install the shared helper module and
profile wrappers. Existing human configurations using `DOTFILES_HUMAN_SECRETS_FILE`
continue to work. Revert this branch to restore independent implementations. After review,
a human maintainer should merge the PR and create the milestone tag.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [x] Maintainer review and milestone tag requested
