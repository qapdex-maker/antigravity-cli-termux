# Sentinel's Journal - Critical Security Learnings

## 2026-07-06 - Command Injection via eval in Bash
**Vulnerability:** Use of `eval` on untrusted JSON data parsed via `jq` in shell scripts.
**Learning:** Parsing JSON into shell variables using `eval $(jq ...)` is dangerous because the data itself can contain shell commands or variable assignments that the shell will then execute.
**Prevention:** Use `read` or other safe parsing methods to assign variables from `jq` output without executing them.

## 2026-07-08 - Shell Arithmetic Injection in Bash
**Vulnerability:** Use of untrusted string variables in shell arithmetic expansion `$(( ... ))` or numeric comparisons.
**Learning:** Bash treats strings in arithmetic context as variable names or expressions, allowing arbitrary command execution if the string contains patterns like `a[$(command)]0`.
**Prevention:** Always validate that variables used in arithmetic context are strictly numeric using regex (e.g., `[[ $VAR =~ ^[0-9]+$ ]]`).

## 2026-07-10 - Terminal and Option Injection in Shell Outputs
**Vulnerability:** Untrusted string inputs (such as Git branch names or current directory paths) parsed from JSON payloads printed with `echo -e` or passed to commands like `basename` without option separators (`--`).
**Learning:** This allows malicious or unexpected data to inject terminal escape sequences or pass options (such as `-v` or those starting with `-`) to external commands.
**Prevention:** Whitelist and sanitize all string inputs via POSIX-compatible glob-based pattern validation, prefer `printf` over `echo`, and replace external commands with pure Bash parameter expansions to completely eliminate process-spawn overhead and injection vectors.

## 2026-07-12 - Environment and Arithmetic Input Validation in Installer Scripts
**Vulnerability:** Shell installer scripts using external environment variables (`ANTIGRAVITY_REPO`, `ANTIGRAVITY_INSTALL_URL`) or dynamically computed terminal width/file sizes (`cols`, `current_size`, `total_size`) in arithmetic expressions `$(( ... ))` or external curl commands without character-level validation. This could allow malicious environment configurations to inject commands or arbitrary shell arithmetic code execution.
**Learning:** Unsanitized variables inside shell arithmetic expansions are evaluated by Bash, enabling command execution. Environment-provided URLs or repos can also introduce option injections into tools like `curl`.
**Prevention:** Validate environment-provided variables with strict character white-lists (using POSIX glob-based validation `[[ $VAR == *[!a-zA-Z0-9_.-]* ]]`) and ensure dynamically retrieved variables are strictly numeric before applying them in shell arithmetic expansions.
