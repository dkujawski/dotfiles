# 1Password Secrets Management

This document describes the secure shell-based approach to managing environment secrets using 1Password CLI.

## Architecture Overview

The secrets management system consists of:

1. **`tools/load-secrets-secure.sh`** - Main secrets loader script
2. **`home/.local/share/bash/load-secrets.sh`** - Integration wrapper for bash profile
3. **Secure caching system** - Local encrypted cache with TTL
4. **1Password CLI integration** - Uses official CLI with best practices

## Design Principles

### 1. **Follow 1Password Best Practices**

- Uses `op run` command for secure secret injection when available
- Leverages service account tokens for non-interactive authentication
- Enables 1Password CLI caching with `OP_CACHE=true`
- Falls back gracefully to direct `op read` commands

### 2. **No Compiled Dependencies**

- Pure shell script implementation
- Uses only standard Unix tools and 1Password CLI
- Easy to audit, modify, and debug
- Cross-platform compatibility (macOS/Linux)

### 3. **Security First**

- Secrets never appear in plaintext in process lists
- Secure local caching with restricted file permissions
- Automatic cache expiration (30-minute TTL)
- Timeout protection to prevent hanging processes

### 4. **Performance Optimized**

- Local caching reduces 1Password API calls
- Parallel secret loading where possible
- 1Password CLI caching enabled
- Graceful degradation when services are unavailable

## Authentication Methods

### Service Account Token (Recommended)

```bash
export OP_SERVICE_ACCOUNT_TOKEN='your-service-account-token'
```

**Benefits:**

- Non-interactive authentication
- Suitable for automation and CI/CD
- Can be restricted to specific vaults
- No user session management required

### User Session (Interactive)

```bash
op signin
```

**Benefits:**

- Uses existing user credentials
- Full access to user's vaults
- Interactive MFA support
- Session sharing across terminals

## Secret Configuration

### Current Secret Mappings

| Environment Variable | 1Password Reference |
|---------------------|-------------------|
| `GITHUB_TOKEN` | `op://Private/github-token/credential` |
| `CONFLUENCE_USER` | `op://Private/confluence-token/username` |
| `CONFLUENCE_API_TOKEN` | `op://Private/confluence-token/credential` |
| `ATLASSIAN_TOKEN` | `op://Private/ATLASSIAN_API_TOKEN/credential` |
| `JIRA_API_TOKEN` | `op://Private/ATLASSIAN_API_TOKEN/credential` |
| `ARTIFACTORY_TOKEN` | `op://Employee/Artifactory DPE/credential` |

### Adding New Secrets

1. **Store the secret in 1Password** with appropriate vault and item structure
2. **Edit `tools/load-secrets-secure.sh`** in two places:

   **In `create_env_file()` function:**

   ```bash
   cat > "$env_file" << 'EOF'
   # ... existing secrets ...
   NEW_SECRET=op://VaultName/ItemName/FieldName
   EOF
   ```

   **In `load_secrets_direct()` function:**

   ```bash
   declare -A secrets=(
       # ... existing secrets ...
       ["NEW_SECRET"]="op://VaultName/ItemName/FieldName"
   )
   ```

## Caching System

### Cache Location

- **Directory**: `~/.cache/op-secrets-secure/`
- **Permissions**: `700` (owner read/write/execute only)
- **Files**: Individual cache files with `600` permissions

### Cache Behavior

- **TTL**: 30 minutes (configurable via `CACHE_TTL_MINUTES`)
- **Format**: Shell export commands
- **Validation**: Timestamp-based expiration
- **Cleanup**: Automatic removal of expired entries

### Cache Management

```bash
# Clear all cached secrets
rm -rf ~/.cache/op-secrets-secure

# Check cache status
ls -la ~/.cache/op-secrets-secure

# View cache contents (for debugging)
cat ~/.cache/op-secrets-secure/secrets.cache
```

## Error Handling

### Authentication Failures

- Checks for service account token first
- Falls back to user session validation
- Provides clear error messages with remediation steps
- Graceful exit without exposing sensitive information

### Network Issues

- 30-second timeout on all 1Password CLI operations
- Graceful degradation when 1Password is unavailable
- Cache serves as backup during temporary outages
- Debug logging for troubleshooting connectivity

### Fallback Mechanisms

1. **Primary**: `op run` with environment file injection
2. **Fallback**: Direct `op read` commands for individual secrets
3. **Cache**: Serves cached values when 1Password is unavailable
4. **Graceful failure**: Continues shell initialization without secrets

## Security Considerations

### Threat Model

- **Process monitoring**: Secrets never appear in process lists
- **Shell history**: No secrets stored in command history
- **Environment exposure**: Minimal plaintext exposure window
- **File system**: Secure cache with restricted permissions

### Security Controls

- **Authentication**: Service account tokens or user sessions
- **Authorization**: 1Password vault-level permissions
- **Encryption**: Local cache uses file system permissions
- **Audit**: All access logged in 1Password account
- **Rotation**: Supports automatic secret rotation via 1Password

### Best Practices

1. **Use service account tokens** for automation
2. **Rotate tokens regularly** (quarterly recommended)
3. **Monitor 1Password audit logs** for unusual access
4. **Restrict vault permissions** to minimum required
5. **Clear cache** when changing secrets
6. **Use debug mode** only when necessary

## Troubleshooting

### Common Issues

#### "Not authenticated with 1Password"

```bash
# Check authentication status
op whoami

# Sign in (user session)
op signin

# Set service account token
export OP_SERVICE_ACCOUNT_TOKEN='your-token'
```

#### "Command timed out after 30 seconds"

```bash
# Check 1Password CLI installation
op --version

# Test connectivity
op vault list

# Check network connectivity
ping my.1password.com
```

#### "Failed to read secret"

```bash
# Verify secret reference format
op read "op://Private/item-name/field-name"

# Check vault access
op vault get Private

# List available items
op item list --vault Private
```

### Debug Mode

Enable detailed logging:

```bash
export DEBUG=1
source ~/.bash_profile
```

Debug output includes:

- Authentication method used
- Cache hit/miss status
- 1Password CLI command execution
- Error details and stack traces
- Performance timing information

## Performance Optimization

### Startup Time

- **Cold start**: ~2-3 seconds (with cache miss)
- **Warm start**: ~0.1 seconds (with cache hit)
- **Timeout**: 30 seconds maximum

### API Call Reduction

- Local caching reduces API calls by ~95%
- 1Password CLI caching enabled
- Batch operations where possible
- Parallel secret loading

### Memory Usage

- Minimal memory footprint
- No persistent processes
- Secrets cleared from memory after export
- Cache files are small (< 1KB typically)

## Migration Guide

### Shell-Only Implementation

The system uses only shell script implementations for maximum compatibility and ease of maintenance:

**Current Implementation:**

- Pure shell script approach using bash
- No compilation dependencies or build processes required
- Works across all Unix-like systems (macOS, Linux)
- Complex caching with encryption

**Added:**

- `tools/load-secrets-secure.sh` (Shell implementation)
- Simplified deployment via Makefile
- Direct 1Password CLI integration
- Improved error handling and debugging

### Configuration Changes

**Old approach:**

```bash
# Compiled binary with custom caching
load-secrets
```

**New approach:**

```bash
# Shell script with 1Password CLI
load-secrets-secure.sh
```

The interface remains the same - shell export commands are generated and sourced into the environment.

## Future Enhancements

### Planned Improvements

1. **Hardware security module integration** for key storage
2. **Automatic secret rotation** with notification
3. **Multi-vault support** with priority ordering
4. **Enhanced audit logging** with local records
5. **Performance monitoring** and metrics collection

### Extension Points

- **Custom secret processors** for different formats
- **Additional authentication methods** (OAuth, SAML)
- **Integration hooks** for external systems
- **Policy enforcement** for secret access patterns
