#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must run as root (try sudo)." >&2
    exit 1
fi

KEY_URL=${KEY_URL:-https://repo.protonvpn.com/debian/public_key.asc}
KEYRING=${KEYRING:-/usr/share/keyrings/protonvpn-archive-keyring.gpg}
SOURCE_FILE=${SOURCE_FILE:-/etc/apt/sources.list.d/repo.protonvpn.com.list}
EXPECTED_SOURCE_LINE="deb [signed-by=${KEYRING}] https://repo.protonvpn.com/debian stable main"
RUN_UPDATE=false

while (($#)); do
    case "$1" in
        --update)
            RUN_UPDATE=true
            shift
            ;;
        --key-url)
            if [[ $# -lt 2 ]]; then
                echo "--key-url requires a value" >&2
                exit 1
            fi
            KEY_URL="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--update] [--key-url URL]" >&2
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$KEY_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$KEY_URL"
    else
        echo "Error: install curl or wget to download $KEY_URL" >&2
        exit 1
    fi
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

download >"$tmpdir/public_key.asc"
gpg --dearmor <"$tmpdir/public_key.asc" >"$tmpdir/protonvpn-archive-keyring.gpg"
install -Dm644 "$tmpdir/protonvpn-archive-keyring.gpg" "$KEYRING"
echo "Installed ProtonVPN keyring to $KEYRING"

echo "Key fingerprints (verify against ProtonVPN documentation):"
gpg --show-keys --fingerprint "$KEYRING"

if [[ ! -f "$SOURCE_FILE" ]] || ! grep -Fq "$EXPECTED_SOURCE_LINE" "$SOURCE_FILE"; then
    if [[ -f "$SOURCE_FILE" ]]; then
        backup="${SOURCE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$SOURCE_FILE" "$backup"
        echo "Saved existing source definition to $backup"
    fi
    printf '%s\n' "$EXPECTED_SOURCE_LINE" >"$SOURCE_FILE"
    echo "Wrote ProtonVPN source definition to $SOURCE_FILE"
else
    echo "ProtonVPN source definition already matches expected configuration."
fi

if $RUN_UPDATE; then
    apt update
else
    echo "Run 'sudo apt update' to refresh package metadata."
fi
