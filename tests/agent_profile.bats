#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/home.XXXXXX")"
  MOCK_BIN="$(mktemp -d "${BATS_TEST_TMPDIR}/bin.XXXXXX")"
  export REPO_ROOT TEST_HOME MOCK_BIN
  mkdir -p "${TEST_HOME}/.config/dotfiles/profiles" "${TEST_HOME}/.config/dotfiles/secrets"
  cp "${REPO_ROOT}/home/.bash_profile" "${TEST_HOME}/.bash_profile"
  if [[ -d "${REPO_ROOT}/home/.config/dotfiles" ]]; then
    cp -R "${REPO_ROOT}/home/.config/dotfiles/." "${TEST_HOME}/.config/dotfiles/"
  fi
}

teardown() {
  rm -rf "${TEST_HOME}" "${MOCK_BIN}"
}

@test "agent profile is the quiet default and does not invoke op" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
touch "${OP_CALLED_FILE}"
exit 99
EOF
  chmod +x "${MOCK_BIN}/op"
  export OP_CALLED_FILE="${TEST_HOME}/op-called"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; printf "%s|%s|%s" "$DOTFILES_PROFILE" "$PAGER" "$GIT_TERMINAL_PROMPT"'

  [ "$status" -eq 0 ]
  [ "$output" = "agent|cat|0" ]
  [ ! -e "${OP_CALLED_FILE}" ]
}

@test "agent profile exposes human and secret entry points without human aliases" {
  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; type load-human-profile; type human-shell; type with-agent-secrets; type load-agent-secrets; alias ls 2>/dev/null || true'

  [ "$status" -eq 0 ]
  [[ "$output" == *"load-human-profile is a function"* ]]
  [[ "$output" == *"human-shell is a function"* ]]
  [[ "$output" == *"with-agent-secrets is a function"* ]]
  [[ "$output" == *"load-agent-secrets is a function"* ]]
  [[ "$output" != *"alias ls="* ]]
}

@test "with-agent-secrets scopes op references to one command" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "run" ]] || exit 90
shift
[[ "$1" == --env-file=* ]] || exit 91
shift
[[ "$1" == "--" ]] || exit 92
shift
GITHUB_TOKEN='scoped value' "$@"
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; with-agent-secrets -- bash -c '\''printf "%s" "$GITHUB_TOKEN"'\'''

  [ "$status" -eq 0 ]
  [ "$output" = "scoped value" ]
}

@test "load-agent-secrets imports only allowlisted names" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "read" ]] || exit 90
printf 'value for %s' "$2"
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-agent-secrets; printf "%s" "$GITHUB_TOKEN"'

  [ "$status" -eq 0 ]
  [ "$output" = "value for op://Employee/github-token/credential" ]
}

@test "secret helper fails with an actionable error when op is unavailable" {
  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; with-agent-secrets -- true'

  [ "$status" -ne 0 ]
  [[ "$output" == *"1Password CLI 'op' is required"* ]]
}

@test "load-human-profile changes the existing shell" {
  cat >"${TEST_HOME}/human-test.bash" <<'EOF'
export HUMAN_PROFILE_LOADED=1
alias human-only='true'
EOF

  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" DOTFILES_HUMAN_PROFILE="${TEST_HOME}/human-test.bash" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-profile; alias human-only; printf "|%s|%s" "$DOTFILES_PROFILE" "$HUMAN_PROFILE_LOADED"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"alias human-only='true'"* ]]
  [[ "$output" == *"|human|1"* ]]
}

@test "versioned SSH fragment selects the 1Password agent" {
  run grep -F 'IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"' \
    "${REPO_ROOT}/home/.ssh/config.d/1password.conf"

  [ "$status" -eq 0 ]
}
