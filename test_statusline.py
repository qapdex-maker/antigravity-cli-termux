#!/usr/bin/env python3
import subprocess
import json
import sys

def run_statusline(payload, terminal_width=80):
    payload = payload.copy()
    payload['terminal_width'] = terminal_width

    proc = subprocess.Popen(
        ['examples/statusline/statusline.sh'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = proc.communicate(input=json.dumps(payload))
    return stdout, stderr, proc.returncode

def main():
    print("Running advanced tests for statusline.sh...")

    payload = {
        "agent_state": "thinking",
        "context_window": {"used_percentage": 95.5},
        "vcs": {"branch": "main", "dirty": True},
        "sandbox": {"enabled": True},
        "artifact_count": 3,
        "subagents": [1],
        "task_count": 2,
        "model": {"display_name": "claude-3-5-sonnet"}
    }

    # 1. Test 120 columns (Wide layout: 1 line)
    stdout, stderr, code = run_statusline(payload, 120)
    assert code == 0, f"Error: {stderr}"
    lines = stdout.strip().split('\n')
    assert len(lines) == 1, f"Expected 1 line for 120 cols, got: {len(lines)}\n{stdout}"
    assert "sandbox" in stdout, "Expected 'sandbox' label in 120 cols output"
    assert "artifacts" in stdout, "Expected 'artifacts' label in 120 cols output"
    print("✅ 120 cols (wide) uses 1 line and contains full labels.")

    # 2. Test 80 columns (Medium layout: 2 lines)
    stdout, stderr, code = run_statusline(payload, 80)
    assert code == 0, f"Error: {stderr}"
    lines = stdout.strip().split('\n')
    assert len(lines) == 2, f"Expected 2 lines for 80 cols, got: {len(lines)}\n{stdout}"
    assert "sandbox" in stdout, "Expected 'sandbox' label in 80 cols output"
    assert "artifacts" in stdout, "Expected 'artifacts' label in 80 cols output"
    print("✅ 80 cols (medium) uses 2 lines and contains full labels.")

    # 3. Test 50 columns (Narrow layout: 2 lines)
    stdout, stderr, code = run_statusline(payload, 50)
    assert code == 0, f"Error: {stderr}"
    lines = stdout.strip().split('\n')
    assert len(lines) == 2, f"Expected 2 lines for 50 cols, got: {len(lines)}\n{stdout}"

    # Ensure compact mode is active: full labels should be omitted
    assert "sandbox " not in stdout, "Unexpected 'sandbox' label in narrow 50 cols output"
    assert "artifacts" not in stdout, "Unexpected 'artifacts' label in narrow 50 cols output"
    assert "subagents" not in stdout, "Unexpected 'subagents' label in narrow 50 cols output"
    assert "tasks" not in stdout, "Unexpected 'tasks' label in narrow 50 cols output"

    # Emojis/Icons and values should still be present
    assert "📦" in stdout, "Expected '📦' icon in narrow output"
    assert "👥" in stdout, "Expected '👥' icon in narrow output"
    assert "📋" in stdout, "Expected '📋' icon in narrow output"
    assert "🔒 ON" in stdout or "🔓 OFF" in stdout, "Expected sandbox lock icon state in narrow output"
    print("✅ 50 cols (narrow) uses 2 lines and correctly uses compact representation (no text labels).")

    # 4. Test new agent states: cancelled, stopped, interrupted
    payload_cancelled = payload.copy()
    payload_cancelled["agent_state"] = "cancelled"
    stdout_c, _, code_c = run_statusline(payload_cancelled, 80)
    assert code_c == 0
    assert "CANCELLED" in stdout_c or "🛑" in stdout_c, "Expected 'CANCELLED' state in statusline"

    payload_stopped = payload.copy()
    payload_stopped["agent_state"] = "stopped"
    stdout_s, _, code_s = run_statusline(payload_stopped, 80)
    assert code_s == 0
    assert "STOPPED" in stdout_s or "🛑" in stdout_s, "Expected 'STOPPED' state in statusline"

    payload_interrupted = payload.copy()
    payload_interrupted["agent_state"] = "interrupted"
    stdout_i, _, code_i = run_statusline(payload_interrupted, 80)
    assert code_i == 0
    assert "STOPPED" in stdout_i or "🛑" in stdout_i, "Expected 'STOPPED' state in statusline"
    print("✅ New cancelled, stopped, and interrupted states are verified.")

    # Test 5: Null byte injection mitigation
    payload_null = payload.copy()
    payload_null["vcs"] = {"branch": "main\u0000true\u0000", "dirty": False}
    payload_null["model"] = {"display_name": "claude\u0000sonnet"}
    stdout_n, stderr_n, code_n = run_statusline(payload_null, 80)
    assert code_n == 0, f"Error: {stderr_n}"
    # If the null byte injection was successful, vcs_dirty would be hijacked to "true".
    # Since we strip null bytes, vcs_dirty should remain false, so the dirty indicator "*" should not be printed.
    assert "*" not in stdout_n, f"Expected vcs_dirty to remain false and no '*' in statusline, got: {stdout_n}"
    assert "claudesonnet" in stdout_n, f"Expected null bytes to be stripped from model name, got: {stdout_n}"
    assert "maintrue" in stdout_n, f"Expected null bytes to be stripped from branch name, got: {stdout_n}"
    print("✅ Test 5 Passed: Null byte injection and field misalignment mitigated in statusline.")

    # 6. Test context window caution & critical alerts (multi-dimensional accessibility cues)
    # High: >= 90% -> ⚠️
    payload_high = payload.copy()
    payload_high["context_window"] = {"used_percentage": 92.0}
    stdout_high, _, code_high = run_statusline(payload_high, 80)
    assert code_high == 0
    assert "⚠️" in stdout_high, "Expected warning icon (⚠️) for high context usage (>= 90%)"
    assert "⚡" not in stdout_high, "Unexpected caution icon (⚡) for high context usage (>= 90%)"

    # Caution: 60% <= pct < 90% -> ⚡
    payload_caution = payload.copy()
    payload_caution["context_window"] = {"used_percentage": 75.0}
    stdout_caution, _, code_caution = run_statusline(payload_caution, 80)
    assert code_caution == 0
    assert "⚡" in stdout_caution, "Expected caution icon (⚡) for moderate context usage (60%-90%)"
    assert "⚠️" not in stdout_caution, "Unexpected warning icon (⚠️) for moderate context usage (60%-90%)"

    # Normal: < 60% -> no emoji
    payload_normal = payload.copy()
    payload_normal["context_window"] = {"used_percentage": 45.0}
    stdout_normal, _, code_normal = run_statusline(payload_normal, 80)
    assert code_normal == 0
    assert "⚠️" not in stdout_normal, "Unexpected warning icon (⚠️) for normal context usage (< 60%)"
    assert "⚡" not in stdout_normal, "Unexpected caution icon (⚡) for normal context usage (< 60%)"
    print("✅ 6. Multi-dimensional context window alerts/cues (⚠️ for >= 90%, ⚡ for 60-90%) verified.")

    print("All tests passed successfully!")

if __name__ == '__main__':
    main()
