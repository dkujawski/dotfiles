#!/usr/bin/env bash
# Bash Utility Functions

# shellcheck source=/dev/null


# --------------------------------------------------------------------------------------
# Colors
# --------------------------------------------------------------------------------------
# Source: https://gist.github.com/daytonn/8677243

end="\033[0m"
black="\033[0;30m"
blackb="\033[1;30m"
white="\033[0;37m"
whiteb="\033[1;37m"
red="\033[0;31m"
redb="\033[1;31m"
green="\033[0;32m"
greenb="\033[1;32m"
yellow="\033[0;33m"
yellowb="\033[1;33m"
blue="\033[0;34m"
blueb="\033[1;34m"
purple="\033[0;35m"
purpleb="\033[1;35m"
lightblue="\033[0;36m"
lightblueb="\033[1;36m"

function black {
  echo -e "${black}${1}${end}"
}

function blackb {
  echo -e "${blackb}${1}${end}"
}

function white {
  echo -e "${white}${1}${end}"
}

function whiteb {
  echo -e "${whiteb}${1}${end}"
}

function red {
  echo -e "${red}${1}${end}"
}

function redb {
  echo -e "${redb}${1}${end}"
}

function green {
  echo -e "${green}${1}${end}"
}

function greenb {
  echo -e "${greenb}${1}${end}"
}

function yellow {
  echo -e "${yellow}${1}${end}"
}

function yellowb {
  echo -e "${yellowb}${1}${end}"
}

function blue {
  echo -e "${blue}${1}${end}"
}

function blueb {
  echo -e "${blueb}${1}${end}"
}

function purple {
  echo -e "${purple}${1}${end}"
}

function purpleb {
  echo -e "${purpleb}${1}${end}"
}

function lightblue {
  echo -e "${lightblue}${1}${end}"
}

function lightblueb {
  echo -e "${lightblueb}${1}${end}"
}

function colors {
  black "black"
  blackb "blackb"
  white "white"
  whiteb "whiteb"
  red "red"
  redb "redb"
  green "green"
  greenb "greenb"
  yellow "yellow"
  yellowb "yellowb"
  blue "blue"
  blueb "blueb"
  purple "purple"
  purpleb "purpleb"
  lightblue "lightblue"
  lightblueb "lightblueb"
}

function colortest {
  if [[ -n "$1" ]]; then
    T="$1"
  fi
  T='gYw'   # The test text

  echo -e "\n                 40m     41m     42m     43m\
       44m     45m     46m     47m";

  for FGs in '    m' '   1m' '  30m' '1;30m' '  31m' '1;31m' '  32m' \
             '1;32m' '  33m' '1;33m' '  34m' '1;34m' '  35m' '1;35m' \
             '  36m' '1;36m' '  37m' '1;37m';
    do FG=${FGs// /}
    echo -en " $FGs \033[$FG  $T  "
    for BG in 40m 41m 42m 43m 44m 45m 46m 47m;
      do echo -en "$EINS \033[$FG\033[$BG  $T  \033[0m";
    done
    echo;
  done
  echo
}

# --------------------------------------------------------------------------------------
# Output Functions
# --------------------------------------------------------------------------------------

function echo_action {
  echo -e "\n${blueb}==> ${whiteb}${1}${end}\n"
}

function echo_success {
  echo -e "${greenb}${1}${end}"
}

function echo_warning {
   echo -e "${yellowb}${1}${end}"
}

function echo_error {
  echo -e "${redb}${1}${end}"
}

# --------------------------------------------------------------------------------------
# Display Functions
# --------------------------------------------------------------------------------------

function display_install_status {
  local tool=$1
  local install_status=$2
  if [[ ${install_status} == 0 ]]; then
    echo_success "Installed ${tool}"
  else
    echo_error "Error installing ${tool}"
  fi
}


function display_update_status {
  local tool=$1
  local update_status=$2
  if [[ ${update_status} == 0 ]]; then
    echo_success "Updated ${tool}"
  else
    echo_error "Error updating ${tool}"
  fi
}


function display_verify_status {
  local tool=$1
  local verify_status=$2

  # Optional custom success and failure messages
  local success_message=$3
  local failure_message=$4

  if [[ ${verify_status} == 0 ]]; then
    if [[ -n ${success_message} ]]; then
      echo_success "${success_message}"
    else
      echo_success "${tool} verified"
    fi
  else
    if [[ -n ${success_message} ]]; then
      echo_error "${failure_message}"
    else
      echo_error "Error verifying ${tool}"
    fi
  fi
}

# --------------------------------------------------------------------------------------
# Test Commands
# --------------------------------------------------------------------------------------

function command_exists {
  command -v "${1}" 1>/dev/null 2>&1
}


# --------------------------------------------------------------------------------------
# Source Commands
# --------------------------------------------------------------------------------------

function source_file {
  if command -v sha256sum >/dev/null 2>&1; then
    [[ -r "${1}" ]] && run_with_spinner source "${1}"
  fi
  [[ -r "${1}" ]] && source "${1}"
}


# --------------------------------------------------------------------------------------
# PATH Commands
# --------------------------------------------------------------------------------------

function trim_path {
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH#:}"
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH%:}"
}

function path_append {
  trim_path
  if [[ -d "${1}" ]] && [[ ":$PATH:" != *":${1}:"* ]]; then
    PATH="${PATH:+"$PATH:"}${1}"
  fi
}

function path_prepend {
  trim_path
  if [[ -d "${1}" ]] && [[ ":$PATH:" != *":${1}:"* ]]; then
    PATH="${1}${PATH:+":$PATH"}"
  fi
}


# --------------------------------------------------------------------------------------
# PKG_CONFIG_PATH Commands
# --------------------------------------------------------------------------------------

function trim_pkg_config_path {
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH#:}"
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH%:}"
}

function pkg_config_path_append {
  trim_pkg_config_path
  if [[ -d "${1}" ]] && [[ ":$PKG_CONFIG_PATH:" != *":${1}:"* ]]; then
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH:+"$PKG_CONFIG_PATH:"}${1}"
  fi
}

function pkg_config_path_prepend {
  trim_pkg_config_path
  if [[ -d "${1}" ]] && [[ ":$PKG_CONFIG_PATH:" != *":${1}:"* ]]; then
    PKG_CONFIG_PATH="${1}${PKG_CONFIG_PATH:+":$PKG_CONFIG_PATH"}"
  fi
}

# --------------------------------------------------------------------------------------
# Progress Spinner
# --------------------------------------------------------------------------------------

# Run a command in the background and show the spinner
run_with_spinner() {
  tmp=$(echo -n "$@" | sha256sum | cut -d' ' -f1)
  cmd="$1"
  shift
  ( $cmd "$@" & echo $! > $tmp )
  until [[ -f $tmp ]]; do
    sleep 0.1
  done
  local pid=$(cat $tmp)
  rm $tmp
  spinner $pid
}

random_char() {
  local count=$1
  local start=$2
  local n=$((0 + $RANDOM % $count))
  get_char $start $n
}

get_char() {
  local start=$1
  local pos=$2
  local char=$(( $start + $pos ))
  printf "\\u$(printf '%x' $char)"
}

random_spinner() {
  local pid=$1

  while ps -p $pid > /dev/null 2>&1; do
    local spinstr=$(random_char 10 0xE38D)
    printf "\b${spinstr}"
    sleep 0.1
  done
  printf " \b\b"
}

clock_spinner() {
  local pid=$1
  local spinstr='🕛🕚🕙🕘🕗🕖🕕🕔'
  spinner $pid "$spinstr"
}

star_spinner() {
  local pid=$1
  local spinstr='⭐🌟✨'
  spinner $pid "$spinstr"
}

heart_spinner() {
  local pid=$1
  local spinstr='❤️💛💚💙💜'
  spinner $pid "$spinstr"
}

circle_spinner() {
  local pid=$1
  local spinstr='◐◓◑◒'
  spinner $pid "$spinstr"
}

line_spinner() {
  local pid=$1
  local spinstr='|/-\\'
  spinner $pid "$spinstr"
}

arrow_spinner() {
  local pid=$1
  local spinstr='←↑→↓'
  spinner $pid "$spinstr"
}

dot_spinner() {
  local pid=$1
  local spinstr='⠋⠙⠚⠒'
  spinner $pid "$spinstr"
}

dot_spinner2() {
  local pid=$1
  local spinstr='⠁⠂⠄⠃'
  spinner $pid "$spinstr"
}

moon_spinner() {
  local pid=$1
  local spinstr='🌑🌒🌓🌔🌕🌖🌗🌘'
  spinner $pid "$spinstr"
}

spinner() {
  local pid=$1
  local spinstr=$2
  if [[ -z $spinstr ]]; then
    spinstr='⠋⠙⠚⠒'
  fi
  local i=0

  while ps -p $pid > /dev/null 2>&1; do
    printf "\b${spinstr:i++%${#spinstr}:1}"
    sleep 0.1
  done
  printf " \b\b"
}

# --------------------------------------------------------------------------------------
# Source with Spinner
# --------------------------------------------------------------------------------------

function source_with_spinner {
  local file="$1"
  local message="${2:-Sourcing ${file}...}"
  
  if [[ ! -r "$file" ]]; then
    echo_error "Cannot read file: $file"
    return 1
  fi

  # Start the spinner in the background
  (
    local spinstr='⠋⠙⠚⠒⠂⠂⠒⠲⠴⠦⠖⠒⠐⠐⠒⠓⠋'
    local i=0
    while true; do
      printf "\r${blueb}${message}${end} ${spinstr:i++%${#spinstr}:1}"
      sleep 0.1
    done
  ) & local spinner_pid=$!

  # Source the file
  source "$file"
  local source_status=$?

  # Kill the spinner
  kill $spinner_pid 2>/dev/null
  wait $spinner_pid 2>/dev/null
  printf "\r\033[K" # Clear the line

  # Return the status of the source command
  return $source_status
}
