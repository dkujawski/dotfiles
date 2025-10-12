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

# Function to attempt loading secrets
attempt_load_secrets() {
    local timeout_duration="${1:-30}"
    debug_log "Attempting to load secrets with ${timeout_duration}s timeout"
    
    if secrets_output=$(timeout "${timeout_duration}s" bash "$SECRETS_LOADER" 2>&1); then
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
                if [ "$DEBUG" = "1" ] || [ "$DEBUG" = "true" ]; then
                    # Extract variable name for debug logging
                    var_name=$(echo "$line" | sed 's/^export \([^=]*\)=.*/\1/')
                    debug_log "Processing environment variable: $var_name"
                fi
                eval "$line"
            fi
        done <<< "$secrets_output"
        return 0
    else
        return $?
    fi
}

# Function to attempt op signin to foxcorporation account
attempt_fox_signin() {
    debug_log "Attempting op signin to foxcorporation account"
    
    # Check if we're in an interactive terminal
    if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
        debug_log "Interactive terminal detected, attempting signin to foxcorporation.1password.com"
        if op signin --account foxcorporation.1password.com >/dev/null 2>&1; then
            debug_log "Successfully signed in to foxcorporation.1password.com"
            return 0
        else
            debug_log "Signin to foxcorporation.1password.com failed or was cancelled"
            return 1
        fi
    else
        debug_log "Non-interactive context, skipping signin attempt"
        return 1
    fi
}

# Load secrets using the secure shell-based approach with timeout
# Make secrets loading non-fatal to allow shell to start even if 1Password is unavailable
if attempt_load_secrets 30; then
    debug_log "Secrets loaded successfully on first attempt"
else
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        echo "Warning: load-secrets command timed out after 30 seconds" >&2
        echo "Continuing shell initialization without secrets..." >&2
    else
        debug_log "Initial secret loading failed (exit code: $exit_code), attempting op signin to foxcorporation account"
        
        # Attempt op signin to foxcorporation account
        if attempt_fox_signin; then
            debug_log "Foxcorporation account signin successful, retrying secret loading"
            
            # Retry loading secrets after successful signin
            if attempt_load_secrets 15; then
                debug_log "Secrets loaded successfully after account signin"
            else
                retry_exit_code=$?
                if [ $retry_exit_code -eq 124 ]; then
                    echo "Warning: load-secrets retry timed out after 15 seconds" >&2
                    echo "Continuing shell initialization without secrets..." >&2
                else
                    echo "Warning: load-secrets retry failed after fox account signin" >&2
                    echo "Continuing shell initialization without secrets..." >&2
                    if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
                        echo "[DEBUG] Retry secrets output: $secrets_output" >&2
                    fi
                fi
            fi
        else
            echo "Warning: load-secrets command failed and fox account signin was not successful" >&2
            echo "Continuing shell initialization without secrets..." >&2
            if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
                echo "[DEBUG] Initial secrets output: $secrets_output" >&2
            fi
        fi
    fi
fi

debug_log "Completed loading all secrets"
