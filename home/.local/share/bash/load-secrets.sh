#!/usr/bin/env bash
# Load Secrets from 1Password

# Debug logging function (if not already defined)
if ! type debug_log >/dev/null 2>&1; then
    debug_log() {
        if [ "$DEBUG" = "1" ] || [ "$DEBUG" = "true" ]; then
            echo "[DEBUG] $*" >&2
        fi
    }
fi

debug_log "Starting 1Password secrets loading"

# Run the load-secrets binary with a timeout
if ! secrets_output=$(timeout 30s load-secrets 2>&1); then
    if [ $? -eq 124 ]; then
        echo "Error: load-secrets command timed out after 30 seconds" >&2
        exit 1
    else
        echo "Error: load-secrets command failed" >&2
        exit 1
    fi
fi

# Process the output line by line
while IFS= read -r line; do
    if [[ $line == \[DEBUG\]* ]]; then
        # Handle debug lines
        echo "$line" >&2
    else
        # Handle export commands
        eval "$line"
    fi
done <<< "$secrets_output"

debug_log "Completed loading all secrets"
