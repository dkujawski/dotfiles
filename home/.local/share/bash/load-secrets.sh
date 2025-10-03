#!/usr/bin/env bash
# Load Secrets from 1Password using secure shell-based approach

# Debug logging function (if not already defined)
if ! type debug_log >/dev/null 2>&1; then
    debug_log() {
        if [ "$DEBUG" = "1" ] || [ "$DEBUG" = "true" ]; then
            echo "[DEBUG] $*" >&2
        fi
    }
fi

debug_log "Starting 1Password secrets loading"

# Determine the path to the secrets loader (prefer macOS-optimized version)
SECRETS_LOADER=""
if [ -f "${HOME}/.local/bin/load-secrets-macos.sh" ]; then
    SECRETS_LOADER="${HOME}/.local/bin/load-secrets-macos.sh"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../../../tools/load-secrets-macos.sh" ]; then
    SECRETS_LOADER="$(dirname "${BASH_SOURCE[0]}")/../../../tools/load-secrets-macos.sh"
elif [ -f "${HOME}/.local/bin/load-secrets-secure.sh" ]; then
    SECRETS_LOADER="${HOME}/.local/bin/load-secrets-secure.sh"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../../../tools/load-secrets-secure.sh" ]; then
    SECRETS_LOADER="$(dirname "${BASH_SOURCE[0]}")/../../../tools/load-secrets-secure.sh"
else
    echo "Error: load-secrets script not found" >&2
    exit 1
fi

debug_log "Using secrets loader: $SECRETS_LOADER"

# Load secrets using the secure shell-based approach with timeout
# Make secrets loading non-fatal to allow shell to start even if 1Password is unavailable
if secrets_output=$(timeout 30s bash "$SECRETS_LOADER" 2>&1); then
    debug_log "Successfully loaded secrets from 1Password"
    
    # Process the output line by line
    while IFS= read -r line; do
        if [[ $line == \[DEBUG\]* ]]; then
            # Handle debug lines
            echo "$line" >&2
        elif [[ $line == *"<concealed by 1Password>"* ]]; then
            # Skip concealed values to avoid syntax errors
            debug_log "Skipping concealed value: $line"
        elif [[ $line == export* ]]; then
            # Handle export commands
            eval "$line"
        fi
    done <<< "$secrets_output"
else
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "Warning: load-secrets command timed out after 30 seconds" >&2
        echo "Continuing shell initialization without secrets..." >&2
    else
        echo "Warning: load-secrets command failed (1Password may not be configured)" >&2
        echo "Continuing shell initialization without secrets..." >&2
        if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
            echo "[DEBUG] Secrets output: $secrets_output" >&2
        fi
    fi
fi

debug_log "Completed loading all secrets"
