#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# Ensure the base system sources list matches the expected defaults.
DEFAULT_SOURCES_FILE="${PWD}/sources.list.default"
if [[ -f ${DEFAULT_SOURCES_FILE} ]]; then
    if ! sudo cmp -s "${DEFAULT_SOURCES_FILE}" /etc/apt/sources.list 2>/dev/null; then
        sudo tee /etc/apt/sources.list >/dev/null <"${DEFAULT_SOURCES_FILE}"
    fi
fi

download_key() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$PROTON_KEY_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$PROTON_KEY_URL"
    else
        echo "Error: neither curl nor wget is installed; cannot fetch $PROTON_KEY_URL" >&2
        return 1
    fi
}

ensure_deb_source() {
    local line="$1"
    local url domain file

    url=$(awk '{for (i = 1; i <= NF; ++i) if ($i ~ /^https?:\/\//) {print $i; exit}}' <<<"$line")
    domain=${url#*://}
    domain=${domain%%/*}
    file="/etc/apt/sources.list.d/${domain}.list"

    if sudo test -f "$file" && sudo grep -Fxq "$line" "$file"; then
        return 0
    fi

    printf '%s\n' "$line" | sudo tee "$file" >/dev/null
}

PROTON_KEY_URL="https://repo.protonvpn.com/debian/public_key.asc"
PROTON_KEYRING="/usr/share/keyrings/protonvpn-archive-keyring.gpg"

if [[ ! -f ${PROTON_KEYRING} ]]; then
    tmp_key=$(mktemp)
    download_key | gpg --dearmor >"${tmp_key}"
    sudo install -Dm644 "${tmp_key}" "${PROTON_KEYRING}"
    rm -f "${tmp_key}"
fi

readarray -t standard_repos < <(grep -Ev '^\s*(#|$)' sources 2>/dev/null || true)
for repo in "${standard_repos[@]}"; do
    repo=$(printf '%s' "$repo" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z "$repo" ]] && continue

    if [[ $repo == -S\ deb\ \[*signed-by=* ]]; then
        ensure_deb_source "${repo#-S }"
        continue
    fi

    read -r -a args <<< "$repo"
    sudo add-apt-repository -y "${args[@]}"

done

readarray -t ppa_repos < <(grep -Ev '^\s*(#|$)' sources-ppa 2>/dev/null || true)
for repo in "${ppa_repos[@]}"; do
    repo=$(printf '%s' "$repo" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z "$repo" ]] && continue

    read -r -a args <<< "$repo"
    sudo add-apt-repository -y "${args[@]}"

done

sudo apt update

readarray -t packages < <(grep -Ev '^\s*(#|$)' pkgs)
if ((${#packages[@]})); then
    sudo apt install -y "${packages[@]}"
fi

sudo apt autoremove -y

if [[ -x /usr/bin/batcat && ! -e ~/.local/bin/bat ]]; then
    mkdir -p ~/.local/bin
    ln -s /usr/bin/batcat ~/.local/bin/bat
fi
