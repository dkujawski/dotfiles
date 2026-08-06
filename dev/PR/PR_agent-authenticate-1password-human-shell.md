## Summary

- Require `op`, run `op signin` when needed, and verify `op whoami` before loading the
  human shell profile.
- Leave the current agent profile unchanged when 1Password CLI validation fails.
- Document the new human-profile authentication requirement and recovery steps.

## Validation

- `bats tests/agent_profile.bats`
- `make test`
- `git diff --check`

## Deployment and rollback

Run `make human-deploy` after merge to install the updated profile dispatcher. Existing
agent shells remain unchanged. To roll back, revert this change and run `make human-deploy`
again.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [ ] Maintainer review and milestone tag requested
