#!/usr/bin/env bash
# Load Secrets from 1Password

# Signin to 1Password; either via the app integration with the native app
# or using the interactive signin process
export OP_ACCOUNT="foxcorporation.1password.com"
eval "$(op signin)"

# URL encoded email address
export FOX_EMAIL="${USER}%40fox.com"

## GitHub
GITHUB_TOKEN="$(op read op://Private/github-token/credential)"
export GITHUB_TOKEN

## Confluence
CONFLUENCE_USER="$(op read op://Private/confluence-token/username)"
CONFLUENCE_API_TOKEN="$(op read op://Private/confluence-token/credential)"
export CONFLUENCE_USER
export CONFLUENCE_API_TOKEN

ATLASSIAN_TOKEN="$(op read op://Private/ATLASSIAN_API_TOKEN/credential)"
export ATLASSIAN_TOKEN
export JIRA_API_TOKEN=$ATLASSIAN_TOKEN

ARTIFACTORY_TOKEN="$(op read op://Employee/Artifactory\ DPE/credential)"
export ARTIFACTORY_TOKEN
