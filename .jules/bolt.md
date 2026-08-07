# Bolt's Journal

## 2025-05-24 - [Overhead in Progress Bars]
**Learning:** Shell scripts often use external tools like `awk` or `bc` for simple arithmetic and string formatting inside high-frequency loops (like progress bars). Spawning a new process every 100-200ms adds significant CPU overhead and can make the UI feel "heavy" or laggy on resource-constrained environments like Termux.
**Action:** Use Bash built-in arithmetic `$((...))` and string manipulation `${var:offset:length}` to handle formatting and calculations within loops.

## 2025-05-25 - [Command Substitution Truncation and Read Block Failures]
**Learning:** When streaming stdout of commands (like `jq`) through process substitution `<<< "$(command ...)"` under `set -e`, any empty trailing fields may result in trailing newlines being stripped by the `$(...)` command substitution syntax. This causes subsequent `read` commands to encounter EOF and exit with code 1, unexpectedly aborting the script.
**Action:** Append a constant dummy or sentinel value (e.g., `"END"`) as the final line of the streamed command's output, and read it into a discard variable `_`. This guarantees every expected line variable has a corresponding line to read, preventing EOF exit code failures.

## 2026-07-22 - [Process Pipeline Elimination in HTTP Header Parsing]
**Learning:** Replacing external process pipelines (such as `awk` and `tail`) with pure Bash alternatives (like a `while read -r` loop combined with a standard case-insensitive `case` statement) to parse multiline string content (e.g. HTTP response headers) prevents subshell spawns and executes up to 70x faster, particularly on resource-constrained environments like Termux.
**Action:** Use pure Bash multiline parsing loops and parameter expansions for string trimming/extraction instead of piping through external command line utilities like `awk` or `tail`.

## 2026-07-26 - [Avoid Repeated Command Probing in Tight Loops]
**Learning:** Running a fallback chain of command flags (such as trying Linux vs BSD `stat` syntax) inside high-frequency progress bar loops causes massive overhead. On systems where the first option fails, it executes two process spawns on every iteration instead of one.
**Action:** Probe the correct command options once before the loop (e.g. on `/dev/null`) and cache the flags to prevent unnecessary process spawns inside tight loops.

## 2026-07-28 - [Ultra-Fast and Safe Leading-Zero Stripping via Base-10 Arithmetic]
**Learning:** Replacing slow, nested parameter expansions (e.g. `${VAR#${VAR%%[!0]*}}`) used to strip leading zeros in Bash (to avoid octal errors) with native base-10 arithmetic expansions yields a 2.6x performance speedup. However, raw `$((10#$VAR))` will crash with a syntax error if `$VAR` is empty or unset.
**Action:** Always use the robust `$((10#0$VAR))` pattern, prepending a `0` to the variable, which guarantees safe evaluation to `0` even if the variable is empty or unset.

## 2026-07-30 - [Multi-Byte Character Slicing and Locale Sensitivity in Bash]
**Learning:** Using pure Bash string slicing `${VAR:offset:length}` on multi-byte UTF-8 character maps (such as `·░▒▓` used for sub-character progress bar rendering) is highly locale-dependent. In byte-based locales like `C` or `POSIX` (often default in automated environments/CI pipelines), Bash operates on raw bytes, leading to garbled and corrupted terminal outputs due to slicing through multi-byte character sequences.
**Action:** Avoid micro-optimizations that slice multi-byte UTF-8 character strings in Bash. Always prefer standard `if-elif` conditional blocks to assign multi-byte UTF-8 characters robustly.

## 2026-07-31 - [Avoid Replacing Built-ins with Verbose and Incorrect Slicing Logic]
**Learning:** Attempting to optimize standard floating-point formatting like `printf "%.1f"` using Bash parameter expansion can introduce correctness bugs by truncating decimals rather than rounding them (e.g. 45.89 becomes 45.8 instead of 45.9). Moreover, replacing a clear, standard built-in with a complex, multiline block hurts code readability with no measurable real-world performance gain.
**Action:** Respect Bolt's philosophy to never sacrifice readability and correctness for micro-optimizations on cold execution paths.

## 2026-08-05 - [Bypassing Spawning External Tools in Terminal Column Detection]
**Learning:** Checking the native shell `$COLUMNS` environment variable (when it is populated and strictly numeric) before executing external `tput` calls in environment detection completely eliminates process fork/exec overhead.
**Action:** Prioritize native shell variable inspection (with strict validation, e.g. `[[ -n "${COLUMNS:-}" && "$COLUMNS" =~ ^[0-9]+$ ]]`) before falling back to spawning external terminal metadata queries.
