#!/usr/bin/env bash
set -u

TARGET_HOME="${HOME}"
failures=0
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-${DOTFILES_HOMEBREW_PREFIX:-/opt/homebrew}}"

pass() { printf 'ok: %s\n' "$1"; }
fail() { printf 'error: %s\n' "$1" >&2; failures=$((failures + 1)); }
warn() { printf 'warning: %s\n' "$1" >&2; }

if [[ "$(uname -s)" == Darwin ]]; then
    pass 'macOS detected'
else
    fail 'this profile currently targets macOS'
fi

# Empty and '.' PATH entries are unsafe for agents.
_dotfiles_doctor_path_entry=
while IFS= read -r -d: _dotfiles_doctor_path_entry; do
    if [[ -z "${_dotfiles_doctor_path_entry}" ]]; then
        fail 'PATH contains an empty entry; reload the agent profile'
        break
    fi
    if [[ "${_dotfiles_doctor_path_entry}" == "." ]]; then
        fail "PATH contains '.'; reload the agent profile"
        break
    fi
done <<<"${PATH}:"
unset _dotfiles_doctor_path_entry

_dotfiles_resolved_under() {
    local resolved="$1" prefix="$2"
    [[ "${resolved}" == "${prefix}"/* ]]
}

for command_name in bash brew make op; do
    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "${command_name} is available"
    else
        fail "${command_name} is missing; run 'make agent-install'"
    fi
done

for command_name in git jq rg fd fzf delta shellcheck bats tmux tree; do
    if ! command_path="$(command -v "${command_name}" 2>/dev/null)"; then
        fail "${command_name} is missing; run 'make agent-install'"
        continue
    fi
    if _dotfiles_resolved_under "${command_path}" "${HOMEBREW_PREFIX}"; then
        pass "${command_name} resolves to ${command_path}"
    else
        fail "${command_name} is shadowed by ${command_path}; expected under ${HOMEBREW_PREFIX}"
    fi
done

for command_name in sed grep find date readlink; do
    if ! command_path="$(command -v "${command_name}" 2>/dev/null)"; then
        fail "${command_name} is missing; run 'make agent-install'"
        continue
    fi
    if [[ "${command_path}" == */libexec/gnubin/* ]]; then
        pass "${command_name} resolves to GNU ${command_path}"
    else
        fail "${command_name} is shadowed by ${command_path}; expected a Homebrew gnubin path"
    fi
done
unset command_path command_name

if command -v gh >/dev/null 2>&1; then
    if gh_git_protocol="$(env -u GH_TOKEN -u GITHUB_TOKEN \
        gh config get git_protocol --host github.com 2>/dev/null)" && \
        [[ "${gh_git_protocol}" == ssh ]]; then
        pass 'GitHub CLI uses SSH for Git operations'
    else
        gh_git_protocol="${gh_git_protocol:-unconfigured}"
        fail "GitHub CLI uses ${gh_git_protocol} for Git operations; run 'make configure-gh'"
    fi
else
    fail "gh is missing; run 'make agent-install'"
fi

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
