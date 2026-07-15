#!/bin/bash
set -euo pipefail

# ─── ANSI Helpers (Standard 16-color palette only) ───────────────────────────
R="\033[0m"         # Reset
B="\033[1m"         # Bold
D="\033[2m"         # Dim
I="\033[3m"         # Italic

# Foreground accents (Standard 16 colors)
FG_BLACK="\033[30m"
FG_RED="\033[31m"
FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_BLUE="\033[34m"
FG_MAGENTA="\033[35m"
FG_CYAN="\033[36m"
FG_WHITE="\033[37m"

FG_GRAY="\033[90m"
FG_BRIGHT_RED="\033[91m"
FG_BRIGHT_GREEN="\033[92m"
FG_BRIGHT_YELLOW="\033[93m"
FG_BRIGHT_BLUE="\033[94m"
FG_BRIGHT_MAGENTA="\033[95m"
FG_BRIGHT_CYAN="\033[96m"
FG_BRIGHT_WHITE="\033[97m"

# Number Highlight Color
NUM_COLOR="${FG_BRIGHT_WHITE}${B}"

# ─── Parse JSON from stdin (Single jq pass for performance) ──────────────────
# Extract all fields in one pass to prevent spawning jq 8 times.
{
  read -r STATE
  read -r USED_PCT
  read -r VCS_BRANCH
  read -r VCS_DIRTY
  read -r SANDBOX
  read -r ARTIFACTS
  read -r SUBAGENTS
  read -r BG_TASKS
  read -r MODEL
  read -r COLS
} <<< "$(
  jq -r '
    (.agent_state // "idle"),
    (.context_window.used_percentage // 0),
    (.vcs.branch // ""),
    (.vcs.dirty // false),
    (.sandbox.enabled // false),
    (.artifact_count // 0),
    (if .subagents | type == "array" then (.subagents | length) else 0 end),
    (.task_count // 0),
    (.model.display_name // ""),
    (.terminal_width // 80)
  ' 2>/dev/null || printf "idle\n0\n\nfalse\nfalse\n0\n0\n0\n\n80\n"
)"

# ─── Input Validation & Sanitization ─────────────────────────────────────────
# Ensure variables are strictly validated and sanitized to prevent terminal/option injection.
RE_PCT='^[0-9]*\.?[0-9]+$'
[[ ! "$USED_PCT" =~ $RE_PCT ]] && USED_PCT=0

[[ "$STATE"      == *[!a-zA-Z0-9_-]* || -z "$STATE" ]] && STATE="idle"
[[ "$VCS_BRANCH" == *[!a-zA-Z0-9_./-]* ]] && VCS_BRANCH=""
[[ "$VCS_DIRTY"  != "true" && "$VCS_DIRTY" != "false" ]] && VCS_DIRTY="false"
[[ "$SANDBOX"    != "true" && "$SANDBOX" != "false" ]] && SANDBOX="false"
[[ "$ARTIFACTS"  == *[!0-9]* || -z "$ARTIFACTS" ]] && ARTIFACTS=0
[[ "$SUBAGENTS"  == *[!0-9]* || -z "$SUBAGENTS" ]] && SUBAGENTS=0
[[ "$BG_TASKS"   == *[!0-9]* || -z "$BG_TASKS" ]] && BG_TASKS=0
[[ "$MODEL"      == *[!a-zA-Z0-9_./\ -]* ]] && MODEL=""
[[ "$COLS"       == *[!0-9]* || -z "$COLS" ]] && COLS=80

# ─── Computed Values ─────────────────────────────────────────────────────────
# Use LC_NUMERIC=C and printf -v to prevent fork overhead and locale errors
LC_NUMERIC=C printf -v PCT_FMT "%.1f" "$USED_PCT"
PCT_INT=${USED_PCT%.*}; PCT_INT=${PCT_INT:-0}
[[ ! "$PCT_INT"    =~ ^[0-9]+$ ]] && PCT_INT=0

# ─── State Indicator (No background colors) ──────────────────────────────────
case "$STATE" in
  idle)     S="${FG_BRIGHT_GREEN}${B}● READY${R}" ;;
  thinking) S="${FG_BRIGHT_YELLOW}${B}◆ THINKING${R}" ;;
  working)  S="${FG_BRIGHT_CYAN}${B}⚙ WORKING${R}" ;;
  tool_use) S="${FG_BRIGHT_MAGENTA}${B}🔧 TOOL${R}" ;;
  *)        S="${FG_WHITE}${B}⏳ ${STATE^^}${R}" ;;
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
    V="${FG_GRAY} ╱ ${FG_BRIGHT_RED}${DISPLAY_BRANCH}${FG_BRIGHT_YELLOW}*${R}"
  else
    V="${FG_GRAY} ╱ ${FG_BRIGHT_BLUE}${DISPLAY_BRANCH}${R}"
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
    M="${FG_GRAY} ╱ ${FG_BRIGHT_MAGENTA}${I}${DISPLAY_MODEL}${R}"
  fi
fi

# ─── Sandbox Badge ───────────────────────────────────────────────────────────
if [ "$SANDBOX" = "true" ]; then
  SB="${FG_GRAY}sandbox ${FG_BRIGHT_GREEN}${B}ON${R}"
else
  SB="${FG_GRAY}sandbox off${R}"
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

# Build bar with partial-fill last block
BAR=""
for ((i = 0; i < BAR_LEN; i++)); do
  if [ "$i" -lt "$FILLED" ]; then
    BAR="${BAR}█"
  elif [ "$i" -eq "$FILLED" ]; then
    if [ "$REMAINDER" -ge 75 ]; then
      BAR="${BAR}▓"
    elif [ "$REMAINDER" -ge 50 ]; then
      BAR="${BAR}▒"
    elif [ "$REMAINDER" -ge 25 ]; then
      BAR="${BAR}░"
    else
      BAR="${BAR}·"
    fi
  else
    BAR="${BAR}·"
  fi
done

# ─── Stats ───────────────────────────────────────────────────────────────────
# Match context percentage text color with warning color for high usage (red/yellow/white)
CTX_PCT_COLOR="${BAR_COLOR}${B}"
CTX="${FG_GRAY}ctx ${BAR_COLOR}${BAR} ${CTX_PCT_COLOR}${PCT_FMT}%${R}"

# Dim zeros for better visual hierarchy without spawning subshells
ART_COLOR="$FG_GRAY"; [ "$ARTIFACTS" -gt 0 ] && ART_COLOR="$NUM_COLOR"
SUB_COLOR="$FG_GRAY"; [ "$SUBAGENTS" -gt 0 ] && SUB_COLOR="$NUM_COLOR"
TAS_COLOR="$FG_GRAY"; [ "$BG_TASKS" -gt 0 ] && TAS_COLOR="$NUM_COLOR"

ART_FMT="${FG_GRAY}artifacts ${ART_COLOR}${ARTIFACTS}${R}"
SUB_FMT="${FG_GRAY}subagents ${SUB_COLOR}${SUBAGENTS}${R}"
BG_FMT="${FG_GRAY}tasks ${TAS_COLOR}${BG_TASKS}${R}"

# ─── Separators ──────────────────────────────────────────────────────────────
DOT="${FG_GRAY} · ${R}"

# ─── Output ──────────────────────────────────────────────────────────────────
LINE1="${S}${M}${V}"
LINE2=" ${CTX}${DOT}${ART_FMT}${DOT}${SUB_FMT}${DOT}${BG_FMT}${DOT}${SB}"

if [ "$COLS" -ge 120 ]; then
  # Wide: single line
  echo -e "${LINE1}${FG_GRAY}  │  ${R}${LINE2}"
elif [ "$COLS" -ge 80 ]; then
  # Medium: two-line layout with border
  echo -e "${FG_GRAY}╭─${R} ${LINE1}"
  echo -e "${FG_GRAY}╰─${R}${LINE2}"
else
  # Narrow: compact two-line, minimal chrome
  # Include critical info (State, Model, Branch, Context, Sandbox)
  echo -e "${S}${M}${V}"
  echo -e "${CTX}${DOT}${BG_FMT}${DOT}${SB}"
fi
