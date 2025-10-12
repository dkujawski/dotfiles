#!/usr/bin/env bash
# 1Password Secrets Loader - Following Official Best Practices
# Uses 1Password CLI with secure patterns to avoid plaintext secret exposure

set -euo pipefail

# Load centralized secrets configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/secrets-config.sh" ]; then
    source "${SCRIPT_DIR}/secrets-config.sh"
else
    echo "Error: secrets-config.sh not found" >&2
    exit 1
fi

# Configuration
CACHE_DIR="${HOME}/.cache/op-secrets-secure"
CACHE_TTL_MINUTES=30
CACHE_FILE="${CACHE_DIR}/secrets.cache"

# Debug logging function
debug_log() {
    if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Check if 1Password CLI is available
check_op_cli() {
    if ! command -v op >/dev/null 2>&1; then
        echo "Error: 1Password CLI (op) is not installed or not in PATH" >&2
        echo "Please install from: https://developer.1password.com/docs/cli/get-started/" >&2
        return 1
    fi
}

# Verify authentication (non-interactive)
check_auth() {
    debug_log "Checking 1Password authentication"
    
    # For service accounts, check if token is set
    if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
        debug_log "Using service account authentication"
        return 0
    fi
    
    # For user accounts, check session
    if op whoami >/dev/null 2>&1; then
        debug_log "Valid user session found"
        return 0
    else
        debug_log "No valid 1Password session found"
        # Attempt interactive signin to foxcorporation account
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
    fi
}

# Note: create_env_file function is now provided by secrets-config.sh

# Load secrets using op run (preferred method)
load_secrets_with_op_run() {
    debug_log "Loading secrets using 1Password CLI 'op run' command"
    
    # Create temporary environment file
    local temp_env_file
    temp_env_file=$(mktemp)
    trap "rm -f '$temp_env_file'" EXIT
    
    create_env_file "$temp_env_file"
    
    # Use op run to inject secrets and export them
    debug_log "Injecting secrets into environment using op run"
    
    # This approach uses op run to safely inject secrets without exposing them in process lists
    local output
    output=$(op run --env-file="$temp_env_file" -- bash -c '
        # Export all variables that were injected by op run
        env | grep -E "^(GITHUB_TOKEN|CONFLUENCE_USER|CONFLUENCE_API_TOKEN|ATLASSIAN_TOKEN|JIRA_API_TOKEN|ARTIFACTORY_TOKEN|TF_TOKEN_app_terraform_io)=" | while IFS= read -r line; do
            echo "export $line"
        done
    ' 2>/dev/null)
    
    # Check if output contains concealed values (1Password security feature)
    if echo "$output" | grep -q "<concealed by 1Password>"; then
        debug_log "op run output contains concealed values, falling back to direct reads"
        return 1
    fi
    
    # Only output if we have valid (non-concealed) secrets
    if [ -n "$output" ]; then
        # Extract and log environment variable names being populated
        if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
            echo "$output" | grep "^export " | sed 's/^export \([^=]*\)=.*/\1/' | while IFS= read -r var_name; do
                debug_log "Populating environment variable: $var_name"
            done
        fi
        echo "$output"
    else
        return 1
    fi
}

# Alternative: Direct op read approach (fallback when op run is not available)
load_secrets_direct() {
    debug_log "Loading secrets using direct op read (fallback method)"
    
    # Use centralized secrets configuration
    declare -A secrets
    while IFS= read -r secret_name; do
        secrets["$secret_name"]=$(get_secret_reference "$secret_name")
    done < <(get_secret_names)
    
    local success_count=0
    local total_count=${#secrets[@]}
    
    for var_name in "${!secrets[@]}"; do
        local secret_ref="${secrets[$var_name]}"
        debug_log "Loading $var_name from $secret_ref"
        
        if value=$(op read "$secret_ref" 2>/dev/null); then
            # Check if the value is concealed
            if [[ "$value" == *"<concealed by 1Password>"* ]]; then
                debug_log "Received concealed value for $var_name, skipping"
                continue
            fi
            
            echo "export $var_name='$value'"
            debug_log "Populating environment variable: $var_name"
            success_count=$((success_count + 1))
            
            # Also export JIRA_API_TOKEN as alias for ATLASSIAN_TOKEN
            if [ "$var_name" = "ATLASSIAN_TOKEN" ]; then
                echo "export JIRA_API_TOKEN='$value'"
                debug_log "Populating environment variable: JIRA_API_TOKEN"
            fi
        else
            debug_log "Failed to read $secret_ref"
        fi
    done
    
    debug_log "Successfully loaded $success_count/$total_count secrets"
    
    # Return success if we loaded at least some secrets
    [ "$success_count" -gt 0 ]
}

# Secure cache functions
setup_cache() {
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR"
        chmod 700 "$CACHE_DIR"
    fi
}

is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi
    
    local cache_age
    # Handle both macOS and Linux stat commands
    if command -v stat >/dev/null 2>&1; then
        if stat -f %m "$CACHE_FILE" >/dev/null 2>&1; then
            # macOS
            cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE")))
        else
            # Linux
            cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE")))
        fi
    else
        # Fallback: assume cache is invalid if we can't check
        return 1
    fi
    
    local cache_ttl_seconds=$((CACHE_TTL_MINUTES * 60))
    [ "$cache_age" -lt "$cache_ttl_seconds" ]
}

load_from_cache() {
    if is_cache_valid; then
        debug_log "Loading secrets from cache"
        cat "$CACHE_FILE"
        return 0
    fi
    return 1
}

save_to_cache() {
    setup_cache
    debug_log "Saving secrets to cache"
    cat > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"
}

# Main execution function
main() {
    debug_log "Starting 1Password secrets loading"
    
    # Enable 1Password CLI caching for better performance
    export OP_CACHE=true
    
    # Set up 1Password account if not already set
    export OP_ACCOUNT="${OP_ACCOUNT:-foxcorporation.1password.com}"
    debug_log "Using 1Password account: $OP_ACCOUNT"
    
    # Set FOX_EMAIL if not set
    if [ -z "${FOX_EMAIL:-}" ]; then
        export FOX_EMAIL="${USER:-$(whoami)}@fox.com"
        debug_log "Set FOX_EMAIL to: $FOX_EMAIL"
    fi
    
    # Check prerequisites
    check_op_cli || return 1
    check_auth || return 1
    
    # Try cache first for better performance
    if load_from_cache; then
        return 0
    fi
    
    # Load fresh secrets and cache them
    local secrets_output
    if secrets_output=$(load_secrets_with_op_run 2>/dev/null) && [ -n "$secrets_output" ]; then
        debug_log "Successfully loaded secrets using op run"
        echo "$secrets_output" | tee >(save_to_cache)
    else
        debug_log "op run method failed or contained concealed values, falling back to direct reads"
        if secrets_output=$(load_secrets_direct 2>/dev/null) && [ -n "$secrets_output" ]; then
            debug_log "Successfully loaded secrets using direct method"
            echo "$secrets_output" | tee >(save_to_cache)
        else
            echo "Error: Failed to load secrets using both methods" >&2
            return 1
        fi
    fi
    
    debug_log "Completed loading all secrets"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

