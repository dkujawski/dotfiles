# Dave's dotfiles

Personal dotfiles configuration with secure 1Password integration for shell environments.

## Features

- **Secure Secret Management**: Shell-based 1Password integration following official best practices
- **No Compiled Dependencies**: Pure shell scripts for maximum portability and auditability
- **Performance Optimized**: Caching with TTL to minimize 1Password API calls
- **Cross-Platform**: Works on macOS and Linux
- **Modular Design**: Easy to customize and extend

## Installation

**Warning:** If you want to give these dotfiles a try, you should first fork this repository, review the code, and remove things you don't want or need. Don't blindly use my settings unless you know what that entails. Use at your own risk!

### Prerequisites

1. **1Password CLI**: Install from [1Password Developer Documentation](https://developer.1password.com/docs/cli/get-started/)
2. **Authentication**: Either sign in with `op signin` or set up a service account token

### Quick Install

```bash
git clone https://github.com/dkujawski/dotfiles.git && cd dotfiles && make
```

### Manual Installation Steps

1. **Clone the repository:**

   ```bash
   git clone https://github.com/dkujawski/dotfiles.git
   cd dotfiles
   ```

2. **Install dotfiles and tools:**

   ```bash
   make install-dotfiles
   ```

3. **Install Homebrew packages (optional):**

   ```bash
   make install-brew
   ```

## 1Password Secret Management

This dotfiles configuration includes secure integration with 1Password for managing environment secrets.

### Authentication Options

#### Option 1: Service Account (Recommended for Automation)

```bash
export OP_SERVICE_ACCOUNT_TOKEN='your-service-account-token'
```

#### Option 2: User Session (Interactive)

```bash
op signin
```

### Configured Secrets

The following environment variables are automatically loaded from 1Password:

- `GITHUB_TOKEN` - GitHub personal access token
- `CONFLUENCE_USER` - Confluence username  
- `CONFLUENCE_API_TOKEN` - Confluence API token
- `ATLASSIAN_TOKEN` / `JIRA_API_TOKEN` - Atlassian API token
- `ARTIFACTORY_TOKEN` - Artifactory access token

### Customizing Secret References

Edit `tools/load-secrets-secure.sh` to modify the 1Password secret references:

```bash
# In the create_env_file() function
GITHUB_TOKEN=op://Private/github-token/credential
CUSTOM_SECRET=op://YourVault/YourItem/YourField
```

### Security Features

- **No Plaintext Exposure**: Uses 1Password's `op run` command when possible
- **Secure Caching**: Encrypted cache with 30-minute TTL
- **Minimal Permissions**: Cache files have restricted permissions (0600)
- **Timeout Protection**: 30-second timeout prevents hanging

## Available Make Targets

```bash
make                    # Install dotfiles and Homebrew (default)
make install-dotfiles   # Install dotfiles to home directory  
make install-brew       # Install Homebrew if not present
make deploy-load-secrets # Deploy the shell-based load-secrets tool
make check              # Check for differences between source and destination
make check-extra        # Check for extra files in target
make clean              # Clean up temporary files
make help               # Show all available targets
```

## Customization

### Add Custom Commands

If `~/.extra` exists, it will be sourced along with the other files. You can use this to add custom commands without forking this repository.

### Specify Custom `$PATH`

If `~/.path` exists, it will be sourced to modify your PATH before other configurations load.

## Troubleshooting

### 1Password Authentication Issues

**Problem**: "Not authenticated with 1Password" error
**Solution**:

```bash
# For user accounts
op signin

# For service accounts  
export OP_SERVICE_ACCOUNT_TOKEN='your-token'
```

**Problem**: Secrets loading times out
**Solution**: Check your 1Password CLI installation and network connectivity:

```bash
op --version
op whoami
```

### Cache Issues

**Problem**: Stale secrets being loaded
**Solution**: Clear the cache:

```bash
rm -rf ~/.cache/op-secrets-secure
```

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
export DEBUG=1
source ~/.bash_profile
```

## Security Considerations

- **Service Account Tokens**: Store securely and rotate regularly
- **Cache Location**: `~/.cache/op-secrets-secure` with restricted permissions
- **Cache TTL**: 30 minutes by default, configurable in the script
- **Network**: Requires internet connectivity to 1Password servers
- **Audit**: All 1Password access is logged in your 1Password account

## License

MIT License - see [LICENSE-MIT.txt](LICENSE-MIT.txt)

## Acknowledgments

Based on the excellent dotfiles foundation by [Mathias Bynens](https://github.com/mathiasbynens/dotfiles) and the community.
