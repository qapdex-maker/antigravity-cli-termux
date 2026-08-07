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

## 2026-07-19 - CRLF Carriage Return Stripping for Robust Shell Parsing
**Vulnerability:** Untrusted JSON payloads containing Windows-style CRLF (`\r\n`) line endings can lead to carriage returns (`\r`) being preserved inside Bash variables, causing hidden control character injection, validation bypasses, or terminal output corruption.
**Learning:** When multiline outputs from JSON tools (like `jq`) are piped into `read` blocks, trailing carriage returns are not automatically stripped by Bash and persist in parsed variable values.
**Prevention:** Always filter intermediate command outputs or JSON-parsed streams through `tr -d '\r'` before reading them into shell variables.

## 2026-07-21 - Line-Injection and Variable Misalignment in Multi-Field Shell Parsing
**Vulnerability:** Multi-field JSON outputs parsed by Bash using standard newline-delimited `read` blocks can be manipulated if any field contains embedded newlines (such as directory or git branch names), shifting succeeding lines and overriding critical system state variables like sandbox status.
**Learning:** Standard line-by-line `read` blocks assume fields never contain newlines. A malicious branch name with newlines can craft input that overrides variables parsed after it.
**Prevention:** Always output fields null-delimited (using `jq -j` and `\u0000`) and consume them safely with `read -d '' -r`.

## 2026-07-23 - Bash Octal Arithmetic Interpretation and Bypass Vulnerability via Leading Zeros
**Vulnerability:** Numeric strings parsed from JSON or external sources containing leading zeros (e.g. "08", "09") trigger "value too great for base" errors inside Bash double-bracket comparisons (`[[ ... ]]`) and arithmetic expansions (`$(( ... ))`). This can cause script execution to halt, fallback behavior to fail, or bypass validation checks entirely.
**Learning:** Bash treats any numeric literal with a leading zero as an octal value. Characters `8` and `9` are invalid in octal, resulting in shell crashes or unexpected validation behavior.
**Prevention:** Always sanitize numeric variables by stripping leading zeros using pure Bash parameter expansion (`val="${val#${val%%[!0]*}}"`, then defaulting to a safe fallback like `0`) before using them in comparisons or arithmetic expansions.

## 2026-07-25 - Insecure Temporary File Creation and Symlink Attack Vulnerability
**Vulnerability:** Use of predictable, hardcoded temporary file paths and extraction directories in a shared `/tmp` directory.
**Learning:** Using hardcoded paths for temporary files or directories (such as `TMP` and `EXTRACT_DIR` inside `/tmp` or `${PREFIX}/tmp`) makes the script vulnerable to symlink attacks, arbitrary file overwriting, and race conditions (CWE-377, CWE-59) by other local users on a shared system.
**Prevention:** Always use `mktemp -d` to securely create a unique temporary directory with restricted `0700` permissions (readable/writable only by the owner), and place all temporary files and extraction directories within it.

## 2026-07-31 - Environment Variable Hijacking and Arbitrary File Destruction via Trap Cleanup Logic
**Vulnerability:** Uninitialized critical variables in shell scripts (e.g., `ANTIGRAVITY_BAK`, `INSTALL_BIN_DIR`) can be hijacked from the parent environment, allowing users/attackers to manipulate execution flows. When coupled with script-level cleanup traps (like moving or deleting backup files on exit/cancel), uninitialized environment variables can lead to arbitrary file move or deletion operations (CWE-377, CWE-59, CWE-459).
**Learning:** Trap handlers in shell scripts run on any exit or cancellation. If the script fails or exits before variables are initialized inside the script body, pre-existing environment variables of the same name can control file operations inside the trap handler.
**Prevention:** Always explicitly initialize critical shell variables controlling backup paths, installation folders, or temporary locations at the very beginning of the script body. Additionally, validate that target variables are non-empty before executing state-altering commands like `mv` or `rm`.

## 2026-08-01 - Format Injection and Terminal Escape Sequence Injection via printf %b with Dynamic Inputs
**Vulnerability:** Using `printf "%b"` to output text containing dynamic, user-controlled variables (like model names, branch names, or install paths) can expose terminal sessions to escape sequence or format injection vulnerabilities if those variables contain backslashes.
**Learning:** When using `%b`, `printf` interprets any backslash-escape sequence present inside the corresponding argument. If untrusted input variables containing backslashes (e.g., `\033...`) are passed to `%b`, they are interpreted and evaluated as raw terminal escape codes, bypassing whitelists and causing arbitrary visual manipulation or terminal attacks.
**Prevention:** Avoid using `%b` for rendering dynamic variables. Define static style/color escape variables using Bash's native ANSI-C quoting syntax (e.g., `R=$'\033[0m'`) so they are evaluated once at definition time, and safely print all dynamic variables using the standard `printf "%s"` format specifier.

## 2026-08-03 - Secure Validation of mktemp Temporary Directory Creation
**Vulnerability:** Failing to validate that a dynamically created temporary directory (such as via `mktemp -d`) is non-empty and actually exists before defining downstream paths or executing file operations.
**Learning:** If `mktemp -d` fails (due to a full disk or environment issues) and returns an empty string, downstream path variables (e.g., `TMP="${SECURE_TMP_DIR}/..."`) can resolve relative to the root path (`/...`), which can lead to writing to or destroying files in unintended directory locations during cleanup/traps.
**Prevention:** Always validate that the directory variable is non-empty and actually exists (e.g., `[[ -z "${SECURE_TMP_DIR:-}" || ! -d "$SECURE_TMP_DIR" ]]`) immediately after its creation, exiting with an error if validation fails.

## 2026-08-05 - Null Byte Injection and Field Misalignment in Multi-Field Shell Parsing
**Vulnerability:** When parsing multi-field JSON outputs in Bash using null-delimited `read -d ''` blocks, any dynamic string field containing embedded null bytes (`\u0000`) can prematurely terminate a field. This causes the remaining string segments to shift into subsequent variables, leading to state spoofing or variable hijacking.
**Learning:** Standard null-delimited parsing assumes fields do not contain embedded null characters. However, if dynamic inputs (e.g. branch names, model names, directory paths) contain embedded null bytes, `read -d ''` splits on those embedded nulls and shifts succeeding fields.
**Prevention:** Always convert each JSON-extracted field using `tostring` and strip out null characters with `gsub("\u0000"; "")` inside the `jq` filter itself before emitting and parsing them.
