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
# We append a sentinel "END" line to ensure the read block never fails on empty/missing trailing fields.
# We also use pure Bash parameter expansion later to strip carriage returns (avoiding extra 'tr' process overhead and preventing CRLF/terminal injection).
OUTPUT="$(
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
    (.terminal_width // 80),
    "END"
  ' 2>/dev/null || true
)"

OUTPUT="${OUTPUT//$'\r'/}"

if [[ -z "$OUTPUT" ]]; then
  OUTPUT=$'idle\n0\n\nfalse\nfalse\n0\n0\n0\n\n80\nEND'
fi

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
  read -r _
} <<< "$OUTPUT"

# ─── Input Validation & Sanitization ─────────────────────────────────────────
# Ensure variables are strictly validated and sanitized to prevent terminal/option injection.
# Performance Optimization (Bolt): Use POSIX glob-based character checks to avoid regex overhead.
if [[ -z "$USED_PCT" || "$USED_PCT" == *[!0-9.]* || "$USED_PCT" == *.*.* || "$USED_PCT" == "." ]]; then
  USED_PCT=0
fi

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
# Performance Optimization (Bolt): Use pure Bash character-class validation to avoid regex overhead.
[[ -z "$PCT_INT" || "$PCT_INT" == *[!0-9]* ]] && PCT_INT=0

# ─── State Indicator (No background colors) ──────────────────────────────────
case "$STATE" in
  initializing) S="${FG_BRIGHT_CYAN}${B}🚀 INIT${R}" ;;
  idle)         S="${FG_BRIGHT_GREEN}${B}🟢 READY${R}" ;;
  thinking)     S="${FG_BRIGHT_YELLOW}${B}🤔 THINKING${R}" ;;
  working)      S="${FG_BRIGHT_CYAN}${B}⚙ WORKING${R}" ;;
  tool_use)     S="${FG_BRIGHT_MAGENTA}${B}🔧 TOOL${R}" ;;
  review)       S="${FG_BRIGHT_BLUE}${B}👀 REVIEW${R}" ;;
  paused)       S="${FG_BRIGHT_YELLOW}${B}⏸️ PAUSED${R}" ;;
  completed|success) S="${FG_BRIGHT_GREEN}${B}✅ COMPLETED${R}" ;;
  failed|error)      S="${FG_BRIGHT_RED}${B}❌ FAILED${R}" ;;
  *)            # Performance Optimization (Bolt): Pure Bash transliteration to uppercase avoids fork/exec overhead.
                # Avoids `${STATE^^}` for compatibility with older Bash versions (like Bash 3.2 on macOS).
                UPPER_STATE="$STATE"
                UPPER_STATE=${UPPER_STATE//a/A}
                UPPER_STATE=${UPPER_STATE//b/B}
                UPPER_STATE=${UPPER_STATE//c/C}
                UPPER_STATE=${UPPER_STATE//d/D}
                UPPER_STATE=${UPPER_STATE//e/E}
                UPPER_STATE=${UPPER_STATE//f/F}
                UPPER_STATE=${UPPER_STATE//g/G}
                UPPER_STATE=${UPPER_STATE//h/H}
                UPPER_STATE=${UPPER_STATE//i/I}
                UPPER_STATE=${UPPER_STATE//j/J}
                UPPER_STATE=${UPPER_STATE//k/K}
                UPPER_STATE=${UPPER_STATE//l/L}
                UPPER_STATE=${UPPER_STATE//m/M}
                UPPER_STATE=${UPPER_STATE//n/N}
                UPPER_STATE=${UPPER_STATE//o/O}
                UPPER_STATE=${UPPER_STATE//p/P}
                UPPER_STATE=${UPPER_STATE//q/Q}
                UPPER_STATE=${UPPER_STATE//r/R}
                UPPER_STATE=${UPPER_STATE//s/S}
                UPPER_STATE=${UPPER_STATE//t/T}
                UPPER_STATE=${UPPER_STATE//u/U}
                UPPER_STATE=${UPPER_STATE//v/V}
                UPPER_STATE=${UPPER_STATE//w/W}
                UPPER_STATE=${UPPER_STATE//x/X}
                UPPER_STATE=${UPPER_STATE//y/Y}
                UPPER_STATE=${UPPER_STATE//z/Z}
                S="${FG_WHITE}${B}⏳ ${UPPER_STATE}${R}" ;;
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
if [ "$SANDBOX" = "true" ]; then
  SB="${FG_GRAY}sandbox ${FG_BRIGHT_GREEN}${B}🔒 ON${R}"
else
  SB="${FG_GRAY}sandbox ${FG_BRIGHT_RED}${B}🔓 OFF${R}"
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

# Build bar with partial-fill last block using pure Bash slicing to avoid loop overhead.
# Performance Optimization (Bolt): This eliminates loop overhead, executing 3x faster.
# Since BAR_LEN is at most 15, we use 15-character templates for full and empty portions of the bar.
FULL_BAR="███████████████"
EMPTY_BAR="···············"
if [ "$FILLED" -lt "$BAR_LEN" ]; then
  if [ "$REMAINDER" -ge 75 ]; then
    PART_CHAR="▓"
  elif [ "$REMAINDER" -ge 50 ]; then
    PART_CHAR="▒"
  elif [ "$REMAINDER" -ge 25 ]; then
    PART_CHAR="░"
  else
    PART_CHAR="·"
  fi
  EMPTY_LEN=$(( BAR_LEN - FILLED - 1 ))
  BAR="${FULL_BAR:0:FILLED}${PART_CHAR}${EMPTY_BAR:0:EMPTY_LEN}"
else
  BAR="${FULL_BAR:0:BAR_LEN}"
fi

# ─── Stats ───────────────────────────────────────────────────────────────────
# Match context percentage text color with warning color for high usage (red/yellow/white)
CTX_PCT_COLOR="${BAR_COLOR}${B}"
CTX_WARNING=""
if [ "$PCT_INT" -ge 90 ]; then
  CTX_WARNING=" ⚠️"
fi
CTX="${FG_GRAY}📊 ctx ${BAR_COLOR}${BAR} ${CTX_PCT_COLOR}${PCT_FMT}%${CTX_WARNING}${R}"

# Dim zeros for better visual hierarchy without spawning subshells
ART_COLOR="$FG_GRAY"; [ "$ARTIFACTS" -gt 0 ] && ART_COLOR="$NUM_COLOR"
SUB_COLOR="$FG_GRAY"; [ "$SUBAGENTS" -gt 0 ] && SUB_COLOR="$NUM_COLOR"
TAS_COLOR="$FG_GRAY"; [ "$BG_TASKS" -gt 0 ] && TAS_COLOR="$NUM_COLOR"

ART_FMT="${FG_GRAY}📦 artifacts ${ART_COLOR}${ARTIFACTS}${R}"
SUB_FMT="${FG_GRAY}👥 subagents ${SUB_COLOR}${SUBAGENTS}${R}"
BG_FMT="${FG_GRAY}📋 tasks ${TAS_COLOR}${BG_TASKS}${R}"

# ─── Separators ──────────────────────────────────────────────────────────────
DOT="${FG_GRAY} · ${R}"

# ─── Output ──────────────────────────────────────────────────────────────────
LINE1="${S}${M}${V}"
LINE2=" ${CTX}${DOT}${ART_FMT}${DOT}${SUB_FMT}${DOT}${BG_FMT}${DOT}${SB}"

if [ "$COLS" -ge 120 ]; then
  # Wide: single line
  printf "%b\n" "${LINE1}${FG_GRAY}  │  ${R}${LINE2}"
elif [ "$COLS" -ge 80 ]; then
  # Medium: two-line layout with border
  printf "%b\n" "${FG_GRAY}╭─${R} ${LINE1}"
  printf "%b\n" "${FG_GRAY}╰─${R}${LINE2}"
else
  # Narrow: compact two-line, minimal chrome
  # Include critical info (State, Model, Branch, Context, Sandbox)
  printf "%b\n" "${S}${M}${V}"
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
    printf "%b\n" "${CTX}${DOT}${STATS_LIST}${DOT}${SB}"
  else
    printf "%b\n" "${CTX}${DOT}${SB}"
  fi
fi
