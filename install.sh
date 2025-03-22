#!/bin/bash -eu
set -u

# store if we're sourced or not in a variable
(return 0 2>/dev/null) && SOURCED=1 || SOURCED=0

abort() {
  printf "%s\n" "$@" >&2
  if [ "$SOURCED" == "1" ]; then
    return 1;
  fi
  exit 1;
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]
then
  abort "Cannot run force-interactive mode in CI."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]
then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# Check if script is run in POSIX mode
if [[ -n "${POSIXLY_CORRECT+1}" ]]
then
  abort 'Bash must not run in POSIX mode. Please unset POSIXLY_CORRECT and try again.'
fi

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

logTitleL1() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

usage() {
  cat <<EOS
Tray Installer
Usage: [NONINTERACTIVE=1] [CI=1] install.sh [options]
    -h, --help       Display this message.
    NONINTERACTIVE   Install without prompting for user input
    CI               Install in CI mode (e.g. do not prompt for user input)
EOS
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h | --help) usage ;;
    *)
      warn "Unrecognized option: '$1'"
      usage 1
      ;;
  esac
done

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -z "${NONINTERACTIVE-}" ]]
then
  if [[ -n "${CI-}" ]]
  then
    warn 'Running in non-interactive mode because `$CI` is set.'
    NONINTERACTIVE=1
  elif [[ ! -t 0 ]]
  then
    if [[ -z "${INTERACTIVE-}" ]]
    then
      warn 'Running in non-interactive mode because `stdin` is not a TTY.'
      NONINTERACTIVE=1
    else
      warn 'Running in interactive mode despite `stdin` not being a TTY because `$INTERACTIVE` is set.'
    fi
  fi
else
  logTitleL1 'Running in non-interactive mode because `$NONINTERACTIVE` is set.'
fi

# USER isn't always set so provide a fall back for the installer and subprocesses.
if [[ -z "${USER-}" ]]
then
  USER="$(chomp "$(id -un)")"
  export USER
fi

# First check OS.
OS="$(uname)"
if [[ "${OS}" == "Linux" ]]
then
  TRAY_ON_LINUX=1
elif [[ "${OS}" == "Darwin" ]]
then
  TRAY_ON_MACOS=1
elif [[ "${OS}" == MINGW* ]]
then
  TRAY_ON_MINGW=1
else
  abort "Tray is only supported on macOS and Linux."
fi

# shellcheck disable=SC2116
TRAY_HOME=$(echo ~/.tray)

execute() {
  if ! "$@"
  then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

retry() {
  local tries="$1" n="$1" pause=2
  shift
  if ! "$@"
  then
    while [[ $((--n)) -gt 0 ]]
    do
      warn "$(printf "Trying again in %d seconds: %s" "${pause}" "$(shell_join "$@")")"
      sleep "${pause}"
      ((pause *= 2))
      if "$@"
      then
        return
      fi
    done
    abort "$(printf "Failed %d times doing: %s" "${tries}" "$(shell_join "$@")")"
  fi
}

# TODO: bump version when new macOS is released or announced
MACOS_NEWEST_UNSUPPORTED="16.0"
# TODO: bump version when new macOS is released
MACOS_OLDEST_SUPPORTED="13.0"

# For Tray on Linux
REQUIRED_CURL_VERSION=7.41.0
REQUIRED_GIT_VERSION=2.7.0

# ---------------------------------------

major_minor() {
  echo "${1%%.*}.$(
    x="${1#*.}"
    echo "${x%%.*}"
  )"
}

version_gt() {
  [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -gt "${2#*.}" ]]
}
version_ge() {
  [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -ge "${2#*.}" ]]
}
version_lt() {
  [[ "${1%.*}" -lt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -lt "${2#*.}" ]]
}

check_run_command_as_root() {
  [[ "${EUID:-${UID}}" == "0" ]] || return

  # Allow Azure Pipelines/GitHub Actions/Docker/Concourse/Kubernetes to do everything as root (as it's normal there)
  [[ -f /.dockerenv ]] && return
  [[ -f /run/.containerenv ]] && return
  [[ -f /proc/1/cgroup ]] && grep -E "azpl_job|actions_job|docker|garden|kubepods" -q /proc/1/cgroup && return

  abort "Don't run this as root!"
}

test_curl() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  if [[ "$1" == "/snap/bin/curl" ]]
  then
    warn "Ignoring $1 (curl snap is too restricted)"
    return 1
  fi

  local curl_version_output curl_name_and_version
  curl_version_output="$("$1" --version 2>/dev/null)"
  curl_name_and_version="${curl_version_output%% (*}"
  version_ge "$(major_minor "${curl_name_and_version##* }")" "$(major_minor "${REQUIRED_CURL_VERSION}")"
}

test_git() {

  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  local git_version_output
  git_version_output="$("$1" --version 2>/dev/null)"
  if [[ "${git_version_output}" =~ "git version "([^ ]*).* ]]
  then
    version_ge "$(major_minor "${BASH_REMATCH[1]}")" "$(major_minor "${REQUIRED_GIT_VERSION}")"
  else
    abort "Unexpected Git version: '${git_version_output}'!"
  fi
}

# Search for the given executable in PATH (avoids a dependency on the `which` command)
which() {
  # Alias to Bash built-in command `type -P`
  type -P "$@"
}

# Search PATH for the specified program that satisfies Tray requirements
# function which is set above
# shellcheck disable=SC2230
find_tool() {
  if [[ $# -ne 1 ]]
  then
    return 1
  fi

  local executable
  while read -r executable
  do
    if [[ "${executable}" != /* ]]
    then
      warn "Ignoring ${executable} (relative paths don't work)"
    elif "test_$1" "${executable}"
    then
      echo "${executable}"
      break
    fi
  done < <(which -a "$1")
}

# -------

unset HAVE_SUDO_ACCESS # unset this from the environment

have_sudo_access() {
  if [[ ! -x "/usr/bin/sudo" ]]
  then
    return 1
  fi

  local -a SUDO=("/usr/bin/sudo")
  if [[ -n "${SUDO_ASKPASS-}" ]]
  then
    SUDO+=("-A")
  elif [[ -n "${NONINTERACTIVE-}" ]]
  then
    SUDO+=("-n")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]
  then
    if [[ -n "${NONINTERACTIVE-}" ]]
    then
      "${SUDO[@]}" -l mkdir &>/dev/null
    else
      "${SUDO[@]}" -v && "${SUDO[@]}" -l mkdir &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -n "${TRAY_ON_MACOS-}" ]] && [[ "${HAVE_SUDO_ACCESS}" -ne 0 ]]
  then
    abort "Need sudo access on macOS (e.g. the user ${USER} needs to be an Administrator)!"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

# shellcheck disable=SC2016
# logTitleL1 'Checking for `sudo` access (which may request your password)...'
: '
if [[ -n "${TRAY_ON_MACOS-}" ]]
then
  [[ "${EUID:-${UID}}" == "0" ]] || have_sudo_access
elif ! [[ -w "${TRAY_HOME}" ]] &&
     ! [[ -w "/home" ]] &&
     ! have_sudo_access
then
  abort "$(
    cat <<EOABORT
Insufficient permissions to install Tray to "${TRAY_HOME}" (the default prefix).
EOABORT
  )"
fi
'

# check_run_command_as_root

if [[ -d "${TRAY_HOME}" && ! -x "${TRAY_HOME}" ]]
then
  abort "The Tray home ${tty_underline}${TRAY_HOME}${tty_reset} exists but is not searchable. Use sudo chmod 775 ${TRAY_HOME}"
fi

if [[ -n "${TRAY_ON_MACOS-}" ]]
then
  macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"
  if version_lt "${macos_version}" "10.7"
  then
    abort "$(
      cat <<EOABORT
Your Mac OS X version is too old. See:
  ${tty_underline}https://githu...${tty_reset}
EOABORT
    )"
  elif version_lt "${macos_version}" "10.11"
  then
    abort "Your OS X version is too old."
  elif version_ge "${macos_version}" "${MACOS_NEWEST_UNSUPPORTED}" ||
       version_lt "${macos_version}" "${MACOS_OLDEST_SUPPORTED}"
  then
    who="We"
    what=""
    if version_ge "${macos_version}" "${MACOS_NEWEST_UNSUPPORTED}"
    then
      what="pre-release version"
    else
      who+=" (and Apple)"
      what="old version"
    fi
    logTitleL1 "You are using macOS ${macos_version}."
    logTitleL1 "${who} do not provide support for this ${what}."

    echo "$(
      cat <<EOS
This installation may not succeed.
EOS
    )
" | tr -d "\\"
  fi
fi

USABLE_GIT=/usr/bin/git
if [[ -n "${TRAY_ON_LINUX-}" || -n "${TRAY_ON_MINGW-}" ]]
then
  USABLE_GIT="$(find_tool git)"
  if [[ -z "$(command -v git)" ]]
  then
    abort "You must install Git before installing Tray."
  fi
  if [[ -z "${USABLE_GIT}" ]]
  then
    abort "The version of Git that was found does not satisfy requirements for Tray."
  fi
  if [[ "${USABLE_GIT}" != /usr/bin/git ]]
  then
    export TRAY_GIT_PATH="${USABLE_GIT}"
    logTitleL1 "Found Git: ${TRAY_GIT_PATH}"
  fi
fi

if ! command -v curl >/dev/null
then
  abort "You must install cURL before installing Tray."
elif [[ -n "${TRAY_ON_LINUX-}" || -n "${TRAY_ON_MINGW-}" ]]
then
  USABLE_CURL="$(find_tool curl)"
  if [[ -z "${USABLE_CURL}" ]]
  then
    abort "The version of cURL that was found does not satisfy requirements for Tray."
  elif [[ "${USABLE_CURL}" != /usr/bin/curl ]]
  then
    export TRAY_CURL_PATH="${USABLE_CURL}"
    logTitleL1 "Found cURL: ${TRAY_CURL_PATH}"
  fi
fi

if [[ -n "${JAVA_HOME-}" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
  # USABLE_JAVA=${JAVA_HOME}/bin/java
  # execute "$USABLE_JAVA" -version
  # There is java - now lets check if its a JDK...


  USABLE_JAVA=${JAVA_HOME}/bin/java
  USABLE_JAVAC=${JAVA_HOME}/bin/javac
  if [[ ! -f ${USABLE_JAVAC} ]]; then
    abort "JAVA_HOME is set to JRE. But JDK is required"
  fi
  JAVA_VER=$($USABLE_JAVA -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{sub("^$", "0", $2); print $1$2}')
  if [ ! "$JAVA_VER" -ge 170 ]; then
    abort "Minimum JDK is 17!"
  fi
  logTitleL1 "Found JDK at ${JAVA_HOME}, version: $(awk -v var1="$JAVA_VER" -v var2=10 'BEGIN { print  ( var1 / var2 ) }')"
else
  abort "JAVA_HOME is not set. JDK is Required"
fi

USABLE_GRADLE=./gradlew
USABLE_PATHS_LOCAL_BIN="/usr/local/bin"
# shellcheck disable=SC2116
USABLE_PATHS_HOME_BIN=$(echo ~/bin)

# $ if [ "/c/Users/THINKPAD/.tray" == "$(echo ~/.tray)" ]; then echo "Equal"; else echo "NotEqual";  fi
# >Equal

if [[ -n ${TRAY_ON_MINGW-} ]]; then
  LOCAL_APPS_PATH=$USABLE_PATHS_HOME_BIN
else
  LOCAL_APPS_PATH=$USABLE_PATHS_LOCAL_BIN
fi

logTitleL1 "Your bin paths:"
IN="$PATH"
mails=$(echo "$IN" | tr ":" " ")
for addr in $mails
do
    if [[ $addr == */bin* ]]; then
      echo -"[$addr]"
    fi
done

logTitleL1 "This script will install:"
echo "${TRAY_HOME}/repository/"
echo "${TRAY_HOME}/bin/tray"
echo "${LOCAL_APPS_PATH}/tray -> ${TRAY_HOME}/bin/tray"

currentDir=$(pwd)
{
    logTitleL1 "Installing tray..."
    mkdir -p "${TRAY_HOME}"
    cd "${TRAY_HOME}"
    if [ ! -d repository ]; then
      mkdir repository
      logTitleL1 "Downloading tray sources..."
      execute "${USABLE_GIT}" clone https://github.com/andreyzebin/audio-connect-tray.git repository
    fi
    cd repository
    logTitleL1 "Updating tray sources..."
    execute "${USABLE_GIT}" pull

    logTitleL1 "Testing if sources buildable..."
    execute "${USABLE_GRADLE}" clean build

    cp -rf bin "${TRAY_HOME}"/
    chmod u+x "${TRAY_HOME}"/bin/tray

    if [ -f "${LOCAL_APPS_PATH}"/tray ]; then
      if [ ! "$(readlink "${LOCAL_APPS_PATH}"/tray)" == "${TRAY_HOME}"/bin/tray ]; then
        ln -s "${TRAY_HOME}"/bin/tray "${LOCAL_APPS_PATH}"/tray
      fi
    else
      mkdir -p "${LOCAL_APPS_PATH}"
      ln -s "${TRAY_HOME}"/bin/tray "${LOCAL_APPS_PATH}"/tray
    fi

    logTitleL1 "Checking installation result..."
    logTitleL1 "Executing: 'tray --version'..."
    tray --version
} || {
    cd "$currentDir"
    abort "Installation failed!"
}
cd "$currentDir"
logTitleL1 "Installation successful!"

# export JAVA_HOME=/c/Users/THINKPAD/.gradle/jdks/eclipse_adoptium-17-amd64-windows.2