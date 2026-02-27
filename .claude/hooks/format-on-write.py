#!/usr/bin/env python3
"""PostToolUse hook: auto-format code files after Write/Edit.

Reads tool input from stdin (JSON), detects language by extension,
runs the appropriate formatter. Exit 0 always (never blocks writes).
"""

import json
import os
import shutil
import subprocess
import sys

FORMATTERS = {
    ".py": ["ruff", "format", "{file}"],
    ".js": ["npx", "prettier", "--write", "{file}"],
    ".ts": ["npx", "prettier", "--write", "{file}"],
    ".jsx": ["npx", "prettier", "--write", "{file}"],
    ".tsx": ["npx", "prettier", "--write", "{file}"],
    ".go": ["gofmt", "-w", "{file}"],
    ".rs": ["rustfmt", "{file}"],
}

SKIP_EXTENSIONS = {".md", ".json", ".yaml", ".yml", ".toml", ".sh", ".txt", ".csv", ".html", ".css"}


def get_file_path(data):
    """Extract file path from hook input JSON."""
    tool_input = data.get("tool_input", {})
    return tool_input.get("file_path") or tool_input.get("filePath") or ""


def run_formatter(file_path):
    """Run the appropriate formatter for the file extension."""
    _, ext = os.path.splitext(file_path)

    if ext in SKIP_EXTENSIONS or ext not in FORMATTERS:
        return

    cmd_template = FORMATTERS[ext]
    cmd = [arg.replace("{file}", file_path) for arg in cmd_template]

    if not shutil.which(cmd[0]):
        return

    try:
        subprocess.run(cmd, capture_output=True, timeout=10)
    except (subprocess.TimeoutExpired, OSError):
        pass


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    file_path = get_file_path(data)
    if file_path and os.path.isfile(file_path):
        run_formatter(file_path)

    sys.exit(0)


if __name__ == "__main__":
    main()
