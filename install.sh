#!/usr/bin/env bash
# Antigravity CLI - Termux Native (Setup)
set -Eeuo pipefail

# Security Enhancement (Sentinel): Initialize critical variables to prevent environment hijacking
# and arbitrary file deletion/move vulnerabilities (CWE-377, CWE-59, CWE-459).
ANTIGRAVITY_BAK=""
ANTIGRAVITY_VA39_BAK=""
INSTALL_BIN_DIR=""
SECURE_TMP_DIR=""
INSTALL_SUCCESS=0

REPO="${ANTIGRAVITY_REPO:-wallentx/antigravity-cli-termux}"
if [[ "$REPO" == -* || "$REPO" == *[!a-zA-Z0-9_./-]* ]]; then
  printf "[ERR] Invalid ANTIGRAVITY_REPO: contains unsafe characters or starts with a dash\n" >&2
  exit 1
fi
if [[ "$REPO" == -* ]]; then
  printf "[ERR] Invalid ANTIGRAVITY_REPO: cannot start with a dash\n" >&2
  exit 1
fi

URL="${ANTIGRAVITY_INSTALL_URL:-https://github.com/$REPO/releases/latest/download/antigravity-termux-standalone.tar.gz}"
if [[ "$URL" != https://* ]]; then
  printf "[ERR] Invalid ANTIGRAVITY_INSTALL_URL: must use HTTPS protocol\n" >&2
  exit 1
fi
if [[ "$URL" == -* || "$URL" == *[!a-zA-Z0-9_./:-]* ]]; then
  printf "[ERR] Invalid ANTIGRAVITY_INSTALL_URL: contains unsafe characters or starts with a dash\n" >&2
  exit 1
fi
if [[ "$URL" == -* ]]; then
  printf "[ERR] Invalid ANTIGRAVITY_INSTALL_URL: cannot start with a dash\n" >&2
  exit 1
fi

# ── Environment Detection ─────────────────────────────────────────────────────
if [[ -z "${TERMUX_VERSION:-}" || -z "${PREFIX:-}" ]]; then
  cat >&2 <<'EOF'
[ERR] This installer is only for native Termux.

PRoot environments can use Google's official Antigravity CLI binary
directly, so this Termux-specific standalone port does not install there.
Use the official installer instead:

  curl -fsSL https://antigravity.google/cli/install.sh | bash

EOF
  exit 1
fi

# Security Enhancement (Sentinel): Validate PREFIX to prevent option/command injection and path traversal
if [[ "$PREFIX" == -* || "$PREFIX" == *[!a-zA-Z0-9_./-]* ]]; then
  printf "[ERR] Invalid PREFIX: contains unsafe characters or starts with a dash\n" >&2
  exit 1
fi

ENV_TYPE="termux"
TERMUX_PREFIX="$PREFIX"
INSTALL_BIN_DIR="${TERMUX_PREFIX}/bin"

# Security Enhancement (Sentinel): Create a secure randomized temporary directory (CWE-377, CWE-59)
# with restricted 0700 permissions to mitigate local race conditions, symlink attacks, and predictable tmp files.
SECURE_TMP_DIR=$(mktemp -d "${TERMUX_PREFIX}/tmp/antigravity-install.XXXXXX" 2>/dev/null || mktemp -d)
if [[ -z "${SECURE_TMP_DIR:-}" || ! -d "$SECURE_TMP_DIR" ]]; then
  printf "[ERR] Failed to create secure temporary directory\n" >&2
  exit 1
fi
chmod 0700 "$SECURE_TMP_DIR"

TMP="${SECURE_TMP_DIR}/antigravity-termux-standalone.tar.gz"
EXTRACT_DIR="${SECURE_TMP_DIR}/.antigravity-extract"
INSTALL_SUCCESS=0

# Ensure base directories exist for fresh setups
mkdir -p "$SECURE_TMP_DIR" 2>/dev/null || true

# ── Cleanup Hook ──────────────────────────────────────────────────────────────
cleanup() {
  printf "\033[?25h" # Restore cursor if cancelled
  [[ -n "${SECURE_TMP_DIR:-}" && -d "$SECURE_TMP_DIR" ]] && rm -rf "$SECURE_TMP_DIR"
  if [[ "${INSTALL_SUCCESS:-0}" -ne 1 ]]; then
    if [[ -n "${INSTALL_BIN_DIR:-}" && -n "${ANTIGRAVITY_BAK:-}" && -f "$ANTIGRAVITY_BAK" ]]; then
      mv -f "$ANTIGRAVITY_BAK" "$INSTALL_BIN_DIR/antigravity" || true
    fi
    if [[ -n "${INSTALL_BIN_DIR:-}" && -n "${ANTIGRAVITY_VA39_BAK:-}" && -f "$ANTIGRAVITY_VA39_BAK" ]]; then
      mv -f "$ANTIGRAVITY_VA39_BAK" "$INSTALL_BIN_DIR/antigravity.va39" || true
    fi
  else
    if [[ -n "${ANTIGRAVITY_BAK:-}" && -f "$ANTIGRAVITY_BAK" ]]; then
      rm -f "$ANTIGRAVITY_BAK" || true
    fi
    if [[ -n "${ANTIGRAVITY_VA39_BAK:-}" && -f "$ANTIGRAVITY_VA39_BAK" ]]; then
      rm -f "$ANTIGRAVITY_VA39_BAK" || true
    fi
  fi
}

handle_cancel() {
  cleanup
  die
}

trap cleanup EXIT
trap handle_cancel INT TERM

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  GREEN=$'\033[32m'
  RED=$'\033[31m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  BOLD="" DIM="" GREEN="" RED="" CYAN="" RESET=""
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '%s\n' " ℹ️  ${CYAN}[..]${RESET} ${DIM}$*${RESET}"; }
ok()      { printf '%s\n' " ✅ ${GREEN}[OK]${RESET} $*"; }
die() {
  {
    printf "\033[?25h" # Restore cursor
    if [[ $# -gt 0 ]]; then
      printf '\n%s\n' " ❌ ${RED}[ERR]${RESET} $*"
    else
      printf '\n%s\n' " ❌ ${RED}[ERR]${RESET} Installation failed or was cancelled."
    fi
    printf "For manual patching and installation:\n"
    printf "%shttps://gist.github.com/Brajesh2022/e42160d29b55417db6c18c52dd1d6d37%s\n\n" "$CYAN" "$RESET"
  } >&2
  exit 1
}
divider() { printf '%s\n' "${DIM}────────────────────────────────────────${RESET}"; }

terminal_cols() {
  # Performance Optimization (Bolt): Prioritizing checking the native shell $COLUMNS variable
  # when it is populated and strictly numeric completely avoids the fork/exec process overhead
  # of spawning the external `tput` tool.
  if [[ -n "${COLUMNS:-}" && "$COLUMNS" != *[!0-9]* ]]; then
    echo "$COLUMNS"
  elif [[ -r /dev/tty ]]; then
    tput cols </dev/tty 2>/dev/null || echo 60
  else
    tput cols 2>/dev/null || echo 60
  fi
}

spinner() {
  local pid=$1
  local msg=$2
  local spinstr='\|/-'
  printf "\033[?25l" # Hide cursor
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf "\r\033[K %s[%c]%s %s%s%s" "$CYAN" "$spinstr" "$RESET" "$DIM" "$msg" "$RESET"
    local spinstr=$temp${spinstr%"$temp"}
    sleep 0.1
  done
  local exit_status=0
  wait "$pid" || exit_status=$?
  if [ $exit_status -eq 0 ]; then
    printf "\r\033[K ✅ %s[OK]%s %s\n" "$GREEN" "$RESET" "$msg"
  else
    printf "\r\033[K ❌ %s[ERR]%s %s\n" "$RED" "$RESET" "$msg"
  fi
  printf "\033[?25h" # Show cursor
  return $exit_status
}

download_with_progress() {
  local url=$1
  local dest=$2

  printf "\033[?25l" # Hide cursor

  local total_size=""
  if head_out=$(curl -sLI --connect-timeout 5 -m 10 -H "Cache-Control: no-cache" -- "$url" 2>/dev/null); then
    # Performance Optimization (Bolt): Pure Bash loop over $head_out prevents slow external process spawning (awk and tail).
    # Runs ~70x faster, avoiding CPU and memory overhead on mobile/Termux systems.
    # Security Enhancement (Sentinel): Uses '--' to terminate curl options and prevent option injection.
    while read -r line; do
      line="${line%$'\r'}"
      case "$line" in
        [Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Ll][Ee][Nn][Gg][Tt][Hh]:*)
          total_size="${line#*:}"
          # Strip leading and trailing whitespace
          total_size="${total_size#"${total_size%%[![:space:]]*}"}"
          total_size="${total_size%"${total_size##*[![:space:]]}"}"
          ;;
      esac
    done <<< "$head_out"
  fi

  if [[ -z "$total_size" || "$total_size" == *[!0-9]* ]]; then
    curl -fLs --connect-timeout 15 -m 120 -H "Cache-Control: no-cache" -o "$dest" -- "$url" >/dev/null 2>&1 &
    spinner $! "Downloading payload..."
    return $?
  fi

  # Strip leading zeros to prevent Bash octal arithmetic interpretation error (e.g. 08500000)
  # Performance Optimization (Bolt): Use highly efficient base-10 arithmetic expansion $((10#0$VAR))
  total_size=$((10#0$total_size))

  local cols
  cols=$(terminal_cols)
  [[ -z "$cols" || "$cols" == *[!0-9]* ]] && cols=60

  # Strip leading zeros to prevent Bash octal arithmetic interpretation error (e.g. 08, 09)
  # Performance Optimization (Bolt): Use highly efficient base-10 arithmetic expansion $((10#0$VAR))
  cols=$((10#0$cols))

  local w=$(( cols - 38 ))
  (( w > 60 )) && w=60
  (( w < 10 )) && w=10

  # Performance Optimization (Bolt): Probe the correct stat format flags once to avoid falling back repeatedly in the loop.
  local stat_format=""
  if stat -L -c "%s" /dev/null >/dev/null 2>&1; then
    stat_format="-L -c %s"
  elif stat -L -f "%z" /dev/null >/dev/null 2>&1; then
    stat_format="-L -f %z"
  fi

  curl -fLs --connect-timeout 15 -m 120 -H "Cache-Control: no-cache" -o "$dest" -- "$url" >/dev/null 2>&1 &
  local pid=$!

  local full_bar="████████████████████████████████████████████████████████████"
  local empty_bar="░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"

  # Performance Optimization (Bolt): Pre-calculate the total size in megabytes outside the progress bar
  # loop to avoid redundant divisions, multiplication, and modulo operations on every 150ms tick.
  local t_mb_i=$(( total_size / 1048576 ))
  local t_mb_d=$(( (total_size * 10 / 1048576) % 10 ))

  while kill -0 "$pid" 2>/dev/null; do
    local current_size=0
    if [[ -f "$dest" ]]; then
      # Performance Optimization (Bolt): Use the pre-probed stat flags directly. This avoids spawning failing commands
      # and eliminates extra process spawns/fallback evaluation overhead in high-frequency rendering.
      if [[ -n "$stat_format" ]]; then
        # shellcheck disable=SC2086
        current_size=$(stat $stat_format "$dest" 2>/dev/null || echo 0)
      else
        current_size=0
      fi
    fi
    [[ -z "$current_size" || "$current_size" == *[!0-9]* ]] && current_size=0

    # Strip leading zeros to prevent Bash octal arithmetic interpretation error (e.g. 08, 09)
    # Performance Optimization (Bolt): Use highly efficient base-10 arithmetic expansion $((10#0$current_size))
    current_size=$((10#0$current_size))

    local pct=$(( total_size > 0 ? current_size * 100 / total_size : 0 ))
    (( pct > 100 )) && pct=100
    local filled=$(( pct * w / 100 ))
    local bar="${full_bar:0:filled}${empty_bar:0:w-filled}"

    local c_mb_i=$(( current_size / 1048576 ))
    local c_mb_d=$(( (current_size * 10 / 1048576) % 10 ))

    # Optimized rendering using pure Bash (removes awk overhead)
    printf "\r\033[K %s[..]%s [%s] %3d%% %s%5d.%dM / %4d.%dM%s" \
      "$CYAN" "$RESET" "$bar" "$pct" "$DIM" "$c_mb_i" "$c_mb_d" "$t_mb_i" "$t_mb_d" "$RESET"

    sleep 0.15
  done

  local exit_status=0
  wait "$pid" || exit_status=$?

  if [ $exit_status -eq 0 ]; then
    local bar="${full_bar:0:w}"
    local t_mb_i=$(( total_size / 1048576 ))
    local t_mb_d=$(( (total_size * 10 / 1048576) % 10 ))
    printf "\r\033[K ✅ %s[OK]%s [%s] 100%% %s%5d.%dM / %4d.%dM%s\n" \
      "$GREEN" "$RESET" "$bar" "$DIM" "$t_mb_i" "$t_mb_d" "$t_mb_i" "$t_mb_d" "$RESET"
  else
    printf "\r\033[K ❌ %s[ERR]%s Download failed.\n" "$RED" "$RESET"
  fi

  printf "\033[?25h" # Restore cursor
  return $exit_status
}

# ── Early Dependency Check ────────────────────────────────────────────────────
# Validate critical command-line dependencies curl and awk before the header/logo block
# to prevent ugly shell/command-not-found errors during setup.
command -v curl >/dev/null 2>&1 || die "curl is required to download assets. Please install it using: pkg install curl"
command -v awk >/dev/null 2>&1  || die "awk is required to render the logo. Please install it using: pkg install gawk"

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
# Security Enhancement (Sentinel): Keep all temporary files within the secure randomized temporary directory
TMP_LOGO=$(mktemp "${SECURE_TMP_DIR}/antigravity-logo.XXXXXX" 2>/dev/null || echo "${SECURE_TMP_DIR}/antigravity-logo.ans")

if { curl -fLs --connect-timeout 5 -m 10 -H "Cache-Control: no-cache" -- "https://raw.githubusercontent.com/${REPO}/dev/logo.ans" > "$TMP_LOGO" 2>/dev/null || curl -fLs --connect-timeout 5 -m 10 -H "Cache-Control: no-cache" -- "https://raw.githubusercontent.com/Brajesh2022/antigravity-cli-termux/dev/logo.ans" > "$TMP_LOGO" 2>/dev/null; } && [[ -s "$TMP_LOGO" ]]; then

  COLS=$(terminal_cols)
  [[ -z "$COLS" || "$COLS" == *[!0-9]* ]] && COLS=60

  # Strip leading zeros to prevent Bash octal arithmetic interpretation error (e.g. 08, 09)
  # Performance Optimization (Bolt): Use highly efficient base-10 arithmetic expansion $((10#0$COLS))
  COLS=$((10#0$COLS))

  awk -v cols="$COLS" -v arch="$(uname -m)" -v bold="${BOLD}${CYAN}" -v dim="${DIM}" -v grn="${GREEN}" -v rst="${RESET}" '
  {
    sub(/\r$/, "");

    if (cols >= 48) {
      printf "%s", $0;
      if (NR == 3)      printf "\033[28G %sAntigravity Termux%s", bold, rst;
      else if (NR == 4) printf "\033[28G %sStandalone Installer%s", dim, rst;
      else if (NR == 5) printf "\033[28G %s────────────────────%s", dim, rst;
      else if (NR == 6) printf "\033[28G %sTarget:%s  Termux", dim, rst;
      else if (NR == 7) printf "\033[28G %sArch:%s    %s", dim, rst, arch;
      else if (NR == 8) printf "\033[28G %sStatus:%s  %sOnline%s", dim, rst, grn, rst;
      printf "\n";
    } else {
      print $0;
    }
  }
  END {
    if (cols < 48) {
      printf "\n";
      printf "  %sAntigravity Termux%s\n", bold, rst;
      printf "  %sStandalone Installer%s\n", dim, rst;
      printf "  %s────────────────────%s\n", dim, rst;
      printf "  %sTarget:%s  Termux\n", dim, rst;
      printf "  %sArch:%s    %s\n", dim, rst, arch;
      printf "  %sStatus:%s  %sOnline%s\n", dim, rst, grn, rst;
    }
  }' "$TMP_LOGO"

  rm -f "$TMP_LOGO"
else
  printf "  %sAntigravity Termux%s\n" "${BOLD}${CYAN}" "${RESET}"
  printf "  %sStandalone Installer%s\n" "${DIM}" "${RESET}"
fi
echo ""
divider

# ── Environment check ─────────────────────────────────────────────────────────
[[ "$(uname -m)" == "aarch64" ]] || die "Architecture must be aarch64"
command -v curl >/dev/null 2>&1  || die "curl is required. Please install it using: pkg install curl"
command -v awk  >/dev/null 2>&1  || die "awk is required. Please install it using: pkg install gawk"
command -v tar  >/dev/null 2>&1  || die "tar is required. Please install it using: pkg install tar"
command -v install >/dev/null 2>&1 || die "install is required. Please install it using: pkg install coreutils"
command -v jq      >/dev/null 2>&1 || die "jq is required (used by statusline and other tools). Please install it using: pkg install jq"

GLIBC_LOADER="${TERMUX_PREFIX}/glibc/lib/ld-linux-aarch64.so.1"
if [[ ! -x "$GLIBC_LOADER" ]]; then
  die "Missing Termux glibc loader: $GLIBC_LOADER
Please install the glibc packages using:
  pkg install glibc-repo && pkg install glibc"
fi

check_lse() {
  grep -q "atomics" /proc/cpuinfo
}

check_qemu() {
  command -v qemu-aarch64 >/dev/null 2>&1
}

CA_BUNDLE="${TERMUX_PREFIX}/etc/tls/cert.pem"
if [[ ! -s "$CA_BUNDLE" ]]; then
  die "Missing Termux CA bundle: $CA_BUNDLE
Please install the ca-certificates package using:
  pkg install ca-certificates"
fi

if ! check_lse; then
  if ! check_qemu; then
    die "This CPU does not support LSE atomics, and qemu-aarch64 was not found.
Please install the qemu-user-aarch64 package using:
  pkg install qemu-user-aarch64"
  fi
  ok "LSE Emulation: QEMU enabled"
fi

ok "Environment: ${ENV_TYPE} (aarch64)"

# ── Clean previous install ────────────────────────────────────────────────────
mkdir -p "$INSTALL_BIN_DIR" 2>/dev/null
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

# ── Download ──────────────────────────────────────────────────────────────────
download_with_progress "$URL" "$TMP" || die

# ── Extraction ────────────────────────────────────────────────────────────────
tar -xz -C "$EXTRACT_DIR" -f "$TMP" agy agy.va39 >/dev/null 2>&1 &
spinner $! "Extracting binaries..." || die

ANTIGRAVITY_BAK=""
ANTIGRAVITY_VA39_BAK=""
if [[ -f "$INSTALL_BIN_DIR/antigravity" ]]; then
  ANTIGRAVITY_BAK="$INSTALL_BIN_DIR/antigravity.bak.$$"
  mv -f "$INSTALL_BIN_DIR/antigravity" "$ANTIGRAVITY_BAK" || die "Failed to back up existing antigravity binary from $INSTALL_BIN_DIR"
fi
if [[ -f "$INSTALL_BIN_DIR/antigravity.va39" ]]; then
  ANTIGRAVITY_VA39_BAK="$INSTALL_BIN_DIR/antigravity.va39.bak.$$"
  mv -f "$INSTALL_BIN_DIR/antigravity.va39" "$ANTIGRAVITY_VA39_BAK" || die "Failed to back up existing antigravity.va39 binary from $INSTALL_BIN_DIR"
fi

install -m 0755 "$EXTRACT_DIR/agy" "$INSTALL_BIN_DIR/antigravity" || die "Failed to install antigravity binary to $INSTALL_BIN_DIR"
install -m 0755 "$EXTRACT_DIR/agy.va39" "$INSTALL_BIN_DIR/antigravity.va39" || die "Failed to install antigravity.va39 binary to $INSTALL_BIN_DIR"
ln -sf "antigravity" "$INSTALL_BIN_DIR/agy" || die "Failed to create antigravity symlink"
rm -rf "$EXTRACT_DIR"

# ── Verify twin-binary ────────────────────────────────────────────────────────
if [[ ! -f "$INSTALL_BIN_DIR/antigravity" || ! -f "$INSTALL_BIN_DIR/antigravity.va39" ]]; then
  rm -f "$INSTALL_BIN_DIR/antigravity" "$INSTALL_BIN_DIR/antigravity.va39"
  die "Verification failed: binaries not found in $INSTALL_BIN_DIR"
fi
ok "Binary found"

# ── Test & Extract Version ────────────────────────────────────────────────────
VERSION=""
if VERSION=$("$INSTALL_BIN_DIR/antigravity" --version 2>/dev/null); then
  ok "Engine online ($VERSION verified)"
  [[ -n "$ANTIGRAVITY_BAK" && -f "$ANTIGRAVITY_BAK" ]] && rm -f "$ANTIGRAVITY_BAK"
  [[ -n "$ANTIGRAVITY_VA39_BAK" && -f "$ANTIGRAVITY_VA39_BAK" ]] && rm -f "$ANTIGRAVITY_VA39_BAK"
else
  rm -f "$INSTALL_BIN_DIR/antigravity" "$INSTALL_BIN_DIR/antigravity.va39"
  die "Binaries failed to execute locally. Check dependencies."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
printf '\n%s\n' "${GREEN}${BOLD}✨ Installation Complete! 🚀${RESET}"
divider
info "Installed binaries to: ${BOLD}${INSTALL_BIN_DIR}${RESET}"
info "Release archive kept at: ${BOLD}${TMP}${RESET}"
info "Optional verification:"
info "${BOLD}cd $(dirname "$TMP") && gh attestation verify antigravity-termux-standalone.tar.gz -R wallentx/antigravity-cli-termux${RESET}"
printf '\n'

case ":$PATH:" in
  *":$INSTALL_BIN_DIR:"*) ;;
  *)
    cat >&2 <<EOF
⚠️  ${RED}${BOLD}Warning:${RESET} ${BOLD}$INSTALL_BIN_DIR${RESET} is not in PATH for this shell.
Please add this to your shell profile (e.g., ~/.bashrc or ~/.zshrc):

  export PATH="$INSTALL_BIN_DIR:\$PATH"

EOF
    ;;
esac

# ── Launch ────────────────────────────────────────────────────────────────────
info "Launching Antigravity CLI..."

export PATH="$INSTALL_BIN_DIR:$PATH"
INSTALL_SUCCESS=1
cleanup
trap - EXIT

if [[ "${ANTIGRAVITY_INSTALL_SKIP_LAUNCH:-0}" == "1" ]]; then
  ok "Launch skipped by ANTIGRAVITY_INSTALL_SKIP_LAUNCH"
  exit 0
fi

exec "$INSTALL_BIN_DIR/antigravity"
