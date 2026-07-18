#!/bin/bash
set -euo pipefail

 jules-11360301565252093106-38c25a8c
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
=======
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
 main

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
 jules-13866825955464836830-50397af9
# Map state to emoji and polished label
case "$STATE" in
  initializing) EMOJI="🚀"; LABEL="Initializing" ;;
  idle)         EMOJI="😴"; LABEL="Idle" ;;
  thinking)     EMOJI="🤔"; LABEL="Thinking" ;;
  working)      EMOJI="🏃"; LABEL="Working" ;;
  tool_use)     EMOJI="🛠️"; LABEL="Using Tool" ;;
  review)       EMOJI="👀"; LABEL="Review" ;;
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

TITLE="$EMOJI $LABEL | $WORKSPACE"
=======
# Map state to emoji and polished user-friendly label
case "$STATE" in
  initializing) EMOJI="🚀"; STATE_LABEL="Initializing" ;;
  idle)         EMOJI="😴"; STATE_LABEL="Idle" ;;
  thinking)     EMOJI="🤔"; STATE_LABEL="Thinking" ;;
  working)      EMOJI="🏃"; STATE_LABEL="Working" ;;
  tool_use)     EMOJI="🛠️"; STATE_LABEL="Using Tool" ;;
  review)       EMOJI="👀"; STATE_LABEL="Reviewing" ;;
  *)            EMOJI="🤖"; STATE_LABEL="Active" ;;
esac

TITLE="$EMOJI $STATE_LABEL | $WORKSPACE"
 main

# Print title safely to avoid option injection
printf "%s\n" "$TITLE"
