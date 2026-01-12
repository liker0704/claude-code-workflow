#!/usr/bin/env python3
"""
Validator for orchestrate files structure.
Validates task.md, tasks.md, plan.md when written to tmp/.orchestrate/.

Exit codes:
  0 - Valid (allow)
  2 - Invalid (block)
"""

import json
import os
import re
import sys


def get_hook_input():
    """Read hook input from environment or stdin."""
    # Try environment first
    hook_input = os.environ.get("CLAUDE_HOOK_INPUT", "")
    if hook_input:
        return json.loads(hook_input)

    # Try stdin
    import sys
    if not sys.stdin.isatty():
        stdin_data = sys.stdin.read()
        if stdin_data:
            return json.loads(stdin_data)

    return {}


def validate_task_md(content: str) -> tuple[bool, list[str]]:
    """Validate task.md structure."""
    errors = []

    required_fields = ["Status:", "Created:", "Last-updated:"]
    for field in required_fields:
        if field not in content:
            errors.append(f"Missing required field: {field}")

    valid_statuses = [
        "initialized", "researching", "research-complete",
        "planning", "plan-complete", "executing", "complete",
        "blocked", "abandoned"
    ]
    status_match = re.search(r"Status:\s*(\S+)", content)
    if status_match:
        status = status_match.group(1)
        if status not in valid_statuses:
            errors.append(f"Invalid status '{status}'. Expected one of: {', '.join(valid_statuses)}")

    if "## Phases" not in content:
        errors.append("Missing '## Phases' section")

    return len(errors) == 0, errors


def validate_tasks_md(content: str) -> tuple[bool, list[str]]:
    """Validate tasks.md structure."""
    errors = []

    if "# Tasks" not in content and "# Task Breakdown" not in content:
        errors.append("Missing tasks header")

    # Check for at least one task definition
    if not re.search(r"##\s+task-\d+", content, re.IGNORECASE):
        errors.append("No task definitions found (expected: ## task-XX)")

    return len(errors) == 0, errors


def validate_plan_md(content: str) -> tuple[bool, list[str]]:
    """Validate plan.md structure."""
    errors = []

    if "Status:" not in content:
        errors.append("Missing Status field")

    valid_statuses = ["draft", "approved", "superseded"]
    status_match = re.search(r"Status:\s*(\S+)", content)
    if status_match:
        status = status_match.group(1)
        if status not in valid_statuses:
            errors.append(f"Invalid plan status '{status}'. Expected: {', '.join(valid_statuses)}")

    return len(errors) == 0, errors


def main():
    try:
        hook_input = get_hook_input()

        # PreToolUse Write event provides file_path and content
        tool_input = hook_input.get("tool_input", {})
        file_path = tool_input.get("file_path", "")
        content = tool_input.get("content", "")

        # Only validate files in tmp/.orchestrate/
        if "tmp/.orchestrate/" not in file_path:
            sys.exit(0)  # Not an orchestrate file, skip

        # Determine file type and validate
        filename = os.path.basename(file_path)
        is_valid = True
        errors = []

        if filename == "task.md":
            is_valid, errors = validate_task_md(content)
        elif filename == "tasks.md":
            is_valid, errors = validate_tasks_md(content)
        elif filename == "plan.md":
            is_valid, errors = validate_plan_md(content)
        else:
            # Other files - no validation
            sys.exit(0)

        if not is_valid:
            print(f"Orchestrate file validation failed for {filename}:")
            for error in errors:
                print(f"  - {error}")
            sys.exit(2)  # Block

        sys.exit(0)  # Allow

    except Exception as e:
        # On error, log but don't block
        print(f"Validator error (non-blocking): {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
