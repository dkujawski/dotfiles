#!/usr/bin/env bash
# Centralized 1Password Secrets Configuration
# This file defines all environment variables and their 1Password references

# Define secrets mapping as associative array
declare -A SECRETS_CONFIG=(
    ["GITHUB_TOKEN"]="op://Employee/github-token/credential"
    ["ATLASSIAN_TOKEN"]="op://Employee/atlassian-token/credential"
    ["JIRA_USER"]="op://Employee/ATLASSIAN_API_TOKEN/username"
    ["JIRA_API_TOKEN"]="op://Employee/ATLASSIAN_API_TOKEN/credential"
    ["CONFLUENCE_USER"]="op://Employee/confluence-token/username"
    ["CONFLUENCE_API_TOKEN"]="op://Employee/confluence-token/credential"
    ["ARTIFACTORY_TOKEN"]="op://Employee/Artifactory DPE/credential"
    ["OPENAI_TOKEN"]="op://Employee/OpenAi/credential"
)

# Function to get all secret names
get_secret_names() {
    printf '%s\n' "${!SECRETS_CONFIG[@]}"
}

# Function to get 1Password reference for a secret
get_secret_reference() {
    local secret_name="$1"
    echo "${SECRETS_CONFIG[$secret_name]}"
}

# Function to get all 1Password references
get_all_references() {
    printf '%s\n' "${SECRETS_CONFIG[@]}"
}

# Function to create environment file for op run
create_env_file() {
    local env_file="$1"
    cat > "$env_file" << 'EOF'
# 1Password Secret References for Employee Vault
# Using Employee vault (available in foxcorporation accounts)

GITHUB_TOKEN=op://Employee/github-token/credential
ATLASSIAN_TOKEN=op://Employee/atlassian-token/credential
JIRA_USER=op://Employee/ATLASSIAN_API_TOKEN/username
JIRA_API_TOKEN=op://Employee/ATLASSIAN_API_TOKEN/credential
CONFLUENCE_USER=op://Employee/confluence-token/username
CONFLUENCE_API_TOKEN=op://Employee/confluence-token/credential
ARTIFACTORY_TOKEN=op://Employee/Artifactory DPE/credential
OPENAI_TOKEN=op://Employee/OpenAi/credential
EOF
}

# Export functions for use in other scripts
export -f get_secret_names
export -f get_secret_reference
export -f get_all_references
export -f create_env_file