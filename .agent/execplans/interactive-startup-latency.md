# Optimize interactive Bash startup and prompt latency

This ExecPlan is a living implementation record. The repository does not include
`.agent/PLANS.md`, so this plan follows the structure of the existing ExecPlan.

## Purpose

Human shells should become usable without waiting for credentials, runtime managers,
or the global completion framework. Prompt rendering inside a Git worktree should use
at most two Git processes while preserving branch, dirty, upstream, path, title, and
exit-status information.

## Progress

- [x] Inspect the startup and prompt hot paths.
- [x] Record a prompt baseline (25 renders: 3.55 seconds in this worktree).
- [x] Add deterministic regression tests for deferred startup and bounded Git calls.
- [x] Defer optional initialization and remove per-module startup spinners.
- [x] Consolidate prompt rendering and Git discovery.
- [x] Run the full validation suite and document the change.

The final 25-render prompt check completed in 1.21 seconds, down from the 3.55-second
baseline in the same worktree.

## Decisions

- Secrets remain explicitly available through `load-secrets`; they are never loaded
  merely by opening a human shell.
- NVM and Bash completion load on first use. pyenv uses its bin and shims directories
  without executing `pyenv init` at startup.
- Prompt state comes from one porcelain-v2 status call and one repository-path call.
- ANSI prompt colors are shell constants, avoiding a series of `tput` subprocesses.

## Validation

- `make test`
- A mocked prompt-render test that counts Git invocations.
- A controlled human-profile test that proves optional tools are not invoked.
- A repeated local prompt benchmark in a Git worktree.
