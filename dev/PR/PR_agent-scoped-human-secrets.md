## Summary

- Replace human-profile startup secret resolution with `with-human-secrets` and explicit
  `load-human-secrets` helpers.
- Retain `load-secrets` as an explicit compatibility alias without eager loading.
- Remove legacy cache-producing loaders and delete their installed scripts and plaintext
  cache directories during deployment.
- Add deterministic regression coverage with isolated homes and mocked 1Password CLI calls.
- Include the human secret helper module in syntax and ShellCheck validation.

## Validation

- `bats tests/human_secrets.bats tests/deployment.bats`
- `make test`

## Deployment and rollback

Run `make agent-deploy` or `make human-deploy` to install the helpers and remove legacy
artifacts. Plaintext caches are intentionally not backed up; credentials remain in
1Password. Reverting the branch restores loader code but may reintroduce plaintext caching.
After review, a human maintainer should merge the PR and create the milestone tag.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [x] Maintainer review and milestone tag requested
