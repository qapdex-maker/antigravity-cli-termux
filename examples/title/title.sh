#!/bin/bash
set -euo pipefail

# Extract fields safely using jq and null delimiters to prevent line-injection vulnerabilities.
# Performance Optimization (Bolt): stream stdin directly to jq to avoid spawning an external cat process and copying buffers.
# We append a sentinel "END" field to ensure the read block never fails on empty/missing trailing fields.
# We also use tr -d '\r' to strip carriage returns to prevent CRLF/terminal injection.
# Security/Performance Optimization (Bolt): Stripping both null-bytes and carriage returns (\r) directly inside
# the single-pass jq filter avoids the overhead of executing separate Bash string replacements for 5 variables
# in high-frequency title rendering. Resolving state emoji and label inside jq removes the need for Bash case mapping.
# Security Enhancement (Sentinel): Transitioning to null delimiters avoids field misalignment on embedded newlines.
# Performance Optimization (Bolt): Read resolved EMOJI and LABEL directly from single-pass jq filter to avoid redundant Bash case mapping.
{
  read -d '' -r EMOJI || true
  read -d '' -r LABEL || true
  read -d '' -r CWD || true
  read -d '' -r SANDBOX || true
  read -d '' -r VCS_BRANCH || true
  read -d '' -r VCS_DIRTY || true
  read -d '' -r MODEL || true
  read -d '' -r _ || true
} < <(jq -j '
  def safe(v): (v | tostring | split("\u0000") | join("") | split("\r") | join(""));
  def safe_get(key): if type == "object" then .[key] else null end;
  def titlecase: (tostring | split("_") | join(" ") | (.[0:1] | ascii_upcase) + .[1:]);
  # Security Enhancement (Sentinel): Assert root is an object before indexing parent_key to prevent fatal jq crashes on non-object root JSON payloads
  def safe_nested(parent_key; child_key): if (type == "object") and (.[parent_key] | type == "object") then .[parent_key][child_key] else null end;

  (safe_get("agent_state") // "idle") as $st |
  (if $st == "initializing" then ["🚀", "Initializing"]
   elif $st == "idle" then ["🟢", "Idle"]
   elif $st == "thinking" then ["🤔", "Thinking"]
   elif $st == "working" then ["🏃", "Working"]
   elif $st == "tool_use" then ["🔧", "Using Tool"]
   elif $st == "review" then ["👀", "Review"]
   elif $st == "paused" then ["⏸️", "Paused"]
   elif ($st == "waiting" or $st == "input_required" or $st == "permission_required" or $st == "prompt") then ["❓", "Waiting for Input"]
   elif ($st == "compacting" or $st == "context_compacting" or $st == "summarizing") then ["🧹", "Compacting"]
   elif ($st == "retry" or $st == "retrying") then ["🔄", "Retrying"]
   elif ($st == "completed" or $st == "success") then ["✅", "Completed"]
   elif ($st == "failed" or $st == "error") then ["❌", "Failed"]
   elif $st == "cancelled" then ["🛑", "Cancelled"]
   elif ($st == "stopped" or $st == "interrupted") then ["🛑", "Stopped"]
   elif $st == "aborted" then ["🛑", "Aborted"]
   else ["🤖", ($st | titlecase)]
   end) as $res |

  safe($res[0]), "\u0000",
  safe($res[1]), "\u0000",
  safe(safe_nested("workspace"; "current_dir") // ""), "\u0000",
  safe(safe_nested("sandbox"; "enabled") // false), "\u0000",
  safe(safe_nested("vcs"; "branch") // ""), "\u0000",
  safe(safe_nested("vcs"; "dirty") // false), "\u0000",
  safe(safe_nested("model"; "display_name") // ""), "\u0000",
  "END\u0000"
' 2>/dev/null)

# ─── Workspace Extraction, Input Validation, Sanitization & Fallbacks ───────
# Ensure variables are strictly validated, sanitized, and set to default fallbacks in a single pass.
# Performance Optimization (Bolt): Reading EMOJI and LABEL directly from single-pass jq avoids running
# redundant case statements in Bash and eliminates duplicate state mapping logic.
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

[[ -z "${EMOJI:-}" ]] && EMOJI="🤖"
[[ -z "${LABEL:-}"           || "$LABEL"          == *[!a-zA-Z0-9_\ -]* ]] && LABEL="Idle"
[[ -z "${WORKSPACE:-}"  || "$WORKSPACE"  == *[!a-zA-Z0-9_./\ -]* ]] && WORKSPACE="unknown"
[[ "${SANDBOX:-}"    != "true" && "$SANDBOX" != "false" ]] && SANDBOX="false"
[[ -z "${VCS_BRANCH:-}" || "$VCS_BRANCH" == *[!a-zA-Z0-9_./-]* ]] && VCS_BRANCH=""
[[ "${VCS_DIRTY:-}"  != "true" && "$VCS_DIRTY" != "false" ]] && VCS_DIRTY="false"
[[ -z "${MODEL:-}"      || "$MODEL"      == *[!a-zA-Z0-9_./\ -]* ]] && MODEL=""

# Build multi-dimensional branch text badge and safety visual cue since color is not supported in typical window titles
M_TXT=""
if [ -n "$MODEL" ]; then
  DISPLAY_MODEL="$MODEL"
  if [ "${#MODEL}" -gt 15 ]; then
    DISPLAY_MODEL="${MODEL:0:9}...${MODEL: -3}"
  fi
  M_TXT=" (🧠 ${DISPLAY_MODEL})"
fi

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

TITLE="$EMOJI $LABEL | $WORKSPACE$M_TXT$VCS_TXT$SB_TXT"

# Print title safely to avoid option injection
printf "%s\n" "$TITLE"
