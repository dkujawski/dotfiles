## Summary

Human profile loading previously failed immediately when the 1Password CLI session was not
already authenticated, leaving the user to discover and run the recovery command manually.
This change makes that transition interactive while preserving quiet agent startup.

- Require `op`, run `op signin` when needed, and verify `op whoami` before loading the
  human shell profile.
- Leave the current agent profile unchanged when 1Password CLI validation fails.
- Document the new human-profile authentication requirement and recovery steps.

Users entering a human shell are now prompted to authorize 1Password when necessary. Human
modules load only after authentication succeeds, and no secret values are resolved during
profile startup.

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
