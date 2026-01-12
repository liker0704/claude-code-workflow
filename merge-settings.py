#!/usr/bin/env python3
"""Merge orchestrator hooks into existing settings.json"""

import json
import sys
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

    # Check if hook already exists
    pre_tool_use = settings["hooks"]["PreToolUse"]
    for hook in pre_tool_use:
        if isinstance(hook, dict) and hook.get("matcher") == "Write":
            for h in hook.get("hooks", []):
                if "validate-orchestrate-files.py" in h.get("command", ""):
                    print("SKIP: Hook already exists")
                    return 0

    # Add hook
    pre_tool_use.append(ORCHESTRATOR_HOOK)

    # Save
    with open(SETTINGS_FILE, "w") as f:
        json.dump(settings, f, indent=2)

    print("OK: Hook added to settings.json")
    return 0

if __name__ == "__main__":
    sys.exit(main())
