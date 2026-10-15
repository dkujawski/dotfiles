#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0
  unset BASH_ENV DOTFILES_AGENT_PROFILE_LOADED DOTFILES_CONFIG_DIR \
    DOTFILES_HOMEBREW_PREFIX DOTFILES_HUMAN_PROFILE DOTFILES_OP_SSH_AUTH_SOCK \
    DOTFILES_PROFILE DOTFILES_PROFILE_LOADED DOTFILES_SECRETS_FILE \
    DOTFILES_SECRETS_HELPERS_LOADED
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/home.XXXXXX")"
  MOCK_BIN="$(mktemp -d "${BATS_TEST_TMPDIR}/bin.XXXXXX")"
  DOTFILES_CONFIG_DIR="${TEST_HOME}/.config/dotfiles"
  # Keep Homebrew promotion from shadowing MOCK_BIN unless a test opts in.
  DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew"
  export REPO_ROOT TEST_HOME MOCK_BIN DOTFILES_CONFIG_DIR DOTFILES_HOMEBREW_PREFIX
  mkdir -p "${TEST_HOME}/.config/dotfiles/profiles" "${TEST_HOME}/.config/dotfiles/secrets"
  cp "${REPO_ROOT}/home/.bash_profile" "${TEST_HOME}/.bash_profile"
  cp "${REPO_ROOT}/home/.bashrc" "${TEST_HOME}/.bashrc"
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

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
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

@test "nested shell reloads the agent profile instead of inheriting its guard" {
  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; PAGER=less; bash --noprofile --norc -c '\''source "$HOME/.bash_profile"; type _dotfiles_with_secrets >/dev/null; printf "%s|%s|helpers" "$DOTFILES_PROFILE" "$PAGER"'\'''

  [ "$status" -eq 0 ]
  [ "$output" = "agent|cat|helpers" ]
}

@test "nested shell reloads the agent profile through bashrc" {
  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; PAGER=less; bash --noprofile --norc -c '\''source "$HOME/.bashrc"; printf "%s|%s" "$DOTFILES_PROFILE" "$PAGER"'\'''

  [ "$status" -eq 0 ]
  [ "$output" = "agent|cat" ]
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

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
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

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-agent-secrets; printf "%s" "$GITHUB_TOKEN"'

  [ "$status" -eq 0 ]
  [ "$output" = "value for op://Employee/github-token/credential" ]
}

@test "secret helper fails with an actionable error when op is unavailable" {
  run -127 env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; with-agent-secrets -- true'

  [ "$status" -ne 0 ]
  [[ "$output" == *"1Password CLI 'op' is required"* ]]
}

@test "load-human-profile skips signin when op is already authenticated" {
  cat >"${TEST_HOME}/human-test.bash" <<'EOF'
export HUMAN_PROFILE_LOADED=1
alias human-only='true'
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${OP_CALLED_FILE}"
[[ "$1" == "whoami" ]]
EOF
  chmod +x "${MOCK_BIN}/op"
  export OP_CALLED_FILE="${TEST_HOME}/op-called"

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
    OP_CALLED_FILE="${OP_CALLED_FILE}" DOTFILES_HUMAN_PROFILE="${TEST_HOME}/human-test.bash" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-profile; alias human-only; printf "|%s|%s" "$DOTFILES_PROFILE" "$HUMAN_PROFILE_LOADED"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"alias human-only='true'"* ]]
  [[ "$output" == *"|human|1"* ]]
  [ "$(<"${OP_CALLED_FILE}")" = "whoami" ]
}

@test "load-human-profile signs in before loading when authentication is required" {
  cat >"${TEST_HOME}/human-test.bash" <<'EOF'
export HUMAN_PROFILE_LOADED=1
alias human-only='true'
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  whoami) [[ -e "${OP_SIGNED_IN_FILE}" ]] ;;
  signin) touch "${OP_SIGNED_IN_FILE}" ;;
  *) exit 90 ;;
esac
EOF
  chmod +x "${MOCK_BIN}/op"
  export OP_SIGNED_IN_FILE="${TEST_HOME}/op-signed-in"

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
    OP_SIGNED_IN_FILE="${OP_SIGNED_IN_FILE}" \
    DOTFILES_HUMAN_PROFILE="${TEST_HOME}/human-test.bash" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-profile; alias human-only; printf "|%s|%s" "$DOTFILES_PROFILE" "$HUMAN_PROFILE_LOADED"'

  [ "$status" -eq 0 ]
  [ -e "${OP_SIGNED_IN_FILE}" ]
  [[ "$output" == *"Signing in to 1Password CLI"* ]]
  [[ "$output" == *"alias human-only='true'"* ]]
  [[ "$output" == *"|human|1"* ]]
}

@test "load-human-profile fails before loading when op is unavailable" {
  cat >"${TEST_HOME}/human-test.bash" <<'EOF'
export HUMAN_PROFILE_LOADED=1
EOF

  run -127 env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    DOTFILES_HUMAN_PROFILE="${TEST_HOME}/human-test.bash" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-profile; status=$?; printf "|%s|%s" "$DOTFILES_PROFILE" "${HUMAN_PROFILE_LOADED:-unset}"; exit "$status"'

  [ "$status" -eq 127 ]
  [[ "$output" == *"1Password CLI 'op' is required"* ]]
  [[ "$output" == *"|agent|unset"* ]]
}

@test "load-human-profile fails before loading when op signin fails" {
  cat >"${TEST_HOME}/human-test.bash" <<'EOF'
export HUMAN_PROFILE_LOADED=1
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${OP_CALLED_FILE}"
exit 1
EOF
  chmod +x "${MOCK_BIN}/op"
  export OP_CALLED_FILE="${TEST_HOME}/op-called"

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
    OP_CALLED_FILE="${OP_CALLED_FILE}" \
    DOTFILES_HUMAN_PROFILE="${TEST_HOME}/human-test.bash" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-profile; status=$?; printf "|%s|%s" "$DOTFILES_PROFILE" "${HUMAN_PROFILE_LOADED:-unset}"; exit "$status"'

  [ "$status" -eq 1 ]
  [ "$(<"${OP_CALLED_FILE}")" = $'whoami\nsignin' ]
  [[ "$output" == *"1Password CLI sign-in failed"* ]]
  [[ "$output" == *"|agent|unset"* ]]
}

@test "load-human-profile verifies authentication after op signin" {
  cat >"${TEST_HOME}/human-test.bash" <<'EOF'
export HUMAN_PROFILE_LOADED=1
EOF
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${OP_CALLED_FILE}"
[[ "$1" == signin ]]
EOF
  chmod +x "${MOCK_BIN}/op"
  export OP_CALLED_FILE="${TEST_HOME}/op-called"

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
    OP_CALLED_FILE="${OP_CALLED_FILE}" \
    DOTFILES_HUMAN_PROFILE="${TEST_HOME}/human-test.bash" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; load-human-profile; status=$?; printf "|%s|%s" "$DOTFILES_PROFILE" "${HUMAN_PROFILE_LOADED:-unset}"; exit "$status"'

  [ "$status" -eq 1 ]
  [ "$(<"${OP_CALLED_FILE}")" = $'whoami\nsignin\nwhoami' ]
  [[ "$output" == *"could not be verified after sign-in"* ]]
  [[ "$output" == *"|agent|unset"* ]]
}

@test "agent profile puts pyenv on PATH without invoking it" {
  mkdir -p "${TEST_HOME}/.pyenv/bin" "${TEST_HOME}/.pyenv/shims"
  cat >"${TEST_HOME}/.pyenv/bin/pyenv" <<EOF
#!/usr/bin/env bash
touch "${TEST_HOME}/pyenv-called"
EOF
  chmod +x "${TEST_HOME}/.pyenv/bin/pyenv"

  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; printf "%s|%s" "$PYENV_ROOT" "$PATH"'

  [ "$status" -eq 0 ]
  [[ "$output" == "${TEST_HOME}/.pyenv|"* ]]
  [[ "$output" == *"${TEST_HOME}/.pyenv/bin"* ]]
  [[ "$output" == *"${TEST_HOME}/.pyenv/shims"* ]]
  [ ! -e "${TEST_HOME}/pyenv-called" ]
}

@test "versioned SSH fragment selects the 1Password agent" {
  run grep -F 'IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"' \
    "${REPO_ROOT}/home/.ssh/config.d/1password.conf"

  [ "$status" -eq 0 ]
}

@test "agent PATH promotes Homebrew ahead of inherited /usr/bin" {
  mkdir -p "${TEST_HOME}/hb/bin" "${TEST_HOME}/usr/bin"
  printf '#!/bin/sh\necho brew-git\n' >"${TEST_HOME}/hb/bin/git"
  printf '#!/bin/sh\necho system-git\n' >"${TEST_HOME}/usr/bin/git"
  chmod +x "${TEST_HOME}/hb/bin/git" "${TEST_HOME}/usr/bin/git"

  run env HOME="${TEST_HOME}" PATH="${TEST_HOME}/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/hb" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; command -v git; git'

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "${TEST_HOME}/hb/bin/git" ]
  [ "${lines[1]}" = "brew-git" ]
}

@test "agent PATH promotes gnubin ahead of Homebrew bin" {
  mkdir -p "${TEST_HOME}/hb/bin" \
    "${TEST_HOME}/hb/opt/gnu-sed/libexec/gnubin"
  printf '#!/bin/sh\necho brew-sed\n' >"${TEST_HOME}/hb/bin/sed"
  printf '#!/bin/sh\necho gnu-sed\n' \
    >"${TEST_HOME}/hb/opt/gnu-sed/libexec/gnubin/sed"
  chmod +x "${TEST_HOME}/hb/bin/sed" \
    "${TEST_HOME}/hb/opt/gnu-sed/libexec/gnubin/sed"

  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/hb" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; command -v sed; sed'

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "${TEST_HOME}/hb/opt/gnu-sed/libexec/gnubin/sed" ]
  [ "${lines[1]}" = "gnu-sed" ]
}

@test "agent PATH drops empty, current-directory, and duplicate entries" {
  mkdir -p "${TEST_HOME}/hb/bin" "${TEST_HOME}/.local/bin"

  run env HOME="${TEST_HOME}" \
    PATH="${TEST_HOME}/hb/bin::.:/usr/bin:${TEST_HOME}/hb/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/hb" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"; source "$HOME/.config/dotfiles/profiles/agent.bash"
     printf "%s\n" "$PATH"
     case ":$PATH:" in *::*) exit 10 ;; esac
     case ":$PATH:" in *":.:"*) exit 11 ;; esac
     count=0
     while IFS= read -r -d: entry; do
       [[ "$entry" == "$HOME/.local/bin" ]] && count=$((count + 1))
     done <<<"${PATH}:"
     [[ "$count" -eq 1 ]] || exit 12'

  [ "$status" -eq 0 ]
  [[ "$output" == "${TEST_HOME}/.local/bin:"* ]]
  [[ "$output" == *"${TEST_HOME}/hb/bin"* ]]
}

@test "agent.bash is safe to source standalone and exports BASH_ENV" {
  run env -u DOTFILES_CONFIG_DIR -u DOTFILES_PROFILE -u BASH_ENV \
    HOME="${TEST_HOME}" PATH="/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.config/dotfiles/profiles/agent.bash"
     printf "%s|%s|%s|%s" "$DOTFILES_PROFILE" "$PAGER" "$BASH_ENV" "$DOTFILES_CONFIG_DIR"'

  [ "$status" -eq 0 ]
  [ "$output" = "agent|cat|${TEST_HOME}/.config/dotfiles/profiles/agent.bash|${TEST_HOME}/.config/dotfiles" ]
}

@test "BASH_ENV propagates agent environment to a nested bash -c" {
  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"
     bash --noprofile --norc -c '\''printf "%s|%s|%s" "$DOTFILES_PROFILE" "$PAGER" "$GIT_TERMINAL_PROMPT"'\'''

  [ "$status" -eq 0 ]
  [ "$output" = "agent|cat|0" ]
}

@test "agent hygiene defaults are set for noninteractive automation" {
  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${TEST_HOME}/missing-homebrew" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"
     printf "%s|%s|%s|%s|%s|%s|%s|%s" \
       "$EDITOR" "$VISUAL" "$HISTFILE" "$HISTSIZE" \
       "$NO_COLOR" "$CLICOLOR" "$GIT_ASKPASS" "$SSH_ASKPASS_REQUIRE"'

  [ "$status" -eq 0 ]
  [ "$output" = "true|true|/dev/null|0|1|0|true|never" ]
}

@test "load-human-profile resets agent automation defaults" {
  local module
  mkdir -p "${TEST_HOME}/.local/share/bash"
  for module in paths exports aliases functions git-functions; do
    printf '# test module\n' >"${TEST_HOME}/.local/share/bash/${module}.sh"
  done
  cat >"${TEST_HOME}/.local/share/bash/utility-functions.sh" <<'EOF'
path_prepend() { PATH="$1:${PATH}"; }
path_append() { PATH="${PATH}:$1"; }
EOF
  printf 'export EDITOR=vim\n' >"${TEST_HOME}/.local/share/bash/exports.sh"
  printf '# test prompt\n' >"${TEST_HOME}/.bash_prompt"
  cat >"${MOCK_BIN}/op" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "whoami" ]]
EOF
  chmod +x "${MOCK_BIN}/op"

  run env -u BASH_ENV -u DOTFILES_SECRETS_FILE \
    HOME="${TEST_HOME}" PATH="${MOCK_BIN}:/usr/bin:/bin" \
    DOTFILES_HOMEBREW_PREFIX="${DOTFILES_HOMEBREW_PREFIX}" \
    DOTFILES_HUMAN_PROFILE="${TEST_HOME}/.config/dotfiles/profiles/human.bash" \
    /opt/homebrew/bin/bash --noprofile --norc -c \
    'source "$HOME/.bash_profile"
     printf "before:%s|%s\n" "$PAGER" "${GIT_EDITOR:-unset}"
     load-human-profile
     printf "after:%s|%s|%s|%s|%s|%s" \
       "$PAGER" "${GIT_EDITOR:-unset}" "${BASH_ENV:-unset}" \
       "${HISTFILE:-unset}" "${NO_COLOR:-unset}" "$EDITOR"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"before:cat|true"* ]]
  [[ "$output" == *"after:less|unset|unset|unset|unset|vim"* ]]
}
