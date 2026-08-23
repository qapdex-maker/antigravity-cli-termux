#!/bin/bash
set -euo pipefail

# ─── ANSI Helpers (Standard 16-color palette only) ───────────────────────────
R=$'\033[0m'         # Reset
B=$'\033[1m'         # Bold
D=$'\033[2m'         # Dim
I=$'\033[3m'         # Italic

# Foreground accents (Standard 16 colors)
FG_BLACK=$'\033[30m'
FG_RED=$'\033[31m'
FG_GREEN=$'\033[32m'
FG_YELLOW=$'\033[33m'
FG_BLUE=$'\033[34m'
FG_MAGENTA=$'\033[35m'
FG_CYAN=$'\033[36m'
FG_WHITE=$'\033[37m'

FG_GRAY=$'\033[90m'
FG_BRIGHT_RED=$'\033[91m'
FG_BRIGHT_GREEN=$'\033[92m'
FG_BRIGHT_YELLOW=$'\033[93m'
FG_BRIGHT_BLUE=$'\033[94m'
FG_BRIGHT_MAGENTA=$'\033[95m'
FG_BRIGHT_CYAN=$'\033[96m'
FG_BRIGHT_WHITE=$'\033[97m'

# Number Highlight Color
NUM_COLOR="${FG_BRIGHT_WHITE}${B}"

# ─── Parse JSON safely using jq and null delimiters to prevent line-injection vulnerabilities. ───
# Extract all fields in one pass to prevent spawning jq 8 times.
# We append a sentinel "END" field to ensure the read block never fails on empty/missing trailing fields.
# We also use tr -d '\r' to strip carriage returns to prevent CRLF/terminal injection.
{
  read -d '' -r STATE_COLOR || true
  read -d '' -r STATE_LABEL || true
  read -d '' -r USED_PCT || true
  read -d '' -r VCS_BRANCH || true
  read -d '' -r VCS_DIRTY || true
  read -d '' -r SANDBOX || true
  read -d '' -r ARTIFACTS || true
  read -d '' -r SUBAGENTS || true
  read -d '' -r BG_TASKS || true
  read -d '' -r MODEL || true
  read -d '' -r COLS || true
  read -d '' -r _ || true
} < <(jq -j '
  def safe(v): (v | tostring | split("\u0000") | join("") | split("\r") | join(""));
  def safe_get(key): if type == "object" then .[key] else null end;
  def safe_nested(parent_key; child_key): if (type == "object") and (.[parent_key] | type == "object") then .[parent_key][child_key] else null end;

  (safe_get("agent_state") // "idle") as $st |
  (if $st == "initializing" then ["cyan", "🚀 INIT"]
   elif $st == "idle" then ["green", "🟢 READY"]
   elif $st == "thinking" then ["yellow", "🤔 THINKING"]
   elif ($st == "planning" or $st == "plan") then ["cyan", "📋 PLANNING"]
   elif $st == "working" then ["cyan", "🏃 WORKING"]
   elif $st == "tool_use" then ["magenta", "🔧 TOOL"]
   elif $st == "review" then ["blue", "👀 REVIEW"]
   elif $st == "paused" then ["yellow", "⏸️ PAUSED"]
   elif ($st == "waiting" or $st == "input_required" or $st == "permission_required" or $st == "prompt" or $st == "approval_required" or $st == "approval" or $st == "permission" or $st == "confirm" or $st == "confirmation") then ["yellow", "❓ WAITING"]
   elif ($st == "compacting" or $st == "context_compacting" or $st == "summarizing") then ["magenta", "🧹 COMPACTING"]
   elif ($st == "retry" or $st == "retrying") then ["yellow", "🔄 RETRYING"]
   elif ($st == "completed" or $st == "success") then ["green", "✅ COMPLETED"]
   elif ($st == "failed" or $st == "error") then ["red", "❌ FAILED"]
   elif $st == "cancelled" then ["red", "🛑 CANCELLED"]
   elif ($st == "stopped" or $st == "interrupted") then ["red", "🛑 STOPPED"]
   elif $st == "aborted" then ["red", "🛑 ABORTED"]
   else
     (($st | tostring | gsub("[^a-zA-Z0-9_-]"; "")) as $clean_st |
      ["white", "⏳ " + (if $clean_st == "" then "IDLE" else ($clean_st | ascii_upcase) end)])
   end) as $st_res |

  safe($st_res[0]), "\u0000",
  safe($st_res[1]), "\u0000",
  safe(safe_nested("context_window"; "used_percentage") // 0), "\u0000",
  safe(safe_nested("vcs"; "branch") // ""), "\u0000",
  safe(safe_nested("vcs"; "dirty") // false), "\u0000",
  safe(safe_nested("sandbox"; "enabled") // false), "\u0000",
  safe(safe_get("artifact_count") // 0), "\u0000",
  safe(if (type == "object") and (.subagents | type == "array") then (.subagents | length) else 0 end), "\u0000",
  safe(safe_get("task_count") // 0), "\u0000",
  safe(safe_nested("model"; "display_name") // ""), "\u0000",
  safe(safe_get("terminal_width") // 80), "\u0000",
  "END\u0000"
' 2>/dev/null)

# ─── Input Validation, Sanitization & Fallbacks ──────────────────────────────
# Ensure variables are strictly validated, sanitized, and set to default fallbacks in a single pass.
if [[ -z "$USED_PCT" || "$USED_PCT" == *[!0-9.]* || "$USED_PCT" == *.*.* || "$USED_PCT" == "." ]]; then
  USED_PCT=0
fi

[[ -z "$STATE_COLOR" || "$STATE_COLOR" == *[!a-z]* ]] && STATE_COLOR="green"
[[ -z "$STATE_LABEL" ]] && STATE_LABEL="🟢 READY"
[[ -z "$VCS_BRANCH" || "$VCS_BRANCH" == *[!a-zA-Z0-9_./-]* ]] && VCS_BRANCH=""
[[ "$VCS_DIRTY"  != "true" && "$VCS_DIRTY" != "false" ]] && VCS_DIRTY="false"
[[ "$SANDBOX"    != "true" && "$SANDBOX" != "false" ]] && SANDBOX="false"
[[ -z "$ARTIFACTS"  || "$ARTIFACTS"  == *[!0-9]* ]] && ARTIFACTS=0
[[ -z "$SUBAGENTS"  || "$SUBAGENTS"  == *[!0-9]* ]] && SUBAGENTS=0
[[ -z "$BG_TASKS"   || "$BG_TASKS"   == *[!0-9]* ]] && BG_TASKS=0
[[ -z "$MODEL"      || "$MODEL"      == *[!a-zA-Z0-9_./\ -]* ]] && MODEL=""
[[ -z "$COLS"       || "$COLS"       == *[!0-9]* ]] && COLS=80

# Strip leading zeros to prevent Bash octal arithmetic/comparison issues (e.g. 08, 09)
ARTIFACTS=$((10#0$ARTIFACTS))
SUBAGENTS=$((10#0$SUBAGENTS))
BG_TASKS=$((10#0$BG_TASKS))
COLS=$((10#0$COLS))

# ─── Computed Values ─────────────────────────────────────────────────────────
# Use LC_NUMERIC=C and printf -v to prevent fork overhead and locale errors
LC_NUMERIC=C printf -v PCT_FMT "%.1f" "$USED_PCT"
# Derive PCT_INT from the formatted PCT_FMT string so indicator boundaries align with the displayed percentage
PCT_INT=${PCT_FMT%.*}; PCT_INT=${PCT_INT:-0}
[[ -z "$PCT_INT" || "$PCT_INT" == *[!0-9]* ]] && PCT_INT=0
# Strip leading zeros to prevent Bash octal arithmetic/comparison issues
PCT_INT=$((10#0$PCT_INT))

# ─── State Indicator (No background colors) ──────────────────────────────────
case "$STATE_COLOR" in
  cyan)    S="${FG_BRIGHT_CYAN}${B}${STATE_LABEL}${R}" ;;
  green)   S="${FG_BRIGHT_GREEN}${B}${STATE_LABEL}${R}" ;;
  yellow)  S="${FG_BRIGHT_YELLOW}${B}${STATE_LABEL}${R}" ;;
  magenta) S="${FG_BRIGHT_MAGENTA}${B}${STATE_LABEL}${R}" ;;
  blue)    S="${FG_BRIGHT_BLUE}${B}${STATE_LABEL}${R}" ;;
  red)     S="${FG_BRIGHT_RED}${B}${STATE_LABEL}${R}" ;;
  *)       S="${FG_WHITE}${B}${STATE_LABEL}${R}" ;;
esac

# ─── VCS Branch ──────────────────────────────────────────────────────────────
V=""
if [ -n "$VCS_BRANCH" ]; then
  # Truncate branch name if it is too long and we are on a narrow terminal (< 80 cols)
  DISPLAY_BRANCH="$VCS_BRANCH"
  if [ "$COLS" -lt 80 ] && [ "${#VCS_BRANCH}" -gt 15 ]; then
    DISPLAY_BRANCH="${VCS_BRANCH:0:9}...${VCS_BRANCH: -3}"
  fi

  if [ "$VCS_DIRTY" = "true" ]; then
    V="${FG_GRAY} ╱ ${FG_BRIGHT_RED}🌿 ${DISPLAY_BRANCH}${FG_BRIGHT_YELLOW}*${R}"
  else
    V="${FG_GRAY} ╱ ${FG_BRIGHT_BLUE}🌿 ${DISPLAY_BRANCH}${R}"
  fi
fi

# ─── Model ───────────────────────────────────────────────────────────────────
M=""
if [ -n "$MODEL" ]; then
  # Hide model on extremely narrow screens (< 50 cols) or truncate if narrow (< 80 cols)
  if [ "$COLS" -ge 50 ]; then
    DISPLAY_MODEL="$MODEL"
    if [ "$COLS" -lt 80 ] && [ "${#MODEL}" -gt 15 ]; then
      DISPLAY_MODEL="${MODEL:0:9}...${MODEL: -3}"
    fi
    M="${FG_GRAY} ╱ ${FG_BRIGHT_MAGENTA}${I}🧠 ${DISPLAY_MODEL}${R}"
  fi
fi

# ─── Sandbox Badge ───────────────────────────────────────────────────────────
if [ "$COLS" -lt 80 ]; then
  SB_LABEL=""
else
  SB_LABEL="sandbox "
fi

if [ "$SANDBOX" = "true" ]; then
  SB="${FG_GRAY}${SB_LABEL}${FG_BRIGHT_GREEN}${B}🔒 ON${R}"
else
  SB="${FG_GRAY}${SB_LABEL}${FG_BRIGHT_RED}${B}🔓 OFF${R}"
fi

# ─── Context Bar (dynamic width based on screen width, fine-grain Unicode) ───
BAR_LEN=15
if [ "$COLS" -lt 80 ]; then
  BAR_LEN=8
fi

FILLED=$((PCT_INT * BAR_LEN / 100))
REMAINDER=$(( (PCT_INT * BAR_LEN) % 100 ))

# Pick color based on percentage
if [ "$PCT_INT" -ge 90 ]; then
  BAR_COLOR="$FG_BRIGHT_RED"
elif [ "$PCT_INT" -ge 60 ]; then
  BAR_COLOR="$FG_BRIGHT_YELLOW"
else
  BAR_COLOR="$FG_BRIGHT_WHITE"
fi

# Build bar with partial-fill last block using locale-safe ASCII placeholder slicing to avoid multi-byte UTF-8 string slicing.
FULL_BAR_ASCII="###############"
EMPTY_BAR_ASCII="---------------"

if [ "$FILLED" -lt "$BAR_LEN" ]; then
  EMPTY_LEN=0
  if [ "$BAR_LEN" -gt "$FILLED" ]; then
    EMPTY_LEN=$(( BAR_LEN - FILLED - 1 ))
  fi

  F_BAR_ASCII="${FULL_BAR_ASCII:0:FILLED}"
  E_BAR_ASCII="${EMPTY_BAR_ASCII:0:EMPTY_LEN}"

  F_BAR="${F_BAR_ASCII//#/█}"
  E_BAR="${E_BAR_ASCII//-/·}"

  # Contrast-enhanced progress bar coloring:
  # The filled portion and partially filled character are colored with BAR_COLOR.
  # The inactive/empty dots of the progress bar are colored with FG_GRAY.
  if [ "$REMAINDER" -ge 75 ]; then
    PART_CHAR="▓"
    BAR="${BAR_COLOR}${F_BAR}${PART_CHAR}${FG_GRAY}${E_BAR}"
  elif [ "$REMAINDER" -ge 50 ]; then
    PART_CHAR="▒"
    BAR="${BAR_COLOR}${F_BAR}${PART_CHAR}${FG_GRAY}${E_BAR}"
  elif [ "$REMAINDER" -ge 25 ]; then
    PART_CHAR="░"
    BAR="${BAR_COLOR}${F_BAR}${PART_CHAR}${FG_GRAY}${E_BAR}"
  else
    PART_CHAR="·"
    BAR="${BAR_COLOR}${F_BAR}${FG_GRAY}${PART_CHAR}${E_BAR}"
  fi
else
  # Generate full bar of length BAR_LEN
  F_BAR_ASCII="${FULL_BAR_ASCII:0:BAR_LEN}"
  BAR="${F_BAR_ASCII//#/█}"
  BAR="${BAR_COLOR}${BAR}"
fi

# ─── Stats ───────────────────────────────────────────────────────────────────
# Match context percentage text color with warning color for high usage (red/yellow/white)
# Dim zero-value context percentage text (0.0%) for better visual hierarchy when unused
if [ "$PCT_INT" -eq 0 ] && [ "$PCT_FMT" = "0.0" ]; then
  CTX_PCT_COLOR="$FG_GRAY"
else
  CTX_PCT_COLOR="${BAR_COLOR}${B}"
fi

CTX_WARNING=""
if [ "$PCT_INT" -ge 90 ]; then
  CTX_WARNING=" ⚠️"
elif [ "$PCT_INT" -ge 60 ]; then
  CTX_WARNING=" ⚡"
fi
CTX="${FG_GRAY}📊 ctx ${BAR}${R} ${CTX_PCT_COLOR}${PCT_FMT}%${CTX_WARNING}${R}"

# Dim zeros for better visual hierarchy without spawning subshells
ART_COLOR="$FG_GRAY"; [ "$ARTIFACTS" -gt 0 ] && ART_COLOR="$NUM_COLOR"
SUB_COLOR="$FG_GRAY"; [ "$SUBAGENTS" -gt 0 ] && SUB_COLOR="$NUM_COLOR"
TAS_COLOR="$FG_GRAY"; [ "$BG_TASKS" -gt 0 ] && TAS_COLOR="$NUM_COLOR"

if [ "$COLS" -lt 80 ]; then
  ART_FMT="${FG_GRAY}📦 ${ART_COLOR}${ARTIFACTS}${R}"
  SUB_FMT="${FG_GRAY}👥 ${SUB_COLOR}${SUBAGENTS}${R}"
  BG_FMT="${FG_GRAY}📋 ${TAS_COLOR}${BG_TASKS}${R}"
else
  ART_FMT="${FG_GRAY}📦 artifacts ${ART_COLOR}${ARTIFACTS}${R}"
  SUB_FMT="${FG_GRAY}👥 subagents ${SUB_COLOR}${SUBAGENTS}${R}"
  BG_FMT="${FG_GRAY}📋 tasks ${TAS_COLOR}${BG_TASKS}${R}"
fi

# ─── Separators ──────────────────────────────────────────────────────────────
DOT="${FG_GRAY} · ${R}"

# ─── Output ──────────────────────────────────────────────────────────────────
LINE1="${S}${M}${V}"
LINE2=" ${CTX}${DOT}${ART_FMT}${DOT}${SUB_FMT}${DOT}${BG_FMT}${DOT}${SB}"

if [ "$COLS" -ge 120 ]; then
  # Wide: single line
  printf "%s\n" "${LINE1}${FG_GRAY}  │  ${R}${LINE2}"
elif [ "$COLS" -ge 80 ]; then
  # Medium: two-line layout with border
  printf "%s\n" "${FG_GRAY}╭─${R} ${LINE1}"
  printf "%s\n" "${FG_GRAY}╰─${R}${LINE2}"
else
  # Narrow: compact two-line, minimal chrome
  # Include critical info (State, Model, Branch, Context, Sandbox)
  printf "%s\n" "${S}${M}${V}"
  # Dynamically render only active stats (> 0) to avoid screen clutter on narrow Termux displays
  STATS_LIST=""
  if [ "$ARTIFACTS" -gt 0 ]; then
    STATS_LIST="${ART_FMT}"
  fi
  if [ "$SUBAGENTS" -gt 0 ]; then
    if [ -n "$STATS_LIST" ]; then
      STATS_LIST="${STATS_LIST}${DOT}${SUB_FMT}"
    else
      STATS_LIST="${SUB_FMT}"
    fi
  fi
  if [ "$BG_TASKS" -gt 0 ]; then
    if [ -n "$STATS_LIST" ]; then
      STATS_LIST="${STATS_LIST}${DOT}${BG_FMT}"
    else
      STATS_LIST="${BG_FMT}"
    fi
  fi

  if [ -n "$STATS_LIST" ]; then
    printf "%s\n" "${CTX}${DOT}${STATS_LIST}${DOT}${SB}"
  else
    printf "%s\n" "${CTX}${DOT}${SB}"
  fi
fi
