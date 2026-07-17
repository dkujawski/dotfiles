# 1Password secrets and SSH

## Agent security model

The default shell does not resolve credentials. The repository stores only allowlisted
environment names and `op://` references in
`~/.config/dotfiles/secrets/agent.env`. Values are never committed, cached by this profile,
printed by diagnostics, or passed through `eval`.

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
