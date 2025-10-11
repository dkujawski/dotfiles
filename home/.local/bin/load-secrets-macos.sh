#!/usr/bin/env bash
# 1Password Secrets Loader - Optimized for macOS Individual Accounts
# Minimizes authentication prompts across multiple shells and IDE sessions

set -euo pipefail

# Configuration
CACHE_DIR="${HOME}/.cache/op-secrets-macos"
CACHE_TTL_MINUTES=60  # Longer TTL for individual accounts
CACHE_FILE="${CACHE_DIR}/secrets.cache"
SESSION_CACHE_FILE="${CACHE_DIR}/session.cache"
SESSION_TTL_MINUTES=480  # 8 hours - typical 1Password session length

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
        echo "Install with: brew install 1password-cli" >&2
        return 1
    fi
}

# Check if 1Password desktop app integration is enabled
check_desktop_integration() {
    debug_log "Checking 1Password desktop app integration"
    
    # Try a quick whoami command to test integration
    if op whoami >/dev/null 2>&1; then
        debug_log "Desktop app integration is working"
        return 0
    else
        debug_log "Desktop app integration not available"
        return 1
    fi
}

# Check session validity with caching
is_session_valid() {
    if [ ! -f "$SESSION_CACHE_FILE" ]; then
        return 1
    fi
    
    local session_age
    if command -v stat >/dev/null 2>&1; then
        if stat -f %m "$SESSION_CACHE_FILE" >/dev/null 2>&1; then
            # macOS
            session_age=$(($(date +%s) - $(stat -f %m "$SESSION_CACHE_FILE")))
        else
            # Fallback
            session_age=$(($(date +%s) - $(stat -c %Y "$SESSION_CACHE_FILE")))
        fi
    else
        return 1
    fi
    
    local session_ttl_seconds=$((SESSION_TTL_MINUTES * 60))
    [ "$session_age" -lt "$session_ttl_seconds" ]
}

# Update session cache
update_session_cache() {
    setup_cache
    touch "$SESSION_CACHE_FILE"
    chmod 600 "$SESSION_CACHE_FILE"
}

# Smart authentication that minimizes prompts
ensure_authenticated() {
    debug_log "Checking authentication status"
    
    # First, try desktop app integration (no prompts needed)
    if check_desktop_integration; then
        debug_log "Using 1Password desktop app integration"
        update_session_cache
        return 0
    fi
    
    # Check if we have a recent session cache
    if is_session_valid; then
        debug_log "Using cached session"
        # Test if the session is actually still valid
        if op whoami >/dev/null 2>&1; then
            return 0
        else
            debug_log "Cached session expired, removing cache"
            rm -f "$SESSION_CACHE_FILE"
        fi
    fi
    
    # Only prompt for signin if in interactive context
    debug_log "No valid session found"
    
    # Check if we're in an interactive terminal
    if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
        debug_log "Interactive terminal detected, attempting signin"
        # Use op signin with account hint to reduce prompts
        if op signin --account foxcorporation.1password.com >/dev/null 2>&1; then
            debug_log "Successfully signed in"
            update_session_cache
            return 0
        else
            debug_log "Signin failed or was cancelled"
            return 1
        fi
    else
        debug_log "Non-interactive context, skipping signin attempt"
        return 1
    fi
}

# Create environment file with secret references
create_env_file() {
    local env_file="$1"
    debug_log "Creating environment file: $env_file"
    
    cat > "$env_file" << 'EOF'
# 1Password Secret References for Individual Account
# Using Private vault (available in individual accounts)

GITHUB_TOKEN=op://Private/github-token/credential
CONFLUENCE_USER=op://Private/confluence-token/username
CONFLUENCE_API_TOKEN=op://Private/confluence-token/credential
ATLASSIAN_TOKEN=op://Private/ATLASSIAN_API_TOKEN/credential
JIRA_API_TOKEN=op://Private/ATLASSIAN_API_TOKEN/credential
ARTIFACTORY_TOKEN=op://Private/Artifactory DPE/credential
TF_TOKEN_app_terraform_io=op://Private/tf_cloud_javisrike/credential
EOF
}

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
        echo "$output"
    else
        return 1
    fi
}

# Alternative: Direct op read approach (fallback)
load_secrets_direct() {
    debug_log "Loading secrets using direct op read (fallback method)"
    
    declare -A secrets=(
        ["GITHUB_TOKEN"]="op://Private/github-token/credential"
        ["CONFLUENCE_USER"]="op://Private/confluence-token/username"
        ["CONFLUENCE_API_TOKEN"]="op://Private/confluence-token/credential"
        ["ATLASSIAN_TOKEN"]="op://Private/ATLASSIAN_API_TOKEN/credential"
        ["ARTIFACTORY_TOKEN"]="op://Private/Artifactory DPE/credential"
        ["TF_TOKEN_app_terraform_io"]="op://Private/tf_cloud_javisrike/credential"
    )
    
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
            success_count=$((success_count + 1))
            
            # Also export JIRA_API_TOKEN as alias for ATLASSIAN_TOKEN
            if [ "$var_name" = "ATLASSIAN_TOKEN" ]; then
                echo "export JIRA_API_TOKEN='$value'"
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
    if command -v stat >/dev/null 2>&1; then
        if stat -f %m "$CACHE_FILE" >/dev/null 2>&1; then
            # macOS
            cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE")))
        else
            # Linux fallback
            cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE")))
        fi
    else
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
    debug_log "Starting 1Password secrets loading (macOS optimized)"
    
    # Enable 1Password CLI caching for better performance
    export OP_CACHE=true
    
    # Set up 1Password account
    export OP_ACCOUNT="${OP_ACCOUNT:-foxcorporation.1password.com}"
    debug_log "Using 1Password account: $OP_ACCOUNT"
    
    # Set FOX_EMAIL if not set
    if [ -z "${FOX_EMAIL:-}" ]; then
        export FOX_EMAIL="${USER:-$(whoami)}@fox.com"
        debug_log "Set FOX_EMAIL to: $FOX_EMAIL"
    fi
    
    # Check prerequisites
    check_op_cli || return 1
    
    # Try cache first for better performance
    if load_from_cache; then
        debug_log "Using cached secrets"
        return 0
    fi
    
    # Ensure authentication (smart, minimal prompts)
    if ! ensure_authenticated; then
        debug_log "Authentication failed, cannot load secrets"
        return 1
    fi
    
    # Load fresh secrets and cache them
    local secrets_output
    debug_log "Attempting to load secrets with op run..."
    if secrets_output=$(load_secrets_with_op_run 2>/dev/null) && [ -n "$secrets_output" ]; then
        debug_log "Successfully loaded secrets using op run"
        echo "$secrets_output" | tee >(save_to_cache)
    else
        debug_log "op run method failed or contained concealed values, falling back to direct reads"
        if secrets_output=$(load_secrets_direct 2>/dev/null) && [ -n "$secrets_output" ]; then
            debug_log "Successfully loaded secrets using direct method"
            echo "$secrets_output" | tee >(save_to_cache)
        else
            debug_log "Failed to load secrets using both methods"
            return 1
        fi
    fi
    
    debug_log "Completed loading all secrets"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
