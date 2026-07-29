# 1Password secrets and SSH

## Agent security model

The default shell does not resolve credentials. The repository stores only allowlisted
environment names and `op://` references in
`~/.config/dotfiles/secrets/agent.env`. Values are never committed, cached by this profile,
printed by diagnostics, or passed through `eval`.

Agent and human helpers share this mapping file through `DOTFILES_SECRETS_FILE`. Set that
variable before profile startup to use another mapping file. The older
`DOTFILES_HUMAN_SECRETS_FILE` override remains supported for human shells, but new
configuration should use the shared variable.

Prefer a credential scope around one command:

```bash
with-agent-secrets -- terraform plan
with-agent-secrets -- gh auth status
```

This delegates injection to `op run`; the parent shell remains credential-free. For tools
that cannot be launched through a wrapper, explicitly import the allowlist:

```bash
load-agent-secrets
```

Those variables remain in the current shell until it exits or they are unset. Start a new
agent shell after the operation when a short exposure window matters.

## Authentication

Install the 1Password desktop app and CLI, enable desktop CLI integration, and verify:

```bash
op whoami
```

A service-account token may be supplied by the invoking process for unattended execution,
but it must itself come from an approved external credential source and must never be added
to these dotfiles.

If `op` is missing, unauthenticated, or lacks vault access, helpers fail with a remediation
message while ordinary shell startup continues normally.

## GitHub CLI authentication

Configure the persistent GitHub CLI authentication and Git transport explicitly:

```bash
make configure-gh
```

The command reads `op://Employee/github-token/credential`, passes it to `gh auth login`
over standard input, and configures `github.com` Git operations for SSH. It removes
`GH_TOKEN` and `GITHUB_TOKEN` only from its child `gh` commands so validation reads the
operating-system credential store rather than an inherited environment override. Setup
fails if the stored token does not exactly match the 1Password value or if `gh` does not
report `git_protocol=ssh`. Neither token is printed.

Use `tools/configure-gh.sh --dry-run` to preview the operation without reading 1Password or
changing GitHub CLI state. Re-run `make configure-gh` after rotating the 1Password token.

## SSH and Git signing

The deployed SSH fragment points OpenSSH at the 1Password agent socket:

```text
~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

The installer adds one include to `~/.ssh/config` and preserves all existing content. Git's
SSH signing helper remains the 1Password `op-ssh-sign` application binary. No private-key
file is installed or exported.

Use `make agent-doctor` to verify socket presence. Manage key availability and application
authorization in 1Password rather than copying keys into `~/.ssh`.

## Human profile

The human profile also leaves credentials unresolved during startup. Prefer a scope around
one child command:

```bash
with-human-secrets -- terraform plan
```

For a tool that cannot use the wrapper, `load-human-secrets` explicitly imports the
allowlist into the current shell. The older `load-secrets` command remains an alias for this
explicit operation; it is never called by profile startup.

The loaders that wrote `~/.cache/op-secrets-secure` and `~/.cache/op-secrets-macos` have
been removed. Either profile deployment deletes those legacy directories and installed
loader scripts without backing up plaintext values. `make clear-secrets-cache` remains
available for manual cleanup before deployment.
