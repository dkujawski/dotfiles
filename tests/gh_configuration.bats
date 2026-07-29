#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/gh-home.XXXXXX")"
  MOCK_BIN="$(mktemp -d "${BATS_TEST_TMPDIR}/gh-bin.XXXXXX")"
  export REPO_ROOT TEST_HOME MOCK_BIN
}

teardown() {
  rm -rf "${TEST_HOME}" "${MOCK_BIN}"
}

install_op_mock() {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" != read || "$2" != op://Employee/github-token/credential ]]; then
  exit 90
fi
printf 'expected-token'
EOF
  chmod +x "${MOCK_BIN}/op"
}

install_gh_mock() {
  cat >"${MOCK_BIN}/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth login")
    printf '%s\n' "$*" >"${TEST_HOME}/gh-login-args"
    cat >"${TEST_HOME}/stored-token"
    [[ "${MOCK_GH_LOGIN_FAILURE:-0}" != 1 ]]
    ;;
  "config set")
    printf '%s\n' "$*" >"${TEST_HOME}/gh-config-args"
    ;;
  "config get")
    printf 'ssh\n'
    ;;
  "auth token")
    if [[ "${MOCK_GH_TOKEN_MISMATCH:-0}" == 1 ]]; then
      printf 'different-token'
    else
      cat "${TEST_HOME}/stored-token"
    fi
    ;;
  "api user")
    printf 'dkujawski\n'
    ;;
  *)
    exit 91
    ;;
esac
EOF
  chmod +x "${MOCK_BIN}/gh"
}

@test "configures gh SSH git operations with the 1Password token" {
  install_op_mock
  install_gh_mock

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    "${REPO_ROOT}/tools/configure-gh.sh"

  [ "$status" -eq 0 ]
  grep -Fq \
    'auth login --hostname github.com --git-protocol ssh --skip-ssh-key --with-token' \
    "${TEST_HOME}/gh-login-args"
  [ "$(cat "${TEST_HOME}/stored-token")" = expected-token ]
  [[ "$output" == *"GitHub CLI is authenticated as dkujawski"* ]]
  [[ "$output" == *"stored token matches op://Employee/github-token/credential"* ]]
  [[ "$output" == *"Git operations use SSH"* ]]
}

@test "configures SSH before reporting a token import failure" {
  install_op_mock
  install_gh_mock

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    MOCK_GH_LOGIN_FAILURE=1 "${REPO_ROOT}/tools/configure-gh.sh"

  [ "$status" -eq 1 ]
  grep -Fq 'config set git_protocol ssh --host github.com' \
    "${TEST_HOME}/gh-config-args"
  [[ "$output" == *"could not store the 1Password token"* ]]
  [[ "$output" == *"repo, read:org, and gist scopes"* ]]
}

@test "dry run does not read the token or change gh authentication" {
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
touch "${TEST_HOME}/op-called"
exit 99
EOF
  cat >"${MOCK_BIN}/gh" <<'EOF'
#!/usr/bin/env bash
touch "${TEST_HOME}/gh-called"
exit 99
EOF
  chmod +x "${MOCK_BIN}/op" "${MOCK_BIN}/gh"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    "${REPO_ROOT}/tools/configure-gh.sh" --dry-run

  [ "$status" -eq 0 ]
  [ ! -e "${TEST_HOME}/op-called" ]
  [ ! -e "${TEST_HOME}/gh-called" ]
  [[ "$output" == *"Would authenticate GitHub CLI for github.com"* ]]
}

@test "reports an actionable error when gh is unavailable" {
  install_op_mock

  run -127 env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    "${REPO_ROOT}/tools/configure-gh.sh"

  [ "$status" -eq 127 ]
  [[ "$output" == *"GitHub CLI 'gh' is required"* ]]
  [[ "$output" == *"make agent-install"* ]]
}

@test "reports an actionable error when 1Password cannot read the token" {
  install_gh_mock
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${MOCK_BIN}/op"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    "${REPO_ROOT}/tools/configure-gh.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"could not read op://Employee/github-token/credential"* ]]
  [[ "$output" == *"approve the 1Password prompt"* ]]
}

@test "fails when gh does not retain the 1Password token" {
  install_op_mock
  install_gh_mock

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" MOCK_GH_TOKEN_MISMATCH=1 \
    "${REPO_ROOT}/tools/configure-gh.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"stored token does not match"* ]]
}
