#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/latency-home.XXXXXX")"
  MOCK_BIN="$(mktemp -d "${BATS_TEST_TMPDIR}/latency-bin.XXXXXX")"
  export REPO_ROOT TEST_HOME MOCK_BIN
}

teardown() {
  rm -rf "${TEST_HOME}" "${MOCK_BIN}"
}

@test "human startup defers secrets runtimes and completion" {
  local module
  mkdir -p "${TEST_HOME}/.local/share/bash" "${TEST_HOME}/.nvm" \
    "${TEST_HOME}/.pyenv/bin" "${TEST_HOME}/.pyenv/shims" \
    "${TEST_HOME}/homebrew/etc/profile.d"

  for module in paths exports aliases functions git-functions; do
    printf '# test module\n' >"${TEST_HOME}/.local/share/bash/${module}.sh"
  done
  cat >"${TEST_HOME}/.local/share/bash/utility-functions.sh" <<'EOF'
path_prepend() { PATH="$1:${PATH}"; }
EOF
  cat >"${TEST_HOME}/.local/share/bash/load-secrets.sh" <<EOF
load-secrets() { touch "${TEST_HOME}/secrets-loaded"; }
EOF
  cat >"${TEST_HOME}/.nvm/nvm.sh" <<EOF
touch "${TEST_HOME}/nvm-loaded"
nvm() { :; }
EOF
  cat >"${TEST_HOME}/homebrew/etc/profile.d/bash_completion.sh" <<EOF
touch "${TEST_HOME}/completion-loaded"
_completion_loader() { :; }
EOF
  printf '# test prompt\n' >"${TEST_HOME}/.bash_prompt"
  cat >"${TEST_HOME}/.pyenv/bin/pyenv" <<EOF
#!/usr/bin/env bash
touch "${TEST_HOME}/pyenv-called"
EOF
  chmod +x "${TEST_HOME}/.pyenv/bin/pyenv"

  run env -u DOTFILES_PROFILE_LOADED -u DOTFILES_HUMAN_PROFILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    HOMEBREW_PREFIX="${TEST_HOME}/homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$REPO_ROOT/home/.config/dotfiles/profiles/human.bash"
     [[ ! -e "$HOME/secrets-loaded" && ! -e "$HOME/nvm-loaded" &&
        ! -e "$HOME/completion-loaded" && ! -e "$HOME/pyenv-called" ]] &&
       touch "$HOME/startup-deferred"
     nvm --version
     _dotfiles_load_completion test-command'

  [ "$status" -eq 0 ]
  [ -e "${TEST_HOME}/startup-deferred" ]
  [ ! -e "${TEST_HOME}/secrets-loaded" ]
  [ -e "${TEST_HOME}/nvm-loaded" ]
  [ -e "${TEST_HOME}/completion-loaded" ]
  [ ! -e "${TEST_HOME}/pyenv-called" ]
}

@test "prompt renders Git state with at most two Git processes" {
  cat >"${MOCK_BIN}/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GIT_CALL_LOG}"
case "$*" in
  'status --porcelain=v2 --branch --ignore-submodules')
    printf '%s\n' '# branch.oid 0123456789abcdef' '# branch.head feature/fast-prompt' \
      '# branch.upstream origin/feature/fast-prompt' '# branch.ab +2 -1' \
      '1 .M N... 100644 100644 100644 abcdef abcdef tracked-file'
    ;;
  'rev-parse --show-toplevel --show-prefix')
    printf '%s\n' '/tmp/project' 'nested/'
    ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/git"
  export GIT_CALL_LOG="${TEST_HOME}/git-calls"

  run env PATH="${MOCK_BIN}:/usr/bin:/bin" TERM=dumb TERM_PROGRAM=iTerm.app \
    GIT_CALL_LOG="${GIT_CALL_LOG}" /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$REPO_ROOT/home/.bash_prompt"; __prompt_render 7'

  [ "$status" -eq 0 ]
  [[ "$output" == *"git: feature/fast-prompt"* ]]
  [[ "$output" == *"* !"* ]]
  [[ "$output" == *"nested/"* ]]
  [[ "$output" == *"!7"* ]]
  [ "$(wc -l <"${GIT_CALL_LOG}")" -le 2 ]
}

@test "prompt uses one renderer so command status is preserved" {
  run grep -Fq '__prompt_render $?' "${REPO_ROOT}/home/.bash_prompt"

  [ "$status" -eq 0 ]
}
