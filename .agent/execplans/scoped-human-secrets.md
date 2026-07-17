# Scoped human secrets

This ExecPlan is a living implementation record. The repository does not contain
`.agent/PLANS.md`, so this plan follows the established local ExecPlan format.

## Purpose

Stop the human Bash profile from resolving every 1Password secret during startup. Replace
the eager loader with command-scoped and explicit-import helpers, and remove the legacy
scripts and on-disk plaintext caches during deployment.

## Progress

- [x] Create `agent/scoped-human-secrets` from `main`.
- [x] Add failing regression tests for startup, helper scope, explicit loading, and cleanup.
- [x] Replace the eager human loader with opt-in helpers.
- [x] Remove legacy cache-producing scripts and deploy-time artifacts.
- [x] Update the specification, documentation, changelog, and PR record.
- [x] Run the complete deterministic validation suite and commit passing milestones.

## Decisions

- Keep `with-human-secrets` as the preferred one-command credential boundary.
- Keep `load-human-secrets` for tools that cannot run through a wrapper; retain
  `load-secrets` as a compatibility alias for explicit imports.
- Reuse the versioned `op://` reference file rather than maintain a second mapping.
- Delete known legacy cache directories without backing them up, because a backup would
  preserve the plaintext credentials this change is intended to remove.
- Remove obsolete installed loaders during both agent and human deployment so the secure
  migration does not depend on which profile a user deploys next.

## Validation

Use isolated temporary homes and mocked `op` commands to verify that startup is inert,
child-command injection is scoped, explicit imports validate mappings, missing tools fail
with remediation, deployment cleanup is idempotent, and dry-run cleanup is read-only. Run
the full Bats, ShellCheck, syntax, and existing authentication suites through `make test`.

## Recovery

The removed cache files intentionally have no repository-managed recovery path. Secrets
remain available from 1Password. Revert the branch to restore loader code, though doing so
is not recommended because it would reintroduce plaintext caching.

## Outcomes

Human shells now start without invoking 1Password and expose scoped and explicit-import
helpers backed only by versioned `op://` references. Both deployment profiles remove the
known plaintext caches and obsolete loader scripts. The full deterministic suite passes,
including helper scope, missing-tool, invalid-mapping, cleanup, dry-run, ShellCheck, syntax,
and authentication behavior.
