# Load Secrets Tool

A Go-based tool for loading secrets from 1Password and exporting them as environment variables. This tool is a rewrite of the original Rust implementation using the official 1Password Go SDK.

## Features

- Caches secrets locally with TTL
- Uses official 1Password Go SDK
- Supports debug logging
- Exports secrets as shell environment variables
- Handles multiple vaults and items
- Configurable via YAML file
- Supports custom paths via CLI arguments

## Prerequisites

- Go 1.21 or later
- 1Password CLI installed and configured
- 1Password Service Account token

## Installation

1. Clone the repository
2. Navigate to the tool directory:
   ```bash
   cd tools/load-secrets-go
   ```
3. Install dependencies:
   ```bash
   go mod download
   ```
4. Build the tool:
   ```bash
   go build
   ```

## Usage

1. Set up your 1Password Service Account token:
   ```bash
   export OP_SERVICE_ACCOUNT_TOKEN='your-token-here'
   ```

2. Run the tool with default configuration:
   ```bash
   ./load-secrets-go
   ```

3. Run with a custom configuration file:
   ```bash
   ./load-secrets-go --config /path/to/config.yaml
   ```

4. Run with a custom 1Password path:
   ```bash
   ./load-secrets-go --path "op://vault/item/field" --env CUSTOM_VAR
   ```

5. To enable debug logging:
   ```bash
   export DEBUG=1
   ./load-secrets-go
   ```

## Configuration File

The tool uses a YAML configuration file (`config.yaml` by default) to define the 1Password paths to load. Example configuration:

```yaml
paths:
  - uri: "op://Private/github-token/credential"
    env: "GITHUB_TOKEN"
    is_ref: true
  - uri: "op://Private/confluence-token/username"
    env: "CONFLUENCE_USER"
    is_ref: true
  - uri: "op://Private/ATLASSIAN_API_TOKEN/credential"
    env: "ATLASSIAN_TOKEN"
    is_ref: true
    aliases: ["JIRA_API_TOKEN"]
```

### Configuration Options

- `uri`: The 1Password reference URI (format: `op://vault/item/field`)
- `env`: The environment variable name to export
- `is_ref`: Whether to use the reference resolver (usually true)
- `aliases`: Optional list of additional environment variable names to export the same value

## Command Line Arguments

- `--config`: Path to configuration file (default: "config.yaml")
- `--path`: Custom 1Password path to load (format: op://vault/item/field)
- `--env`: Environment variable name for custom path (required when using --path)

## Environment Variables

The tool uses the following environment variables:
- `OP_SERVICE_ACCOUNT_TOKEN`: Your 1Password Service Account token
- `OP_ACCOUNT`: Your 1Password account (defaults to foxcorporation.1password.com)
- `DEBUG`: Set to "1" or "true" to enable debug logging

## Cache

The tool caches secrets in `~/.cache/op-secrets` with a 30-minute TTL by default. The cache is stored as encrypted JSON files.

## Security

- Secrets are cached locally with encryption
- Cache files have restricted permissions (0600)
- Cache directory has restricted permissions (0700)
- Cache entries expire after 30 minutes 
