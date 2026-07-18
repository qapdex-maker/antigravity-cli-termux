#!/bin/bash
set -euo pipefail

# Read JSON payload from stdin
DATA=$(cat)

# Extract fields using jq and safely strip any carriage return (\r) characters
{
  read -r STATE
  read -r CWD
} <<< "$(jq -r '
  (.agent_state // "idle"),
  (.workspace.current_dir // "")
' 2>/dev/null <<< "$DATA" | tr -d '\r' || printf "idle\n\n")"

# Try to extract CitC workspace name from CWD
# Performance Optimization (Bolt): Avoid regex `=~` engine compilation and execution overhead by using pure Bash parameter expansion.
if [ -n "$CWD" ]; then
  if [[ "$CWD" == "/google/src/cloud/"* ]]; then
    TEMP_CWD="${CWD#/google/src/cloud/}"
    if [[ "$TEMP_CWD" == *"/"* ]]; then
      TEMP_CWD="${TEMP_CWD#*/}"
      WORKSPACE="${TEMP_CWD%%/*}"
    else
      # Not enough components, fall back to basename
      TEMP_CWD="${CWD%/}"
      WORKSPACE="${TEMP_CWD##*/}"
      WORKSPACE="${WORKSPACE:-/}"
    fi
  else
    # Extract base name using pure Bash parameter expansion to prevent process spawns and option injection.
    # Performance Optimization (Bolt): This avoids fork/exec overhead of the external `basename` command.
    TEMP_CWD="${CWD%/}"
    WORKSPACE="${TEMP_CWD##*/}"
    WORKSPACE="${WORKSPACE:-/}"
  fi
else
  WORKSPACE="unknown"
fi

# ─── Input Validation & Sanitization ─────────────────────────────────────────
# Ensure variables are strictly validated and sanitized to prevent terminal/option injection.
[[ "$STATE"      == *[!a-zA-Z0-9_-]* || -z "$STATE" ]] && STATE="idle"
[[ "$WORKSPACE"  == *[!a-zA-Z0-9_./\ -]* || -z "$WORKSPACE" ]] && WORKSPACE="unknown"

# Map state to emoji
case "$STATE" in
  initializing) EMOJI="🚀" ;;
  idle)         EMOJI="😴" ;;
  thinking)     EMOJI="🤔" ;;
  working)      EMOJI="🏃" ;;
  tool_use)     EMOJI="🛠️" ;;
  review)       EMOJI="👀" ;;
  *)            EMOJI="🤖" ;;
esac

TITLE="$EMOJI $STATE | $WORKSPACE"

# Print title safely to avoid option injection
printf "%s\n" "$TITLE"
