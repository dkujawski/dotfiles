#!/usr/bin/env bash
set -u

TARGET_HOME="${HOME}"
failures=0

pass() { printf 'ok: %s\n' "$1"; }
fail() { printf 'error: %s\n' "$1" >&2; failures=$((failures + 1)); }
warn() { printf 'warning: %s\n' "$1" >&2; }

if [[ "$(uname -s)" == Darwin ]]; then
    pass 'macOS detected'
else
    fail 'this profile currently targets macOS'
fi

for command_name in bash brew git gh jq rg fd fzf delta make op shellcheck bats tmux tree; do
    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "${command_name} is available"
    else
        fail "${command_name} is missing; run 'make agent-install'"
    fi
done

if [[ -r "${TARGET_HOME}/.config/dotfiles/profiles/agent.bash" ]]; then
    pass 'agent profile is deployed'
else
    fail "agent profile is missing; run 'make agent-deploy'"
fi

op_socket="${TARGET_HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "${op_socket}" ]]; then
    pass '1Password SSH agent socket is available'
else
    fail '1Password SSH agent socket is unavailable; enable it in 1Password Developer settings'
fi

if command -v op >/dev/null 2>&1; then
    if op whoami >/dev/null 2>&1; then
        pass '1Password CLI authentication is available'
    elif [[ -r "${TARGET_HOME}/.config/dotfiles/secrets/agent.env" ]] && \
        op run --env-file="${TARGET_HOME}/.config/dotfiles/secrets/agent.env" -- \
            sh -c 'test -n "${GITHUB_TOKEN:-}"' >/dev/null 2>&1; then
        pass '1Password scoped secret injection is available'
    else
        warn "1Password secret injection is unavailable; enable desktop integration or run 'op signin'"
    fi
fi

if [[ "${failures}" -ne 0 ]]; then
    printf 'agent-doctor found %d required issue(s).\n' "${failures}" >&2
    exit 1
fi
pass 'required coding-agent shell checks passed'
