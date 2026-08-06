#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0
  unset DOTFILES_AGENT_PROFILE_LOADED DOTFILES_CONFIG_DIR DOTFILES_HOMEBREW_PREFIX \
    DOTFILES_HUMAN_PROFILE DOTFILES_HUMAN_SECRETS_FILE DOTFILES_OP_SSH_AUTH_SOCK \
    DOTFILES_PROFILE DOTFILES_PROFILE_LOADED DOTFILES_SECRETS_FILE
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/human-home.XXXXXX")"
  MOCK_BIN="$(mktemp -d "${BATS_TEST_TMPDIR}/human-bin.XXXXXX")"
  export REPO_ROOT TEST_HOME MOCK_BIN
  cat >"${MOCK_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${MOCK_BIN}/brew"
  "${REPO_ROOT}/tools/deploy-agent.sh" --profile human --home "${TEST_HOME}" >/dev/null
}

teardown() {
  rm -rf "${TEST_HOME}" "${MOCK_BIN}"
}

@test "human startup authenticates op without resolving secrets" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == whoami ]]; then
  touch "${OP_AUTHENTICATED_FILE}"
  exit 0
fi
touch "${OP_SECRET_CALLED_FILE}"
exit 99
EOF
  chmod +x "${MOCK_BIN}/op"
  export OP_AUTHENTICATED_FILE="${TEST_HOME}/op-authenticated"
  export OP_SECRET_CALLED_FILE="${TEST_HOME}/op-secret-called"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    OP_AUTHENTICATED_FILE="${OP_AUTHENTICATED_FILE}" \
    OP_SECRET_CALLED_FILE="${OP_SECRET_CALLED_FILE}" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile" && declare -F with-human-secrets >/dev/null && declare -F load-human-secrets >/dev/null && declare -F load-secrets >/dev/null'

  [ "$status" -eq 0 ]
  [ -e "${OP_AUTHENTICATED_FILE}" ]
  [ ! -e "${OP_SECRET_CALLED_FILE}" ]
}

@test "human startup ignores a stale legacy secrets module" {
  cat >"${TEST_HOME}/.local/share/bash/load-secrets.sh" <<'EOF'
printf 'stale legacy secrets module was sourced\n' >&2
exit 42
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == whoami ]]
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; declare -F load-human-secrets >/dev/null; printf "shell-alive"'

  [ "$status" -eq 0 ]
  [ "$output" = "shell-alive" ]
}

@test "with-human-secrets limits credentials to one child command" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == whoami ]] && exit 0
[[ "$1" == run ]] || exit 90
shift
[[ "$1" == --env-file=* ]] || exit 91
shift
[[ "$1" == -- ]] || exit 92
shift
GITHUB_TOKEN='scoped value' "$@"
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; with-human-secrets -- bash -c '\''printf "%s" "$GITHUB_TOKEN"'\''; printf "|%s" "${GITHUB_TOKEN-unset}"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"scoped value|unset" ]]
}

@test "load-human-secrets explicitly imports validated references" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == whoami ]] && exit 0
[[ "$1" == read ]] || exit 90
printf 'value for %s' "$2"
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-secrets; printf "%s" "$GITHUB_TOKEN"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"value for op://Employee/github-token/credential" ]]
}

@test "human and agent profiles use the same secret mapping override" {
  cat >"${TEST_HOME}/shared.env" <<'EOF'
SHARED_TOKEN=op://Employee/shared-token/credential
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == whoami ]] && exit 0
[[ "$1" == read ]] || exit 90
printf 'value for %s' "$2"
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    DOTFILES_SECRETS_FILE="${TEST_HOME}/shared.env" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-secrets; printf "%s" "$SHARED_TOKEN"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"value for op://Employee/shared-token/credential" ]]
}

@test "human profile reports a missing op command" {
  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"'

  [ "$status" -eq 1 ]
  [[ "$output" == *"1Password CLI 'op' is required"* ]]
}

@test "load-human-secrets rejects invalid mappings before reading them" {
  cat >"${TEST_HOME}/invalid.env" <<'EOF'
lowercase_name=op://Employee/example/credential
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == whoami ]] && exit 0
exit 98
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    DOTFILES_HUMAN_SECRETS_FILE="${TEST_HOME}/invalid.env" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-secrets'

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid 1Password mapping for lowercase_name"* ]]
}
