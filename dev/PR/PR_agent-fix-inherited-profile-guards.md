## Summary

- Makes Bash profile-loaded guards process-local instead of exporting them to child shells.
- Reloads the selected agent profile when nested shells enter through `.bash_profile` or
  `.bashrc`.
- Isolates profile tests from live `DOTFILES_CONFIG_DIR` state and adds nested-shell
  regression coverage.

## Validation

- `make test`

## Deployment and rollback

Run `make agent-deploy` to install the corrected startup files. Existing shells continue to
work, and newly started nested shells will initialize the selected profile independently.
Roll back by reverting this branch and running `make agent-deploy` again.

## Checklist

- [x] Tests pass
- [x] Documentation and changelog are current
- [x] No secrets or generated machine credentials are committed
- [ ] Maintainer review and milestone tag requested
