#!/usr/bin/env python3
import subprocess
import json
import sys

def run_title(payload):
    proc = subprocess.Popen(
        ['examples/title/title.sh'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = proc.communicate(input=json.dumps(payload))
    return stdout, stderr, proc.returncode

def main():
    print("Running advanced tests for title.sh...")

    # Test 1: Standard Idle State on sandbox enabled
    payload1 = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/myproject"},
        "sandbox": {"enabled": True}
    }
    stdout, stderr, code = run_title(payload1)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "🟢 Idle | myproject" in title, f"Expected idle & myproject, got: {title}"
    assert "🔒 Sandbox ON" in title, f"Expected sandbox enabled, got: {title}"
    print("✅ Test 1 Passed: Idle, clean project path, sandbox ON.")

    # Test 2: Thinking state on Sandbox disabled
    payload2 = {
        "agent_state": "thinking",
        "workspace": {"current_dir": "/google/src/cloud/username/myworkspace/google3/my-feature"},
        "sandbox": {"enabled": False}
    }
    stdout, stderr, code = run_title(payload2)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "🤔 Thinking | myworkspace" in title, f"Expected CitC path mapping, got: {title}"
    assert "🔓 Sandbox OFF" in title, f"Expected sandbox disabled, got: {title}"
    print("✅ Test 2 Passed: Thinking, CitC workspace mapping, sandbox OFF.")

    # Test 3: VCS branch integration (Clean branch)
    payload3 = {
        "agent_state": "working",
        "workspace": {"current_dir": "/home/user/repo"},
        "sandbox": {"enabled": True},
        "vcs": {"branch": "feature-abc", "dirty": False}
    }
    stdout, stderr, code = run_title(payload3)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "🏃 Working | repo (🌿 feature-abc) (🔒 Sandbox ON)" in title, f"Expected clean branch info, got: {title}"
    print("✅ Test 3 Passed: VCS clean branch badge.")

    # Test 4: VCS branch integration (Dirty branch)
    payload4 = {
        "agent_state": "working",
        "workspace": {"current_dir": "/home/user/repo"},
        "sandbox": {"enabled": True},
        "vcs": {"branch": "feature-abc", "dirty": True}
    }
    stdout, stderr, code = run_title(payload4)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "🏃 Working | repo (🌿 feature-abc*) (🔒 Sandbox ON)" in title, f"Expected dirty branch info, got: {title}"
    print("✅ Test 4 Passed: VCS dirty branch badge.")

    # Test 5: Sanitization and safety with malicious VCS branches
    payload5 = {
        "agent_state": "working",
        "workspace": {"current_dir": "/home/user/repo"},
        "sandbox": {"enabled": True},
        "vcs": {"branch": "feature;rm -rf /", "dirty": False}
    }
    stdout, stderr, code = run_title(payload5)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "feature;rm" not in title, f"Expected malicious branch name to be sanitized, got: {title}"
    print("✅ Test 5 Passed: Malicious VCS branch input sanitized successfully.")

    # Test 6: Robust parsing with completely missing .vcs block
    payload6 = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/repo"},
        "sandbox": {"enabled": True}
        # No "vcs" key at all
    }
    stdout, stderr, code = run_title(payload6)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "🟢 Idle | repo (🔒 Sandbox ON)" in title, f"Expected missing VCS to parse cleanly without errors, got: {title}"
    print("✅ Test 6 Passed: Completely missing VCS parsed cleanly.")

    # Test 7: Branch name truncation (longer than 15 characters)
    payload7_clean = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/repo"},
        "sandbox": {"enabled": True},
        "vcs": {"branch": "feature-extremely-long-name", "dirty": False}
    }
    stdout, stderr, code = run_title(payload7_clean)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "feature-e...ame" in title, f"Expected truncated branch feature-e...ame, got: {title}"
    assert "feature-extremely-long-name" not in title, f"Expected full long branch to be truncated, got: {title}"

    payload7_dirty = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/repo"},
        "sandbox": {"enabled": True},
        "vcs": {"branch": "feature-extremely-long-name", "dirty": True}
    }
    stdout, stderr, code = run_title(payload7_dirty)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    assert "feature-e...ame*" in title, f"Expected dirty truncated branch feature-e...ame*, got: {title}"

    print("✅ Test 7 Passed: VCS branch name (> 15 chars) truncated correctly (clean & dirty).")

    # Test 8: Non-object safety check (Crashes avoidance for corrupted nested objects)
    payload_corrupted = {
        "agent_state": "idle",
        "workspace": "corrupted_string",
        "sandbox": "corrupted_string",
        "vcs": "corrupted_string",
        "model": "corrupted_string"
    }
    stdout_corr, stderr_corr, code_corr = run_title(payload_corrupted)
    assert code_corr == 0, f"Error: {stderr_corr}"
    title_corr = stdout_corr.strip()
    assert "🔓 Sandbox OFF" in title_corr, f"Expected sandbox status to safely fallback to OFF, got: {title_corr}"
    assert "unknown" in title_corr, f"Expected workspace to safely fallback to unknown, got: {title_corr}"
    print("✅ Test 8 Passed: Corrupted nested fields successfully bypassed and handled safely in title.")

    # Test 9: Active model integration (Standard model name)
    payload9 = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/project"},
        "sandbox": {"enabled": True},
        "model": {"display_name": "claude-3-5"}
    }
    stdout9, stderr9, code9 = run_title(payload9)
    assert code9 == 0, f"Error: {stderr9}"
    title9 = stdout9.strip()
    assert "🟢 Idle | project (🧠 claude-3-5) (🔒 Sandbox ON)" in title9, f"Expected standard model display, got: {title9}"
    print("✅ Test 9 Passed: Standard active model displays correctly.")

    # Test 10: Active model integration (Long model name truncation)
    payload10 = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/project"},
        "sandbox": {"enabled": True},
        "model": {"display_name": "gemini-1.5-pro-preview-08"}
    }
    stdout10, stderr10, code10 = run_title(payload10)
    assert code10 == 0, f"Error: {stderr10}"
    title10 = stdout10.strip()
    assert "gemini-1.5-pro-preview-08" not in title10, "Expected full long model to be truncated"
    assert "gemini-1....-08" in title10, f"Expected truncated model name gemini-1....-08, got: {title10}"
    print("✅ Test 10 Passed: Long active model name truncated correctly.")

    # Test 11: Active model integration (Malicious/unsafe model name sanitization and fallback)
    payload11 = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/project"},
        "sandbox": {"enabled": True},
        "model": {"display_name": "gemini;rm -rf /"}
    }
    stdout11, stderr11, code11 = run_title(payload11)
    assert code11 == 0, f"Error: {stderr11}"
    title11 = stdout11.strip()
    assert "gemini;rm" not in title11, "Expected malicious model name to be sanitized and ignored"
    print("✅ Test 11 Passed: Malicious active model name sanitized and ignored successfully.")

    print("All title.sh tests passed successfully!")

if __name__ == '__main__':
    main()
