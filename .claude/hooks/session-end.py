#!/usr/bin/env python3
"""Session end hook - persist current session state"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime, timezone

SESSION_FILE = Path.home() / ".cache" / "claude-code" / "sessions" / "last-session.json"

def get_project_dir():
    """Get project directory from args, env var, or cwd"""
    # 1. Explicit CLI argument
    if len(sys.argv) > 1 and os.path.isdir(sys.argv[1]):
        return sys.argv[1]

    # 2. Claude Code environment variables
    for var in ('CLAUDE_PROJECT_DIR', 'PROJECT_DIR', 'INIT_CWD'):
        val = os.environ.get(var)
        if val and os.path.isdir(val):
            return val

    # 3. Fallback to cwd
    return os.getcwd()

def find_active_task(cwd):
    """Find active task from tmp/.orchestrate/*/task.md"""
    orchestrate_dir = Path(cwd) / "tmp" / ".orchestrate"

    if not orchestrate_dir.exists():
        return None

    try:
        for task_file in orchestrate_dir.glob("*/task.md"):
            try:
                content = task_file.read_text()

                # Extract status
                status = None
                for line in content.split('\n'):
                    if line.startswith('Status:'):
                        status = line.split(':', 1)[1].strip()
                        break

                # Only care about executing or planning tasks
                if status in ('executing', 'planning'):
                    task_name = task_file.parent.name
                    return {
                        'task_slug': task_name,
                        'phase': status,
                        'cwd': str(cwd)
                    }
            except Exception:
                continue
    except Exception:
        pass

    return None

def save_session(session_data):
    """Save session data to cache"""
    try:
        # Create directory if needed
        SESSION_FILE.parent.mkdir(parents=True, exist_ok=True)

        # Add timestamp
        session_data['timestamp'] = datetime.now(timezone.utc).isoformat()

        # Write session file
        with open(SESSION_FILE, 'w') as f:
            json.dump(session_data, f, indent=2)

        return True
    except Exception:
        return False

def main():
    cwd = get_project_dir()

    # Find active task
    task = find_active_task(cwd)

    if not task:
        # No active task, but don't fail
        return 0

    # Save session
    save_session(task)
    return 0

if __name__ == "__main__":
    try:
        exit(main())
    except Exception:
        # Fail silently
        exit(0)
