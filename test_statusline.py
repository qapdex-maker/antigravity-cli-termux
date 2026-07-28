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

    print("All tests passed successfully!")

if __name__ == '__main__':
    main()
