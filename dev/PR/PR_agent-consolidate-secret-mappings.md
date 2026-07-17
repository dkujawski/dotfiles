## Summary

- Replace eager human-profile secret resolution with scoped `with-human-secrets` and
  explicit `load-human-secrets` entry points.
- Remove legacy cache-producing loaders and clean up their installed scripts and plaintext
  cache directories during deployment.
- Consolidate agent and human 1Password mapping validation and loading in one shared module.
- Use `DOTFILES_SECRETS_FILE` as the mapping source for both profiles while preserving the
  older human-only override as a compatibility fallback.
- Retain the existing agent and human helper command names as profile-specific wrappers.
- Add deterministic coverage for scoped human secrets, legacy cleanup, and the shared
  mapping override.

## Validation

- `bats tests/agent_profile.bats tests/human_secrets.bats`
- `make test`

## Deployment and rollback

Run `make agent-deploy` or `make human-deploy` to install the shared helper module, profile
wrappers, and remove legacy cache artifacts. Plaintext caches are intentionally not backed
up; credentials remain in 1Password. Existing human configurations using
`DOTFILES_HUMAN_SECRETS_FILE` continue to work. Revert this branch to restore the previous
implementations, noting that doing so may reintroduce plaintext caching. After review, a
human maintainer should merge the PR and create the milestone tag.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [x] Maintainer review and milestone tag requested
