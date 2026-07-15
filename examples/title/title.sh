#!/bin/bash
set -euo pipefail

# Read JSON payload from stdin
DATA=$(cat)

# Extract fields using jq
{
  read -r STATE
  read -r CWD
} <<< "$(jq -r '
  (.agent_state // "idle"),
  (.workspace.current_dir // "")
' 2>/dev/null <<< "$DATA" || printf "idle\n\n")"

# Try to extract CitC workspace name from CWD
if [ -n "$CWD" ]; then
  if [[ "$CWD" =~ /google/src/cloud/[^/]+/([^/]+) ]]; then
    WORKSPACE="${BASH_REMATCH[1]}"
  else
 sentinel/security-improvement-bash-injection-3632722592319210898
    # Extract base name using pure Bash parameter expansion to prevent process spawns and option injection
    TEMP_CWD="${CWD%/}"
    WORKSPACE="${TEMP_CWD##*/}"
=======
    # Performance Optimization (Bolt): Use pure Bash parameter expansion
    # instead of spawning a subshell with the external `basename` command.
    # This avoids fork/exec overhead which is highly beneficial on mobile/Termux environments.
    WORKSPACE="${CWD%/}"
    WORKSPACE="${WORKSPACE##*/}"
 main
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
