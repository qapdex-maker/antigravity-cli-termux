# Security Directives for Antigravity CLI Contributors

As an agent or human contributor to this repository, you MUST adhere to the following security standards to prevent common vulnerabilities in shell scripts.

## 🛡️ Bash Security Best Practices

### 1. Prevent Arithmetic Injection
When using variables in shell arithmetic expansion `$(( ... ))` or numeric comparisons (`-gt`, `-lt`, etc.), you MUST validate that the variable is strictly numeric.
Bash treats strings in arithmetic context as variable names or expressions, which can lead to arbitrary command execution.

**❌ BAD (Vulnerable):**
```bash
PCT_INT=${USED_PCT%.*}
FILLED=$((PCT_INT * BAR_LEN / 100))
```

**✅ GOOD (Secure):**
```bash
PCT_INT=${USED_PCT%.*}
[[ ! "$PCT_INT" =~ ^[0-9]+$ ]] && PCT_INT=0
FILLED=$((PCT_INT * BAR_LEN / 100))
```

### 2. Safe JSON Parsing (Avoid `eval`)
NEVER use `eval $(jq ...)` to parse JSON into shell variables. A malicious JSON payload can contain shell commands that `eval` will execute.
Instead, use a safe `read` block with process substitution or here-strings.

**❌ BAD (Vulnerable):**
```bash
eval $(jq -r '@sh "STATE=\(.agent_state)"' <<< "$DATA")
```

**✅ GOOD (Secure):**
```bash
{
  read -r STATE
  read -r USED_PCT
} <<< "$(jq -r '.agent_state, .context_window.used_percentage' <<< "$DATA")"
```

### 3. Safe Piping with Here-Strings
Use here-strings `<<< "$VAR"` instead of `echo "$VAR" | ...` when piping variable content to other commands. This avoids issues with variables containing leading dashes or other shell-special characters.

**❌ BAD:**
```bash
echo "$DATA" | jq .
```

**✅ GOOD:**
```bash
jq . <<< "$DATA"
```

## 🔍 Verification
All new shell scripts or modifications to existing ones MUST be verified for these patterns. If `shellcheck` is available, it should be run as part of the verification process.
