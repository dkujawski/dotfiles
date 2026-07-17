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

@test "human startup exposes secret helpers without invoking op" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
touch "${OP_CALLED_FILE}"
exit 99
EOF
  chmod +x "${MOCK_BIN}/op"
  export OP_CALLED_FILE="${TEST_HOME}/op-called"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile" && declare -F with-human-secrets >/dev/null && declare -F load-human-secrets >/dev/null && declare -F load-secrets >/dev/null'

  [ "$status" -eq 0 ]
  [ ! -e "${OP_CALLED_FILE}" ]
}

@test "with-human-secrets limits credentials to one child command" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
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

@test "human secret helper reports a missing op command" {
  run -127 env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" DOTFILES_PROFILE=human \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; with-human-secrets -- true'

  [ "$status" -ne 0 ]
  [[ "$output" == *"1Password CLI 'op' is required"* ]]
}

@test "load-human-secrets rejects invalid mappings before reading them" {
  cat >"${TEST_HOME}/invalid.env" <<'EOF'
lowercase_name=op://Employee/example/credential
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
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
