# macOS Individual Account Setup Guide

This guide provides the optimal setup for 1Password secrets management on macOS with individual accounts, designed to minimize authentication prompts across multiple shells and IDE sessions.

## **Prerequisites**

1. **1Password Individual Account** (Personal or Family plan)
2. **1Password Desktop App** installed and signed in
3. **1Password CLI** installed via Homebrew
4. **macOS** (tested on macOS 10.15+)

## **Step 1: Install and Configure 1Password CLI**

### Install 1Password CLI
```bash
brew install 1password-cli
```

### Enable Desktop App Integration
This is the **key step** that eliminates most authentication prompts:

1. Open **1Password Desktop App**
2. Go to **Settings** → **Developer**
3. Enable **"Integrate with 1Password CLI"**
4. Optionally enable **"Connect with 1Password CLI"** for additional integration

### Verify Integration
```bash
# This should work without prompting for authentication
op whoami
```

If this works without prompting, you're ready to go!

## **Step 2: Organize Your Secrets**

### Create Development Items in 1Password
Since individual accounts can use the built-in **Private** vault, organize your secrets there:

**Recommended Structure:**
```
Private Vault:
├── github-token
│   └── credential: ghp_your_token_here
├── confluence-token  
│   ├── username: your.username
│   └── credential: your_api_token
├── ATLASSIAN_API_TOKEN
│   └── credential: your_atlassian_token
└── Artifactory DPE
    └── credential: your_artifactory_token
```

### Test Secret Access
```bash
# Test reading a secret
op read "op://Private/github-token/credential"
```

## **Step 3: Deploy the macOS-Optimized Implementation**

```bash
# Install the dotfiles with macOS optimization
make install-dotfiles
```

This deploys both the generic and macOS-optimized versions, with the wrapper automatically preferring the macOS version.

## **Step 4: Configure Your Environment**

### Set Your 1Password Account (if different)
```bash
# Add to ~/.extra or ~/.bash_profile
export OP_ACCOUNT="your-account.1password.com"
```

### Enable Debug Mode (Optional)
```bash
# For troubleshooting
export DEBUG=1
```

## **How It Works: Authentication Strategy**

The macOS implementation uses a **smart authentication hierarchy**:

### 1. **Desktop App Integration (Primary)**
- **No prompts needed** - uses your existing desktop app session
- **Seamless experience** across all shells and IDEs
- **Automatic session management**

### 2. **Session Caching (Secondary)**
- Caches successful authentication for **8 hours**
- Reduces prompts when desktop integration isn't available
- Automatic cache invalidation when sessions expire

### 3. **Smart Signin (Fallback)**
- Only prompts when absolutely necessary
- Uses account hint to reduce authentication steps
- Graceful handling of cancelled authentications

### 4. **Secrets Caching (Performance)**
- Caches loaded secrets for **60 minutes** (longer than generic version)
- Reduces 1Password API calls by ~95%
- Secure file permissions (600/700)

## **IDE Integration**

### **VS Code**
The implementation works seamlessly with VS Code terminals:

1. **Integrated Terminal**: Inherits the parent shell's 1Password session
2. **Debug Sessions**: Environment variables are automatically available
3. **Extensions**: Works with extensions that spawn shell processes

### **JetBrains IDEs (IntelliJ, WebStorm, etc.)**
```bash
# In IDE terminal settings, ensure shell is set to:
/bin/bash --login
```

### **Terminal Apps (iTerm2, Terminal.app)**
- **New tabs**: Inherit the session from the first authenticated tab
- **New windows**: May require one authentication per window session
- **Split panes**: Share authentication within the same window

## **Performance Characteristics**

### **Cold Start (First Shell)**
- **With Desktop Integration**: ~0.5 seconds
- **Without Desktop Integration**: ~2-3 seconds (includes signin)

### **Warm Start (Subsequent Shells)**
- **With Cache Hit**: ~0.1 seconds
- **With Desktop Integration**: ~0.3 seconds
- **Session Cached**: ~0.5 seconds

### **Authentication Frequency**
- **Desktop Integration**: Never (as long as desktop app is signed in)
- **Session Caching**: Once per 8 hours maximum
- **Cache Refresh**: Once per hour for secrets

## **Troubleshooting**

### **"Desktop app integration not available"**

**Check Desktop App:**
```bash
# Ensure 1Password app is running
ps aux | grep "1Password"

# Check CLI integration setting
op --version
```

**Solution:**
1. Restart 1Password desktop app
2. Re-enable CLI integration in Settings → Developer
3. Try `op whoami` again

### **"Session expired" errors**

**Clear session cache:**
```bash
rm -rf ~/.cache/op-secrets-macos/session.cache
```

**Re-authenticate:**
```bash
op signin --account your-account.1password.com
```

### **IDE not loading secrets**

**Check shell configuration:**
```bash
# Ensure IDE uses login shell
echo $0  # Should show bash with - prefix (login shell)
```

**VS Code specific:**
```json
// In settings.json
{
    "terminal.integrated.shell.osx": "/bin/bash",
    "terminal.integrated.shellArgs.osx": ["--login"]
}
```

### **Multiple authentication prompts**

**Check for competing configurations:**
```bash
# Look for other 1Password configurations
grep -r "op signin" ~/.bash* ~/.zsh* 2>/dev/null
```

**Disable other 1Password integrations** that might conflict.

## **Security Considerations**

### **Session Management**
- **Desktop Integration**: Most secure - uses 1Password's native session management
- **Session Caching**: Stores only timestamp, not credentials
- **Cache Location**: `~/.cache/op-secrets-macos/` with restricted permissions

### **Secret Exposure**
- **Process Lists**: Secrets never appear in `ps` output
- **Shell History**: No secrets stored in command history  
- **Environment**: Minimal exposure window during export
- **File System**: Cached secrets have 600 permissions

### **Best Practices**
1. **Keep Desktop App Running**: Ensures seamless authentication
2. **Regular Updates**: Keep 1Password CLI and desktop app updated
3. **Monitor Sessions**: Check 1Password Activity for unusual access
4. **Secure Workstation**: Use FileVault and screen lock
5. **Clear Cache**: Periodically clear cache if sharing the machine

## **Advanced Configuration**

### **Custom Cache TTL**
Edit `tools/load-secrets-macos.sh`:
```bash
# Adjust these values as needed
CACHE_TTL_MINUTES=120        # 2 hours for secrets
SESSION_TTL_MINUTES=960      # 16 hours for session
```

### **Additional Secrets**
Add new secrets by editing the `create_env_file()` function:
```bash
# Add to the EOF block
NEW_SECRET=op://Private/new-item/credential
```

### **Multiple Accounts**
For multiple 1Password accounts:
```bash
# Set specific account per project
export OP_ACCOUNT="work-account.1password.com"
# or
export OP_ACCOUNT="personal-account.1password.com"
```

This implementation provides the optimal balance of security, performance, and user experience for individual 1Password accounts on macOS.
