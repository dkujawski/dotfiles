#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/deploy-home.XXXXXX")"
  export REPO_ROOT TEST_HOME
}

teardown() {
  rm -rf "${TEST_HOME}"
}

@test "agent deployment dry-run makes no changes" {
  run "${REPO_ROOT}/tools/deploy-agent.sh" --dry-run --home "${TEST_HOME}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Would install"* ]]
  [ -z "$(find "${TEST_HOME}" -mindepth 1 -print -quit)" ]
}

@test "agent deployment backs up startup files and preserves SSH config" {
  mkdir -p "${TEST_HOME}/.ssh"
  printf 'old profile\n' >"${TEST_HOME}/.bash_profile"
  printf 'Host existing\n    HostName example.test\n' >"${TEST_HOME}/.ssh/config"

  run "${REPO_ROOT}/tools/deploy-agent.sh" --home "${TEST_HOME}"

  [ "$status" -eq 0 ]
  cmp -s "${REPO_ROOT}/home/.bash_profile" "${TEST_HOME}/.bash_profile"
  grep -Fq 'Host existing' "${TEST_HOME}/.ssh/config"
  grep -Fq 'Include ~/.ssh/config.d/*' "${TEST_HOME}/.ssh/config"
  [ -f "$(find "${TEST_HOME}/.local/state/dotfiles/backups" -name .bash_profile -print -quit)" ]
}

@test "agent deployment is idempotent and adds one SSH include" {
  mkdir -p "${TEST_HOME}/.ssh"
  printf 'Host existing\n    HostName example.test\n' >"${TEST_HOME}/.ssh/config"

  "${REPO_ROOT}/tools/deploy-agent.sh" --home "${TEST_HOME}"
  run "${REPO_ROOT}/tools/deploy-agent.sh" --home "${TEST_HOME}"

  [ "$status" -eq 0 ]
  [ "$(grep -Fc 'Include ~/.ssh/config.d/*' "${TEST_HOME}/.ssh/config")" -eq 1 ]
  [[ "$output" == *"already current"* ]]
}

@test "human deployment installs legacy modules but keeps agent dispatcher" {
  run "${REPO_ROOT}/tools/deploy-agent.sh" --profile human --home "${TEST_HOME}"

  [ "$status" -eq 0 ]
  [ -f "${TEST_HOME}/.local/share/bash/aliases.sh" ]
  [ -f "${TEST_HOME}/.bash_prompt" ]
  grep -Fq 'DOTFILES_PROFILE:-agent' "${TEST_HOME}/.bash_profile"
}

@test "deployment removes legacy plaintext secret caches and loaders" {
  mkdir -p "${TEST_HOME}/.cache/op-secrets-secure" \
    "${TEST_HOME}/.cache/op-secrets-macos" "${TEST_HOME}/.local/bin"
  printf 'export TOKEN=plaintext\n' >"${TEST_HOME}/.cache/op-secrets-secure/secrets.cache"
  printf 'export TOKEN=plaintext\n' >"${TEST_HOME}/.cache/op-secrets-macos/secrets.cache"
  touch "${TEST_HOME}/.local/bin/load-secrets-secure.sh" \
    "${TEST_HOME}/.local/bin/load-secrets-macos.sh" \
    "${TEST_HOME}/.local/bin/secrets-config.sh"

  run "${REPO_ROOT}/tools/deploy-agent.sh" --home "${TEST_HOME}"

  [ "$status" -eq 0 ]
  [ ! -e "${TEST_HOME}/.cache/op-secrets-secure" ]
  [ ! -e "${TEST_HOME}/.cache/op-secrets-macos" ]
  [ ! -e "${TEST_HOME}/.local/bin/load-secrets-secure.sh" ]
  [ ! -e "${TEST_HOME}/.local/bin/load-secrets-macos.sh" ]
  [ ! -e "${TEST_HOME}/.local/bin/secrets-config.sh" ]
}

@test "deployment dry-run preserves legacy secret artifacts" {
  mkdir -p "${TEST_HOME}/.cache/op-secrets-secure"
  printf 'export TOKEN=plaintext\n' >"${TEST_HOME}/.cache/op-secrets-secure/secrets.cache"

  run "${REPO_ROOT}/tools/deploy-agent.sh" --dry-run --home "${TEST_HOME}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Would remove legacy secret artifact"* ]]
  [ -f "${TEST_HOME}/.cache/op-secrets-secure/secrets.cache" ]
}

@test "agent doctor gives an actionable error for an undeployed profile" {
  run env HOME="${TEST_HOME}" PATH="${PATH}" "${REPO_ROOT}/tools/agent-doctor.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"agent profile is missing; run 'make agent-deploy'"* ]]
}
