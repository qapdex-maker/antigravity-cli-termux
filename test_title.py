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

    # Test 7: Null byte injection mitigation
    payload7 = {
        "agent_state": "idle",
        "workspace": {"current_dir": "/home/user/project\u0000false\u0000"},
        "sandbox": {"enabled": True},
        "vcs": {"branch": "main\u0000dirty\u0000", "dirty": False}
    }
    stdout, stderr, code = run_title(payload7)
    assert code == 0, f"Error: {stderr}"
    title = stdout.strip()
    # If the null byte injection was successful, Sandbox would have been hijacked to OFF.
    # We assert that Sandbox is still ON (🔒 Sandbox ON) and branch was not misaligned.
    assert "🔒 Sandbox ON" in title, f"Expected sandbox to remain ON despite null byte injection, got: {title}"
    assert "projectfalse" in title, f"Expected null bytes to be stripped/removed from directory, got: {title}"
    assert "maindirty" in title, f"Expected null bytes to be stripped/removed from branch, got: {title}"
    print("✅ Test 7 Passed: Null byte injection and field misalignment mitigated.")

    print("All title.sh tests passed successfully!")

if __name__ == '__main__':
    main()
