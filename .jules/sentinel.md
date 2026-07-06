# Sentinel's Journal - Critical Security Learnings

## 2026-07-06 - Command Injection via eval in Bash
**Vulnerability:** Use of `eval` on untrusted JSON data parsed via `jq` in shell scripts.
**Learning:** Parsing JSON into shell variables using `eval $(jq ...)` is dangerous because the data itself can contain shell commands or variable assignments that the shell will then execute.
**Prevention:** Use `read` or other safe parsing methods to assign variables from `jq` output without executing them.
