#!/usr/bin/env python3
"""Merge orchestrator hooks into existing settings.json"""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

SETTINGS_FILE = Path.home() / ".claude" / "settings.json"

ORCHESTRATOR_HOOK = {
    "matcher": "Write",
    "hooks": [{
        "type": "command",
        "command": "python3 ~/.claude/validators/validate-orchestrate-files.py",
        "timeout": 5000
    }]
}

SESSION_HOOKS = {
    "SessionStart": [{
        "hooks": [{
            "type": "command",
            "command": "python3 ~/.claude/hooks/session-start.py"
        }]
    }],
    "SessionEnd": [{
        "hooks": [{
            "type": "command",
            "command": "python3 ~/.claude/hooks/session-end.py"
        }]
    }]
}

def atomic_write_json(path, data):
    """Write JSON atomically: write to temp file, then rename"""
    dir_path = path.parent
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp", prefix=".settings-")
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_path, path)
    except Exception:
        # Clean up temp file on failure
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

def backup_settings(path):
    """Create a backup of settings.json before modification"""
    if not path.exists():
        return
    backup = path.with_suffix('.json.bak')
    shutil.copy2(path, backup)

def main():
    # Load existing settings or create empty
    if SETTINGS_FILE.exists():
        with open(SETTINGS_FILE) as f:
            settings = json.load(f)
    else:
        settings = {}

    # Ensure hooks structure exists
    if "hooks" not in settings:
        settings["hooks"] = {}
    if "PreToolUse" not in settings["hooks"]:
        settings["hooks"]["PreToolUse"] = []

    # Track changes
    changes = []

    # Check if PreToolUse hook already exists
    pre_tool_use = settings["hooks"]["PreToolUse"]
    hook_exists = False
    for hook in pre_tool_use:
        if isinstance(hook, dict) and hook.get("matcher") == "Write":
            for h in hook.get("hooks", []):
                if "validate-orchestrate-files.py" in h.get("command", ""):
                    hook_exists = True
                    break

    if not hook_exists:
        pre_tool_use.append(ORCHESTRATOR_HOOK)
        changes.append("PreToolUse (orchestrator validator)")

    # Add SessionStart hook if not exists
    if "SessionStart" not in settings["hooks"]:
        settings["hooks"]["SessionStart"] = []

    session_start_exists = False
    for hook in settings["hooks"]["SessionStart"]:
        for h in hook.get("hooks", []):
            if "session-start.py" in h.get("command", ""):
                session_start_exists = True
                break

    if not session_start_exists:
        settings["hooks"]["SessionStart"].extend(SESSION_HOOKS["SessionStart"])
        changes.append("SessionStart (restore context)")

    # Add SessionEnd hook if not exists
    if "SessionEnd" not in settings["hooks"]:
        settings["hooks"]["SessionEnd"] = []

    session_end_exists = False
    for hook in settings["hooks"]["SessionEnd"]:
        for h in hook.get("hooks", []):
            if "session-end.py" in h.get("command", ""):
                session_end_exists = True
                break

    if not session_end_exists:
        settings["hooks"]["SessionEnd"].extend(SESSION_HOOKS["SessionEnd"])
        changes.append("SessionEnd (persist state)")

    # Report results
    if not changes:
        print("SKIP: All hooks already exist")
        return 0

    # Backup existing file before modification
    backup_settings(SETTINGS_FILE)

    # Atomic write
    atomic_write_json(SETTINGS_FILE, settings)

    print(f"OK: Added hooks: {', '.join(changes)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
