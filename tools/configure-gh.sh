#!/usr/bin/env bash
set -euo pipefail

GH_HOST="${DOTFILES_GH_HOST:-github.com}"
GH_TOKEN_REFERENCE="${DOTFILES_GH_TOKEN_REFERENCE:-op://Employee/github-token/credential}"
DRY_RUN=0

usage() {
    printf 'Usage: %s [--dry-run]\n' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            printf 'Error: unknown argument %s.\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if ! command -v gh >/dev/null 2>&1; then
    printf "Error: GitHub CLI 'gh' is required. Run \`make agent-install\`.\n" >&2
    exit 127
fi
if ! command -v op >/dev/null 2>&1; then
    printf "Error: 1Password CLI 'op' is required. Install it and enable desktop integration.\n" >&2
    exit 127
fi

if [[ "${DRY_RUN}" == 1 ]]; then
    printf 'Would authenticate GitHub CLI for %s from %s.\n' \
        "${GH_HOST}" "${GH_TOKEN_REFERENCE}"
    printf 'Would configure Git operations for %s to use SSH without uploading a key.\n' \
        "${GH_HOST}"
    exit 0
fi

gh_without_environment_token() {
    env -u GH_TOKEN -u GITHUB_TOKEN gh "$@"
}

if ! github_token="$(op read "${GH_TOKEN_REFERENCE}")"; then
    printf 'Error: could not read %s; approve the 1Password prompt and verify vault access.\n' \
        "${GH_TOKEN_REFERENCE}" >&2
    exit 1
fi
if [[ -z "${github_token}" ]]; then
    printf 'Error: %s resolved to an empty token; update the 1Password item.\n' \
        "${GH_TOKEN_REFERENCE}" >&2
    exit 1
fi

if ! printf '%s\n' "${github_token}" | gh_without_environment_token auth login \
    --hostname "${GH_HOST}" \
    --git-protocol ssh \
    --skip-ssh-key \
    --with-token; then
    printf 'Error: GitHub CLI could not store the 1Password token for %s; verify its scopes and validity.\n' \
        "${GH_HOST}" >&2
    exit 1
fi

if ! stored_token="$(gh_without_environment_token auth token --hostname "${GH_HOST}")"; then
    printf 'Error: GitHub CLI could not read the stored token for %s after login.\n' \
        "${GH_HOST}" >&2
    exit 1
fi
if [[ "${stored_token}" != "${github_token}" ]]; then
    printf 'Error: GitHub CLI stored token does not match %s.\n' \
        "${GH_TOKEN_REFERENCE}" >&2
    exit 1
fi
unset github_token stored_token

git_protocol="$(gh_without_environment_token config get git_protocol --host "${GH_HOST}")"
if [[ "${git_protocol}" != ssh ]]; then
    printf 'Error: GitHub CLI reports git_protocol=%s for %s; expected ssh.\n' \
        "${git_protocol}" "${GH_HOST}" >&2
    exit 1
fi

if ! github_login="$(gh_without_environment_token api user --jq .login)"; then
    printf 'Error: the stored GitHub token could not access the authenticated user endpoint.\n' >&2
    exit 1
fi

printf 'GitHub CLI is authenticated as %s; the stored token matches %s.\n' \
    "${github_login}" "${GH_TOKEN_REFERENCE}"
printf 'Git operations use SSH for %s; the existing 1Password SSH agent key remains in place.\n' \
    "${GH_HOST}"
