#!/usr/bin/env python3
"""Session start hook - load and display previous session context"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

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

def load_session():
    """Load last session info if exists"""
    if not SESSION_FILE.exists():
        return None

    try:
        with open(SESSION_FILE) as f:
            return json.load(f)
    except Exception:
        return None

def find_active_tasks(cwd):
    """Find active orchestrate tasks in tmp/.orchestrate/*/task.md"""
    tasks = []
    orchestrate_dir = Path(cwd) / "tmp" / ".orchestrate"

    if not orchestrate_dir.exists():
        return tasks

    try:
        for task_file in orchestrate_dir.glob("*/task.md"):
            try:
                content = task_file.read_text()
                task_name = task_file.parent.name

                # Extract status and last-updated in one pass
                status = None
                last_updated = None
                for line in content.split('\n'):
                    if line.startswith('Status:'):
                        status = line.split(':', 1)[1].strip()
                    elif line.startswith('Last-updated:'):
                        last_updated = line.split(':', 1)[1].strip()

                if status:
                    tasks.append({
                        'slug': task_name,
                        'status': status,
                        'last_updated': last_updated
                    })
            except Exception:
                continue
    except Exception:
        pass

    return tasks

def main():
    session = load_session()

    if not session:
        return 0

    print("=== Session Restored ===")

    # Show saved session
    task_slug = session.get('task_slug', 'unknown')
    phase = session.get('phase', 'unknown')
    timestamp = session.get('timestamp', 'unknown')
    saved_cwd = session.get('cwd', '.')

    print(f"Last task: {task_slug}")
    print(f"Phase: {phase}")
    print(f"Saved: {timestamp}")

    # Use saved cwd if current project dir doesn't have orchestrate tasks
    current_cwd = get_project_dir()
    check_cwd = current_cwd if (Path(current_cwd) / "tmp" / ".orchestrate").exists() else saved_cwd

    tasks = find_active_tasks(check_cwd)

    if tasks:
        print("\nActive orchestrate tasks:")
        for task in tasks:
            last = task.get('last_updated', 'unknown')
            print(f"  - {task['slug']}: {task['status']} (Last: {last})")

    print("========================")
    return 0

if __name__ == "__main__":
    try:
        exit(main())
    except Exception:
        # Fail silently
        exit(0)
