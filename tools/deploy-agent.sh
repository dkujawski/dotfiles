#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_HOME="${HOME}"
PROFILE=agent
DRY_RUN=0
BACKUP_ROOT=

usage() {
    printf 'Usage: %s [--dry-run] [--profile agent|human] [--home PATH]\n' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --profile)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            PROFILE="$2"
            shift
            ;;
        --home)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            TARGET_HOME="$2"
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Error: unknown argument %s.\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ "${PROFILE}" != agent && "${PROFILE}" != human ]]; then
    printf 'Error: profile must be agent or human, got %s.\n' "${PROFILE}" >&2
    exit 2
fi
if [[ -z "${TARGET_HOME}" || "${TARGET_HOME}" == / ]]; then
    printf 'Error: refusing to deploy to unsafe home path %q.\n' "${TARGET_HOME}" >&2
    exit 2
fi

backup_file() {
    local target_file="$1" relative_path="$2" backup_file
    [[ -e "${target_file}" ]] || return 0
    if [[ -z "${BACKUP_ROOT}" ]]; then
        BACKUP_ROOT="${TARGET_HOME}/.local/state/dotfiles/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
    fi
    backup_file="${BACKUP_ROOT}/${relative_path}"
    if [[ "${DRY_RUN}" == 1 ]]; then
        printf 'Would back up %s to %s\n' "${target_file}" "${backup_file}"
        return 0
    fi
    mkdir -p "$(dirname "${backup_file}")"
    cp -p "${target_file}" "${backup_file}"
}

install_file() {
    local relative_path="$1" mode="${2:-644}"
    local source_file="${REPO_ROOT}/home/${relative_path}"
    local target_file="${TARGET_HOME}/${relative_path}"
    if [[ -f "${target_file}" ]] && cmp -s "${source_file}" "${target_file}"; then
        printf '%s already current\n' "${target_file}"
        return 0
    fi
    backup_file "${target_file}" "${relative_path}"
    if [[ "${DRY_RUN}" == 1 ]]; then
        printf 'Would install %s\n' "${target_file}"
        return 0
    fi
    mkdir -p "$(dirname "${target_file}")"
    install -m "${mode}" "${source_file}" "${target_file}"
    printf 'Installed %s\n' "${target_file}"
}

install_tree() {
    local source_dir="${REPO_ROOT}/home/$1" source_file relative_file
    while IFS= read -r -d '' source_file; do
        relative_file="${source_file#${REPO_ROOT}/home/}"
        install_file "${relative_file}"
    done < <(find "${source_dir}" -type f -print0 | sort -z)
}

ensure_ssh_include() {
    local ssh_dir="${TARGET_HOME}/.ssh" ssh_config="${TARGET_HOME}/.ssh/config"
    local include_line='Include ~/.ssh/config.d/*' temp_file
    if [[ -f "${ssh_config}" ]] && grep -Eq '^[[:space:]]*Include[[:space:]]+~/.ssh/config.d/\*[[:space:]]*$' "${ssh_config}"; then
        printf '%s already contains the dotfiles SSH include\n' "${ssh_config}"
        return 0
    fi
    backup_file "${ssh_config}" '.ssh/config'
    if [[ "${DRY_RUN}" == 1 ]]; then
        printf 'Would add %s to %s\n' "${include_line}" "${ssh_config}"
        return 0
    fi
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    temp_file="$(mktemp "${ssh_config}.tmp.XXXXXX")"
    if [[ -f "${ssh_config}" ]]; then
        cp "${ssh_config}" "${temp_file}"
        printf '\n%s\n' "${include_line}" >>"${temp_file}"
    else
        printf '%s\n' "${include_line}" >"${temp_file}"
    fi
    chmod 600 "${temp_file}"
    mv "${temp_file}" "${ssh_config}"
    printf 'Updated %s without replacing existing hosts\n' "${ssh_config}"
}

install_file '.bash_profile'
install_file '.bashrc'
install_tree '.config/dotfiles'
install_file '.ssh/config.d/1password.conf' 600
ensure_ssh_include

if [[ "${PROFILE}" == human ]]; then
    install_file '.bash_prompt'
    install_tree '.local/share/bash'
    install_tree '.local/bin'
fi

if [[ -n "${BACKUP_ROOT}" && "${DRY_RUN}" == 0 ]]; then
    printf 'Backups saved under %s\n' "${BACKUP_ROOT}"
fi
