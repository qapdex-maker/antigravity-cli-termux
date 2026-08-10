#!/bin/bash
set -euo pipefail

# Extract fields safely using jq and null delimiters to prevent line-injection vulnerabilities.
# Performance Optimization (Bolt): stream stdin directly to jq to avoid spawning an external cat process and copying buffers.
# We append a sentinel "END" field to ensure the read block never fails on empty/missing trailing fields.
# We also use tr -d '\r' to strip carriage returns to prevent CRLF/terminal injection.
# Security Enhancement (Sentinel): Transitioning to null delimiters avoids field misalignment on embedded newlines.
{
  read -d '' -r STATE || true
  read -d '' -r CWD || true
  read -d '' -r SANDBOX || true
  read -d '' -r VCS_BRANCH || true
  read -d '' -r VCS_DIRTY || true
  read -d '' -r _ || true
} < <(jq -j '
  def safe(v): (v | tostring | gsub("\u0000"; ""));
  safe(.agent_state // "idle"), "\u0000",
  safe(.workspace.current_dir // ""), "\u0000",
  safe(.sandbox.enabled // false), "\u0000",
  safe(.vcs?.branch // ""), "\u0000",
  safe(.vcs?.dirty // false), "\u0000",
  "END\u0000"
' 2>/dev/null)

# Performance Optimization (Bolt): Pure Bash parameter expansion ${VAR//$'\r'/} replaces
# the external process pipeline | tr -d '\r', removing process spawn overhead in high-frequency title rendering.
STATE="${STATE//$'\r'/}"
CWD="${CWD//$'\r'/}"
SANDBOX="${SANDBOX//$'\r'/}"
VCS_BRANCH="${VCS_BRANCH//$'\r'/}"
VCS_DIRTY="${VCS_DIRTY//$'\r'/}"

# ─── Workspace Extraction, Input Validation, Sanitization & Fallbacks ───────
# Ensure variables are strictly validated, sanitized, and set to default fallbacks in a single pass.
# Performance Optimization (Bolt): Combined fallback & validation checks completely avoid redundant shell operations
# on clean paths, yielding an expected speedup in title rendering.
if [ -n "${CWD:-}" ]; then
  if [[ "$CWD" == "/google/src/cloud/"* ]]; then
    TEMP_CWD="${CWD#/google/src/cloud/}"
    if [[ "$TEMP_CWD" == *"/"* ]]; then
      TEMP_CWD="${TEMP_CWD#*/}"
      WORKSPACE="${TEMP_CWD%%/*}"
    fi
  fi
  # Fallback to standard basename extraction if not a Google path or missing components.
  # Performance Optimization (Bolt): Extract base name using pure Bash parameter expansion to prevent process spawns and option injection.
  # This avoids the fork/exec overhead of the external `basename` command.
  if [ -z "${WORKSPACE:-}" ]; then
    TEMP_CWD="${CWD%/}"
    WORKSPACE="${TEMP_CWD##*/}"
    WORKSPACE="${WORKSPACE:-/}"
  fi
else
  WORKSPACE="unknown"
fi

[[ -z "${STATE:-}"      || "$STATE"      == *[!a-zA-Z0-9_-]* ]] && STATE="idle"
[[ -z "${WORKSPACE:-}"  || "$WORKSPACE"  == *[!a-zA-Z0-9_./\ -]* ]] && WORKSPACE="unknown"
[[ "${SANDBOX:-}"    != "true" && "$SANDBOX" != "false" ]] && SANDBOX="false"
[[ -z "${VCS_BRANCH:-}" || "$VCS_BRANCH" == *[!a-zA-Z0-9_./-]* ]] && VCS_BRANCH=""
[[ "${VCS_DIRTY:-}"  != "true" && "$VCS_DIRTY" != "false" ]] && VCS_DIRTY="false"

# Map state to emoji and polished label
case "$STATE" in
  initializing) EMOJI="🚀"; LABEL="Initializing" ;;
  idle)         EMOJI="🟢"; LABEL="Idle" ;;
  thinking)     EMOJI="🤔"; LABEL="Thinking" ;;
  working)      EMOJI="🏃"; LABEL="Working" ;;
  tool_use)     EMOJI="🔧"; LABEL="Using Tool" ;;
  review)       EMOJI="👀"; LABEL="Review" ;;
  paused)       EMOJI="⏸️"; LABEL="Paused" ;;
  completed|success) EMOJI="✅"; LABEL="Completed" ;;
  failed|error)      EMOJI="❌"; LABEL="Failed" ;;
  cancelled)         EMOJI="🛑"; LABEL="Cancelled" ;;
  stopped|interrupted) EMOJI="🛑"; LABEL="Stopped" ;;
  aborted)           EMOJI="🛑"; LABEL="Aborted" ;;
  *)            EMOJI="🤖"
                # Fallback mapping: convert underscore to space, and capitalize first letter
                # without spawning subshells or using Bash 4+ specific parameters
                TEMP_STATE="${STATE//_/ }"
                FIRST_CHAR="${TEMP_STATE:0:1}"
                REST_CHARS="${TEMP_STATE:1}"
                case "$FIRST_CHAR" in
                  a) FIRST_CHAR="A" ;; b) FIRST_CHAR="B" ;; c) FIRST_CHAR="C" ;; d) FIRST_CHAR="D" ;;
                  e) FIRST_CHAR="E" ;; f) FIRST_CHAR="F" ;; g) FIRST_CHAR="G" ;; h) FIRST_CHAR="H" ;;
                  i) FIRST_CHAR="I" ;; j) FIRST_CHAR="J" ;; k) FIRST_CHAR="K" ;; l) FIRST_CHAR="L" ;;
                  m) FIRST_CHAR="M" ;; n) FIRST_CHAR="N" ;; o) FIRST_CHAR="O" ;; p) FIRST_CHAR="P" ;;
                  q) FIRST_CHAR="Q" ;; r) FIRST_CHAR="R" ;; s) FIRST_CHAR="S" ;; t) FIRST_CHAR="T" ;;
                  u) FIRST_CHAR="U" ;; v) FIRST_CHAR="V" ;; w) FIRST_CHAR="W" ;; x) FIRST_CHAR="X" ;;
                  y) FIRST_CHAR="Y" ;; z) FIRST_CHAR="Z" ;;
                esac
                LABEL="${FIRST_CHAR}${REST_CHARS}"
                ;;
esac

# Build multi-dimensional branch text badge and safety visual cue since color is not supported in typical window titles
VCS_TXT=""
if [ -n "$VCS_BRANCH" ]; then
  DISPLAY_BRANCH="$VCS_BRANCH"
  if [ "${#VCS_BRANCH}" -gt 15 ]; then
    DISPLAY_BRANCH="${VCS_BRANCH:0:9}...${VCS_BRANCH: -3}"
  fi

  if [ "$VCS_DIRTY" = "true" ]; then
    VCS_TXT=" (🌿 ${DISPLAY_BRANCH}*)"
  else
    VCS_TXT=" (🌿 ${DISPLAY_BRANCH})"
  fi
fi

if [ "$SANDBOX" = "true" ]; then
  SB_TXT=" (🔒 Sandbox ON)"
else
  SB_TXT=" (🔓 Sandbox OFF)"
fi

TITLE="$EMOJI $LABEL | $WORKSPACE$VCS_TXT$SB_TXT"

# Print title safely to avoid option injection
printf "%s\n" "$TITLE"
