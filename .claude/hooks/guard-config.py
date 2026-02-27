#!/usr/bin/env python3
"""ConfigChange hook: audit settings changes.

Logs all settings modifications for transparency.
Does NOT block any changes (exit 0 always).
"""

import json
import os
import sys
from datetime import datetime, timezone

LOG_DIR = os.path.expanduser("~/.local/share/claude-code-workflow")
LOG_FILE = os.path.join(LOG_DIR, "config-changes.log")


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    source = data.get("source", "unknown")
    file_path = data.get("file_path", "")
    timestamp = datetime.now(timezone.utc).isoformat()

    os.makedirs(LOG_DIR, exist_ok=True)

    entry = f"[{timestamp}] source={source} file={file_path}\n"

    try:
        with open(LOG_FILE, "a") as f:
            f.write(entry)
    except OSError:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
