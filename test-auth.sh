#!/usr/bin/env bash
# Test authentication without hanging

set -euo pipefail

debug_log() {
    echo "[DEBUG] $*" >&2
}

# Test non-interactive authentication check
check_auth_test() {
    debug_log "Testing 1Password authentication"
    
    # For service accounts, check if token is set
    if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
        debug_log "Using service account authentication"
        return 0
    fi
    
    # For user accounts, check session
    if timeout 3s op whoami >/dev/null 2>&1; then
        debug_log "Valid user session found"
        return 0
    else
        debug_log "No valid 1Password session found"
        # Don't attempt interactive signin in non-interactive contexts
        if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
            debug_log "Interactive terminal detected - would attempt signin"
            debug_log "Skipping actual signin for test"
            return 1
        else
            debug_log "Non-interactive context, skipping signin attempt"
            return 1
        fi
    fi
}

echo "Testing authentication logic..."
if check_auth_test; then
    echo "✅ Authentication successful"
else
    echo "❌ Authentication failed (expected if not signed in)"
fi
echo "✅ Test completed without hanging"
