# Local coding-agent shell profile

This ExecPlan is a living implementation record. The repository does not contain the
referenced `.agent/PLANS.md`, so this document follows the repository instructions and
records progress, decisions, validation, and recovery details directly.

## Purpose

Make a quiet, deterministic Bash environment the default on this macOS laptop for local
coding agents, while preserving the previous interactive configuration as an explicitly
loadable human profile. Resolve secrets only through 1Password and use its SSH agent.

## Progress

- [x] Create `agent/macos-local-coding-agents` from updated `main`.
- [x] Merge the current `macos-fox` deployment history.
- [x] Commit the live iTerm preference state without importing generated `~/.gitconfig` drift.
- [x] Add failing profile, secret, and SSH tests.
- [x] Implement the agent/human profile split and 1Password helpers.
- [x] Implement dependency and deployment orchestration.
- [x] Update specifications, operational documentation, changelog, and PR record.
- [x] Deploy locally and verify a clean, accurately deployed branch.

## Decisions

- Keep `/opt/homebrew/bin/bash`; adding a less ubiquitous shell would reduce agent compatibility.
- Agent startup performs no secret lookup, network call, prompt rendering, or terminal mutation.
- `with-agent-secrets` is the preferred credential boundary; `load-agent-secrets` is explicit opt-in.
- Preserve the existing human configuration without making it the default.
- Manage the 1Password SSH socket through a dedicated included SSH fragment.
- Do not version GitHub CLI, Git LFS, or user identity lines generated in `~/.gitconfig`.

## Implementation outline

Add a small `.bash_profile` dispatcher and separate profiles under
`~/.config/dotfiles/profiles`. Add a declarative 1Password environment file and shell
helpers that validate input and dependencies. Add a safe deployment script with dry-run,
backup, SSH include, and doctor modes. Drive it with Make and a focused Brewfile.

## Validation

Run Bats in isolated temporary homes with mocked external tools, ShellCheck all new shell
files, validate Make dry-runs, run the existing authentication test, then deploy and verify
fresh Bash startup, profile switching, non-disclosing secret injection, and the SSH socket.

## Recovery

Deployment backs up replaced files below `~/.local/state/dotfiles/backups`. Restore the
latest backup or deploy the human profile explicitly. Git history is retained through the
merge commit, and the original deployment branches remain unchanged.

## Outcomes

The coding-agent profile is deployed and is the quiet default. Targeted deployment is
idempotent, generated Git configuration remains untouched, the human profile can be loaded
in place, scoped 1Password injection resolves from a clean environment, and the 1Password
SSH agent exposes an authorized key. Backups from the migration are stored under
`~/.local/state/dotfiles/backups/20260717T181826Z-79462`.
