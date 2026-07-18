#!/bin/bash
set -euo pipefail

# Extract fields using jq
# Performance Optimization (Bolt): stream stdin directly to jq to avoid spawning an external cat process and copying buffers.
# We append a sentinel "END" line to ensure the read block never fails on empty/missing trailing fields.
OUTPUT="$(jq -r '
  (.agent_state // "idle"),
  (.workspace.current_dir // ""),
  "END"
' 2>/dev/null || true)"

# Fallback in case of empty input or parsing error
if [[ -z "$OUTPUT" ]]; then
  OUTPUT=$'idle\n\nEND'
fi

{
  read -r STATE
  read -r CWD
  read -r _
} <<< "$OUTPUT"

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
