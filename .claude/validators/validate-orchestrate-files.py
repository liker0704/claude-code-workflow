#!/usr/bin/env python3
"""
Validator for orchestrate files structure.
Validates task.md, tasks.md, plan.md, _plan.md, architecture.md when written to tmp/.orchestrate/.

Exit codes:
  0 - Valid (allow or JSON deny output)

Hook output format (on validation failure):
  JSON with hookSpecificOutput.permissionDecision = "deny" and actionable hints.
"""

import json
import os
import re
import sys


# Error messages with actionable hints for AI
ERROR_HINTS = {
    # task.md
    "missing_status": (
        "Missing required field: Status:",
        "Add 'Status: initialized' at the top of task.md (valid: initialized, researching, planning, executing, complete, blocked)"
    ),
    "missing_created": (
        "Missing required field: Created:",
        "Add 'Created: YYYY-MM-DD' field after Status in task.md"
    ),
    "missing_last_updated": (
        "Missing required field: Last-updated:",
        "Add 'Last-updated: YYYY-MM-DD' field after Created in task.md"
    ),
    "invalid_status": (
        "Invalid status '{status}'",
        "Change status to one of: {valid_statuses}"
    ),
    "missing_phases": (
        "Missing '## Phases' section",
        "Add '## Phases' section with checkboxes: Research, Architecture (if needed), Plan, Execute"
    ),

    # tasks.md
    "missing_tasks_header": (
        "Missing tasks header",
        "Add '# Tasks' or '# Task Breakdown' header at the top of tasks.md"
    ),
    "no_task_definitions": (
        "No task definitions found",
        "Add at least one task: '## task-01' with description"
    ),

    # plan.md
    "missing_plan_status": (
        "Missing Status field",
        "Add 'Status: draft' at the top of plan.md"
    ),
    "invalid_plan_status": (
        "Invalid plan status '{status}'",
        "Change plan status to one of: draft, approved, superseded"
    ),

    # _plan.md (research)
    "missing_research_status": (
        "Missing Status field",
        "Add 'Status: draft' at the top of _plan.md"
    ),
    "invalid_research_status": (
        "Invalid research plan status '{status}'",
        "Change research status to one of: draft, approved, executing, complete"
    ),
    "missing_research_questions": (
        "Missing section: ## 2. Research Questions",
        "Add '## 2. Research Questions' section with questions to answer"
    ),
    "missing_concerns_matrix": (
        "Missing section: ## 4. Concerns Matrix",
        "Add '## 4. Concerns Matrix' table with Concern | Priority | Resolution columns"
    ),
    "missing_gaps_found": (
        "Missing section: ## 7. Gaps Found",
        "Add '## 7. Gaps Found' section to track knowledge gaps"
    ),
    "gap_iterations_exceeded": (
        "Gap iterations {current} exceeds max {max_iter}",
        "Reduce gap iterations or escalate to user for decision"
    ),

    # _plan.md - Complexity Assessment
    "missing_complexity_assessment": (
        "Missing required section: ## 8. Complexity Assessment",
        "Add '## 8. Complexity Assessment' section with Score and factors table for Architecture gate"
    ),
    "missing_complexity_score": (
        "Missing complexity score",
        "Add '**Score:** N (threshold: 5)' in Complexity Assessment section"
    ),
    "invalid_complexity_score": (
        "Complexity score must be a number, got '{score}'",
        "Fix '**Score:**' to contain a valid number (e.g., '**Score:** 7 (threshold: 5)')"
    ),

    # _summary.md
    "missing_key_findings": (
        "Missing required section: ## Key Findings",
        "Add '## Key Findings' section with research discoveries"
    ),
    "missing_recommendations": (
        "Missing required section: ## Recommendations",
        "Add '## Recommendations' section with actionable suggestions"
    ),
    "missing_sources": (
        "Missing required section: ## Sources",
        "Add '## Sources' section listing all research sources"
    ),
    "no_findings_listed": (
        "No findings in Key Findings section",
        "Add at least one finding: '- **Finding:** \"quote\" (Source: file.md)'"
    ),
    "finding_no_confidence": (
        "Findings should have Confidence ratings",
        "Add '**Confidence:** High/Medium/Low (N%)' after each finding"
    ),

    # architecture.md
    "missing_context": (
        "Missing required section: ## Context",
        "Add '## Context' section explaining the problem and constraints"
    ),
    "missing_alternatives": (
        "Missing required section: ## Alternatives Considered",
        "Add '## Alternatives Considered' with at least 1 rejected alternative"
    ),
    "missing_decision": (
        "Missing required section: ## Decision",
        "Add '## Decision' section with **Approach:** and **Rationale:**"
    ),
    "missing_components": (
        "Missing required section: ## Components",
        "Add '## Components' table: | Action | Path | Purpose |"
    ),
    "missing_data_flow": (
        "Missing required section: ## Data Flow",
        "Add '## Data Flow' section describing data movement between components"
    ),
    "no_alternatives_listed": (
        "Must list at least 1 alternative",
        "Add alternatives: '1. **[Name]** — rejected: reason why not chosen'"
    ),
    "alternative_no_rejection": (
        "Alternative '{name}' missing rejection reason",
        "Add rejection reason: '1. **[{name}]** — rejected: specific reason'"
    ),
    "components_empty": (
        "Components table must have at least 1 row",
        "Add component rows: '| CREATE | `path/file.ts` | purpose |'"
    ),
    "decision_no_approach": (
        "Decision section missing 'Approach:'",
        "Add '**Approach:** description of chosen solution' to Decision section"
    ),
    "decision_no_rationale": (
        "Decision section missing 'Rationale:'",
        "Add '**Rationale:** why this approach was chosen' to Decision section"
    ),

    # risks.md
    "missing_risk_table": (
        "Missing required risk table headers",
        "Add markdown table with headers: | Risk | Likelihood | Impact | Mitigation |"
    ),

    # acceptance.md
    "missing_checklist_items": (
        "Missing checklist items (Definition of Done)",
        "Add at least one checklist item: '- [ ] requirement description' or '- [x] completed item'"
    ),
    "missing_dod_header": (
        "Missing Definition of Done header",
        "Add section header: '## Definition of Done' or '## Acceptance Criteria' or '## DoD'"
    ),
}


def format_error_with_hint(error_key: str, **kwargs) -> str:
    """Format error message with actionable hint."""
    if error_key not in ERROR_HINTS:
        return f"Validation error: {error_key}"

    error_msg, hint = ERROR_HINTS[error_key]

    # Format with kwargs
    error_msg = error_msg.format(**kwargs) if kwargs else error_msg
    hint = hint.format(**kwargs) if kwargs else hint

    return f"{error_msg}\n   → FIX: {hint}"


def output_deny(filename: str, errors: list[str]) -> None:
    """Output JSON deny response with actionable hints."""
    error_list = "\n".join(f"• {err}" for err in errors)

    message = (
        f"BLOCKED by validate-orchestrate-files.py\n\n"
        f"File: {filename}\n\n"
        f"Errors:\n{error_list}\n\n"
        f"Fix the errors above and retry writing the file.\n\n"
        f"See ~/.claude/docs/orchestrate-file-formats.md for correct format."
    )

    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": message,
        }
    }

    print(json.dumps(output))


def check_secrets(content: str) -> tuple[bool, list[str]]:
    """
    Check content for hardcoded secrets.
    Returns (is_safe, list_of_findings).
    """
    findings = []

    # Pattern 1: API keys (sk-...)
    api_keys = re.findall(r'sk-[a-zA-Z0-9]{20,}', content)
    if api_keys:
        findings.append(f"API key detected: {api_keys[0][:15]}... (potential leak)")

    # Pattern 2: AWS keys (AKIA...)
    aws_keys = re.findall(r'AKIA[A-Z0-9]{16}', content)
    if aws_keys:
        findings.append(f"AWS access key detected: {aws_keys[0]} (potential leak)")

    # Pattern 3: Hardcoded passwords
    passwords = re.findall(r'password\s*=\s*["\']([^"\']+)["\']', content, re.IGNORECASE)
    if passwords:
        findings.append(f"Hardcoded password detected: password=\"{passwords[0][:10]}...\" (security risk)")

    # Pattern 4: Private keys
    private_keys = re.findall(r'-----BEGIN.*PRIVATE KEY-----', content)
    if private_keys:
        findings.append(f"Private key detected: {private_keys[0]} (critical security risk)")

    is_safe = len(findings) == 0
    return is_safe, findings


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

    valid_statuses = [
        "initialized", "researching", "research-complete",
        "architecting", "arch-review", "arch-iteration", "arch-escalated",
        "planning", "plan-complete", "executing", "complete",
        "blocked", "abandoned", "cancelled"
    ]

    if "Status:" not in content:
        errors.append(format_error_with_hint("missing_status"))
    else:
        status_match = re.search(r"Status:\s*(\S+)", content)
        if status_match:
            status = status_match.group(1)
            if status not in valid_statuses:
                errors.append(format_error_with_hint(
                    "invalid_status",
                    status=status,
                    valid_statuses=", ".join(valid_statuses)
                ))

    if "Created:" not in content:
        errors.append(format_error_with_hint("missing_created"))

    if "Last-updated:" not in content:
        errors.append(format_error_with_hint("missing_last_updated"))

    if "## Phases" not in content:
        errors.append(format_error_with_hint("missing_phases"))

    return len(errors) == 0, errors


def validate_tasks_md(content: str) -> tuple[bool, list[str]]:
    """Validate tasks.md structure."""
    errors = []

    if "# Tasks" not in content and "# Task Breakdown" not in content:
        errors.append(format_error_with_hint("missing_tasks_header"))

    if not re.search(r"##\s+task-\d+", content, re.IGNORECASE):
        errors.append(format_error_with_hint("no_task_definitions"))

    return len(errors) == 0, errors


def validate_plan_md(content: str) -> tuple[bool, list[str]]:
    """Validate plan.md structure."""
    errors = []

    valid_statuses = ["draft", "approved", "superseded"]

    if "Status:" not in content:
        errors.append(format_error_with_hint("missing_plan_status"))
    else:
        status_match = re.search(r"Status:\s*(\S+)", content)
        if status_match:
            status = status_match.group(1)
            if status not in valid_statuses:
                errors.append(format_error_with_hint(
                    "invalid_plan_status",
                    status=status
                ))

    return len(errors) == 0, errors


def validate_research_plan_md(content: str) -> tuple[bool, list[str]]:
    """Validate research _plan.md structure."""
    errors = []

    valid_statuses = ["draft", "approved", "executing", "complete"]

    if "Status:" not in content:
        errors.append(format_error_with_hint("missing_research_status"))
    else:
        status_match = re.search(r"Status:\s*(\S+)", content)
        if status_match:
            status = status_match.group(1)
            if status not in valid_statuses:
                errors.append(format_error_with_hint(
                    "invalid_research_status",
                    status=status
                ))

    # Check for required sections
    section_map = {
        "## 2. Research Questions": "missing_research_questions",
        "## 4. Concerns Matrix": "missing_concerns_matrix",
        "## 7. Gaps Found": "missing_gaps_found",
    }
    for section, error_key in section_map.items():
        if section not in content:
            errors.append(format_error_with_hint(error_key))

    # Check gap iterations format
    if "**Gap iterations:**" in content:
        gap_match = re.search(r"\*\*Gap iterations:\*\*\s*(\d+)/(\d+)", content)
        if gap_match:
            current, max_iter = int(gap_match.group(1)), int(gap_match.group(2))
            if current > max_iter:
                errors.append(format_error_with_hint(
                    "gap_iterations_exceeded",
                    current=current,
                    max_iter=max_iter
                ))

    # Check Complexity Assessment (Section 8) - required for Architecture gate
    if "## 8. Complexity Assessment" not in content:
        errors.append(format_error_with_hint("missing_complexity_assessment"))
    else:
        # Check for Score
        score_match = re.search(r"\*\*Score:\*\*\s*(\S+)", content)
        if not score_match:
            errors.append(format_error_with_hint("missing_complexity_score"))
        else:
            score_value = score_match.group(1)
            # Score should be a number (possibly with decimals)
            if not re.match(r"^\d+\.?\d*$", score_value):
                errors.append(format_error_with_hint(
                    "invalid_complexity_score",
                    score=score_value
                ))

    return len(errors) == 0, errors


def validate_summary_md(content: str) -> tuple[bool, list[str]]:
    """Validate research _summary.md structure."""
    errors = []
    warnings = []

    # Required sections
    section_map = {
        "## Key Findings": "missing_key_findings",
        "## Recommendations": "missing_recommendations",
        "## Sources": "missing_sources",
    }

    for section, error_key in section_map.items():
        if section not in content:
            errors.append(format_error_with_hint(error_key))

    # Check Key Findings has at least one finding
    findings_match = re.search(
        r"## Key Findings\s*(.*?)(?=\n## |\Z)",
        content,
        re.DOTALL
    )
    if findings_match:
        findings_section = findings_match.group(1).strip()
        # Look for bullet points or numbered findings
        findings = re.findall(r"[-*\d.]\s+\*\*", findings_section)
        if len(findings) == 0:
            errors.append(format_error_with_hint("no_findings_listed"))

        # Check for Confidence ratings (warning, not error)
        if "**Confidence:**" not in findings_section and "Confidence:" not in findings_section:
            warnings.append(format_error_with_hint("finding_no_confidence"))

    # Print warnings to stderr (non-blocking)
    for warning in warnings:
        print(f"  Warning: {warning}", file=sys.stderr)

    return len(errors) == 0, errors


def validate_architecture_md(content: str) -> tuple[bool, list[str]]:
    """Validate architecture.md structure (ADR format)."""
    errors = []
    warnings = []

    # Required sections for lightweight ADR
    section_map = {
        "## Context": "missing_context",
        "## Alternatives Considered": "missing_alternatives",
        "## Decision": "missing_decision",
        "## Components": "missing_components",
        "## Data Flow": "missing_data_flow",
    }

    for section, error_key in section_map.items():
        if section not in content:
            errors.append(format_error_with_hint(error_key))

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
            errors.append(format_error_with_hint("no_alternatives_listed"))
        else:
            for name, keyword, reason in alternatives:
                if not keyword:
                    warnings.append(f"Alternative '{name}' missing 'rejected:' keyword")
                if not reason.strip():
                    errors.append(format_error_with_hint(
                        "alternative_no_rejection",
                        name=name
                    ))

    # Check Components table has at least 1 row
    components_match = re.search(
        r"## Components\s*(.*?)(?=\n## |\Z)",
        content,
        re.DOTALL
    )
    if components_match:
        components_section = components_match.group(1)
        component_rows = re.findall(
            r'\|\s*(CREATE|MODIFY|DELETE)\s*\|',
            components_section,
            re.IGNORECASE
        )
        if len(component_rows) == 0:
            errors.append(format_error_with_hint("components_empty"))

    # Check Decision section has Approach and Rationale
    decision_match = re.search(
        r"## Decision\s*(.*?)(?=\n## |\Z)",
        content,
        re.DOTALL
    )
    if decision_match:
        decision_section = decision_match.group(1)
        if "**Approach:**" not in decision_section and "Approach:" not in decision_section:
            errors.append(format_error_with_hint("decision_no_approach"))
        if "**Rationale:**" not in decision_section and "Rationale:" not in decision_section:
            errors.append(format_error_with_hint("decision_no_rationale"))

    # Print warnings (non-blocking) to stderr
    for warning in warnings:
        print(f"  Warning: {warning}", file=sys.stderr)

    return len(errors) == 0, errors


def validate_risks_md(content: str) -> tuple[bool, list[str]]:
    """Validate risks.md has proper risk table."""
    errors = []

    # Required table headers (case-insensitive)
    required_headers = ['Risk', 'Likelihood', 'Impact', 'Mitigation']

    # Check if all required headers exist (case-insensitive)
    content_lower = content.lower()
    missing_headers = []
    for header in required_headers:
        if header.lower() not in content_lower:
            missing_headers.append(header)

    if missing_headers:
        errors.append(format_error_with_hint("missing_risk_table"))
        return False, errors

    # Additional validation: check for markdown table format (optional but recommended)
    # Look for table delimiter row like |---|---|---|---|
    has_table_delimiter = re.search(r'\|[\s-]+\|[\s-]+\|[\s-]+\|[\s-]+\|', content)
    if not has_table_delimiter:
        # Warning but not blocking - headers might be present but not in table format
        print(f"  Warning: Risk table headers found but table formatting (|---|---|) not detected", file=sys.stderr)

    return len(errors) == 0, errors


def validate_acceptance_md(content: str) -> tuple[bool, list[str]]:
    """Validate acceptance.md has DoD checklist."""
    errors = []

    # Check for checklist items: - [ ] or - [x]
    checklist_pattern = re.compile(r'-\s+\[[ xX]\]')
    matches = checklist_pattern.findall(content)

    if len(matches) == 0:
        errors.append(format_error_with_hint("missing_checklist_items"))

    # Check for Definition of Done header (case-insensitive)
    content_lower = content.lower()
    dod_keywords = ['definition of done', 'acceptance criteria', 'dod']
    has_dod_header = any(keyword in content_lower for keyword in dod_keywords)

    if not has_dod_header:
        errors.append(format_error_with_hint("missing_dod_header"))

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

        # STEP 1: Check for secrets in ALL orchestrate files
        secrets_safe, secrets_findings = check_secrets(content)
        if not secrets_safe:
            filename = os.path.basename(file_path)
            secrets_errors = [
                "SECURITY RISK: Hardcoded secrets detected in file!",
                "",
            ] + secrets_findings + [
                "",
                "NEVER write secrets to orchestrate files. Use environment variables or config files instead."
            ]
            output_deny(filename, secrets_errors)
            sys.exit(0)  # Exit 0, Claude reads JSON for deny

        # STEP 2: Determine file type and validate structure
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
        elif filename == "_summary.md":
            is_valid, errors = validate_summary_md(content)
        elif filename == "architecture.md":
            is_valid, errors = validate_architecture_md(content)
        elif filename == "risks.md":
            is_valid, errors = validate_risks_md(content)
        elif filename == "acceptance.md":
            is_valid, errors = validate_acceptance_md(content)
        else:
            # Other files - no structure validation, but secrets check passed
            sys.exit(0)

        if not is_valid:
            # Output JSON deny with actionable hints for AI
            output_deny(filename, errors)
            sys.exit(0)  # Exit 0, Claude reads JSON for deny

        sys.exit(0)  # Allow

    except Exception as e:
        # On error, log but don't block
        print(f"Validator error (non-blocking): {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
