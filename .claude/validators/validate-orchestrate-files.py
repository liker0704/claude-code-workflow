#!/usr/bin/env python3
"""
Validator for orchestrate files structure.
Validates task.md, tasks.md, plan.md, _plan.md, architecture.md when written to tmp/.orchestrate/.

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
        "architecting", "arch-review", "arch-iteration", "arch-escalated",  # Architecture phase
        "planning", "plan-complete", "executing", "complete",
        "blocked", "abandoned", "cancelled"
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


def validate_research_plan_md(content: str) -> tuple[bool, list[str]]:
    """Validate research _plan.md structure."""
    errors = []

    if "Status:" not in content:
        errors.append("Missing Status field")

    valid_statuses = ["draft", "approved", "executing", "complete"]
    status_match = re.search(r"Status:\s*(\S+)", content)
    if status_match:
        status = status_match.group(1)
        if status not in valid_statuses:
            errors.append(f"Invalid research plan status '{status}'. Expected: {', '.join(valid_statuses)}")

    # Check for required sections
    required_sections = ["## 2. Research Questions", "## 4. Concerns Matrix", "## 7. Gaps Found"]
    for section in required_sections:
        if section not in content:
            errors.append(f"Missing section: {section}")

    # Check gap iterations format
    if "**Gap iterations:**" in content:
        gap_match = re.search(r"\*\*Gap iterations:\*\*\s*(\d+)/(\d+)", content)
        if gap_match:
            current, max_iter = int(gap_match.group(1)), int(gap_match.group(2))
            if current > max_iter:
                errors.append(f"Gap iterations {current} exceeds max {max_iter}")

    return len(errors) == 0, errors


def validate_architecture_md(content: str) -> tuple[bool, list[str]]:
    """Validate architecture.md structure (ADR format)."""
    errors = []
    warnings = []

    # Required sections for lightweight ADR
    required_sections = [
        "## Context",
        "## Alternatives Considered",
        "## Decision",
        "## Components",
        "## Data Flow"
    ]

    for section in required_sections:
        if section not in content:
            errors.append(f"Missing required section: {section}")

    # Check Alternatives section has at least 1 alternative with rejection reason
    alt_section_match = re.search(
        r"## Alternatives Considered\s*(.*?)(?=\n## |\Z)",
        content,
        re.DOTALL
    )
    if alt_section_match:
        alt_section = alt_section_match.group(1)
        # Look for numbered alternatives: 1. **[Name]** — rejected: reason
        alternatives = re.findall(
            r'\d+\.\s+\*\*\[([^\]]+)\]\*\*\s*[—-]\s*(rejected:|отвергнуто:)?\s*(.+)',
            alt_section,
            re.IGNORECASE
        )
        if len(alternatives) < 1:
            errors.append("Must list at least 1 alternative in '## Alternatives Considered'")
        else:
            for name, keyword, reason in alternatives:
                if not keyword:
                    warnings.append(f"Alternative '{name}' missing 'rejected:' keyword")
                if not reason.strip():
                    errors.append(f"Alternative '{name}' missing rejection reason")

    # Check Components table has at least 1 row
    components_match = re.search(
        r"## Components\s*(.*?)(?=\n## |\Z)",
        content,
        re.DOTALL
    )
    if components_match:
        components_section = components_match.group(1)
        # Look for table rows: | CREATE/MODIFY | `path` | purpose |
        component_rows = re.findall(
            r'\|\s*(CREATE|MODIFY|DELETE)\s*\|',
            components_section,
            re.IGNORECASE
        )
        if len(component_rows) == 0:
            errors.append("Components table must have at least 1 row (CREATE/MODIFY/DELETE)")

    # Check Decision section has Approach and Rationale
    decision_match = re.search(
        r"## Decision\s*(.*?)(?=\n## |\Z)",
        content,
        re.DOTALL
    )
    if decision_match:
        decision_section = decision_match.group(1)
        if "**Approach:**" not in decision_section and "Approach:" not in decision_section:
            errors.append("Decision section missing 'Approach:'")
        if "**Rationale:**" not in decision_section and "Rationale:" not in decision_section:
            errors.append("Decision section missing 'Rationale:'")

    # Print warnings (non-blocking)
    for warning in warnings:
        print(f"  Warning: {warning}", file=sys.stderr)

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
        elif filename == "_plan.md":
            is_valid, errors = validate_research_plan_md(content)
        elif filename == "architecture.md":
            is_valid, errors = validate_architecture_md(content)
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
