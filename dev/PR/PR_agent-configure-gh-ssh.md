## Summary

- Add an explicit `make configure-gh` workflow that reads the GitHub token from
  `op://Employee/github-token/credential`, stores it through the GitHub CLI credential
  flow, and configures `github.com` Git operations for SSH.
- Verify that the persistent GitHub CLI token exactly matches the 1Password value while
  ignoring inherited token environment variables and never printing credentials.
- Extend deployment diagnostics, documentation, and deterministic tests for GitHub CLI
  protocol configuration, missing tools, failed secret reads, and token mismatches.
- Keep shared secret helpers available in nested shells by making their load guard
  process-local.

## Validation

- `make test` (31 Bats tests, ShellCheck, Bash syntax checks, and authentication no-hang test)
- `git diff --check`

## Deployment and rollback

Deploy the profile with `make agent-deploy`, then run `make configure-gh` and approve the
1Password prompt. Confirm the environment with `make agent-doctor`. The GitHub setup is
separate from deployment because credential authorization may be interactive.

To roll back the repository changes, revert the branch commits and run
`make agent-deploy`. To restore HTTPS manually, run
`gh config set git_protocol https --host github.com`; token rotation or replacement should
be performed with `gh auth login` rather than placing credentials in shell startup files.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [x] Maintainer review and milestone tag requested
