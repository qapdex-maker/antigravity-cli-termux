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
