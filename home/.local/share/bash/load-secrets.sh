#!/usr/bin/env bash
# Export 1Password secrets and hook up the 1Password SSH agent.

if ! command -v op >/dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

if ! declare -F debug_log >/dev/null 2>&1; then
  debug_log() {
    if [[ ${DEBUG:-0} == 1 || ${DEBUG} == true ]]; then
      printf '[DEBUG] %s\n' "$1" >&2
    fi
  }
fi

debug_log "Checking 1Password session"
if ! op whoami >/dev/null 2>&1; then
  debug_log "No active 1Password session; skipping secret exports"
  return 0 2>/dev/null || exit 0
fi

if [[ -z ${SSH_AUTH_SOCK:-} || ! -S $SSH_AUTH_SOCK ]]; then
  for candidate in "$HOME/.1password/agent.sock" "$HOME/.config/1Password/agent.sock" "$HOME/.config/1Password/ssh-agent.sock"; do
    if [ -S "$candidate" ]; then
      export SSH_AUTH_SOCK="$candidate"
      debug_log "Using 1Password ssh-agent at $candidate"
      break
    fi
  done

  if [[ -z ${SSH_AUTH_SOCK:-} || ! -S $SSH_AUTH_SOCK ]]; then
    printf '1Password ssh-agent socket not found; enable the SSH agent in the 1Password app.\n' >&2
  fi
fi

secret_specs=(
  "op://Private/github-token/credential|GITHUB_TOKEN"
  "op://Private/confluence-token/username|CONFLUENCE_USER"
  "op://Private/confluence-token/credential|CONFLUENCE_API_TOKEN"
  "op://Private/ATLASSIAN_API_TOKEN/credential|ATLASSIAN_TOKEN,JIRA_API_TOKEN"
  "op://Employee/Artifactory DPE/credential|ARTIFACTORY_TOKEN"
)

for spec in "${secret_specs[@]}"; do
  IFS='|' read -r path env_csv <<<"$spec"
  if ! value=$(op read --no-newline "$path"); then
    printf 'Failed to read %s from 1Password.\n' "$path" >&2
    continue
  fi
  IFS=',' read -r -a names <<<"$env_csv"
  for name in "${names[@]}"; do
    export "$name=$value"
    debug_log "Exported $name"
  done
done

unset spec path env_csv names name value secret_specs candidate
