#!/usr/bin/env python3
"""PostToolUse hook: capture orchestrate file writes for statistics.

Copies files written to tmp/.orchestrate/ to a persistent stats directory
and extracts confidence/status metadata into a JSONL index.
"""

import hashlib
import json
import os
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

STATS_DIR = Path.home() / ".local" / "share" / "claude-code-workflow" / "stats"
INDEX_FILE = STATS_DIR / "index.jsonl"
FILES_DIR = STATS_DIR / "files"

ORCHESTRATE_MARKER = "tmp/.orchestrate/"


def get_hook_input():
    """Read hook input from stdin."""
    try:
        if not sys.stdin.isatty():
            return json.loads(sys.stdin.read())
    except (json.JSONDecodeError, IOError):
        pass
    return {}


def extract_path_info(file_path):
    """Extract task_slug, phase, filename from orchestrate path.

    Expected pattern: .../tmp/.orchestrate/{task-slug}/{phase}/{filename}
    """
    idx = file_path.find(ORCHESTRATE_MARKER)
    if idx == -1:
        return None, None, None

    relative = file_path[idx + len(ORCHESTRATE_MARKER):]
    parts = relative.split("/")

    if len(parts) < 2:
        return None, None, None

    task_slug = parts[0]

    if len(parts) >= 3 and parts[1] in ("research", "plan", "execution"):
        phase = parts[1]
        filename = parts[-1]
    else:
        phase = None
        filename = parts[-1]

    return task_slug, phase, filename


def extract_agent_name(content, filename):
    """Extract agent name from content or filename.

    Priority:
    1. ## Return: {name} in content
    2. Known meta-file patterns
    3. Filename heuristic
    """
    # Priority 1: parse from content
    m = re.search(r"^##\s+Return:\s*(.+)$", content, re.MULTILINE)
    if m:
        return m.group(1).strip()

    # Priority 2: meta-files
    if filename.startswith("_"):
        return "orchestrator"

    # Priority 3: known patterns
    if filename == "architecture.md":
        return "architect"
    if re.match(r"batch-\d+-review\.md", filename):
        return "reviewer"

    # task-NN-name.md
    m = re.match(r"task-\d+-(.+)\.md", filename)
    if m:
        return m.group(1)

    # Strip common suffixes from filename stem
    stem = Path(filename).stem
    for suffix in ("-report", "-review", "-critique"):
        if stem.endswith(suffix):
            return stem[:-len(suffix)]

    return stem


def extract_confidence(content):
    """Extract numeric confidence score from content.

    Checks two patterns:
    1. ### Confidence\\nScore: 0.85
    2. YAML footer confidence: 0.85
    """
    # Pattern 1: structured Confidence section
    m = re.search(r"###\s*Confidence\s*\n\s*Score:\s*([\d.]+)", content)
    if m:
        try:
            val = float(m.group(1))
            if 0.0 <= val <= 1.0:
                return val
        except ValueError:
            pass

    # Pattern 2: YAML footer (numeric)
    m = re.search(r"^confidence:\s*([\d.]+)\s*$", content, re.MULTILINE)
    if m:
        try:
            val = float(m.group(1))
            if 0.0 <= val <= 1.0:
                return val
        except ValueError:
            pass

    # Pattern 3: YAML footer (text — legacy)
    m = re.search(r"^confidence:\s*(high|medium|low)\s*$", content, re.MULTILINE | re.IGNORECASE)
    if m:
        mapping = {"high": 0.85, "medium": 0.60, "low": 0.30}
        return mapping.get(m.group(1).lower())

    return None


def extract_status(content):
    """Extract status from content."""
    m = re.search(r"###\s*Status:\s*(SUCCESS|PARTIAL|FAILED|BLOCKED)", content)
    if m:
        return m.group(1)

    m = re.search(r"^status:\s*(SUCCESS|PARTIAL|FAILED)\s*$", content, re.MULTILINE)
    if m:
        return m.group(1)

    return None


def main():
    hook_input = get_hook_input()
    if not hook_input:
        return 0

    tool_input = hook_input.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    content = tool_input.get("content", "")

    # Only process orchestrate artifacts
    if ORCHESTRATE_MARKER not in file_path:
        return 0

    task_slug, phase, filename = extract_path_info(file_path)
    if not task_slug or not filename:
        return 0

    # Build archive path
    now = datetime.now(timezone.utc)
    date_path = now.strftime("%Y/%m/%d")

    if phase:
        archive_rel = f"{date_path}/{task_slug}/{phase}/{filename}"
    else:
        archive_rel = f"{date_path}/{task_slug}/{filename}"

    archive_path = FILES_DIR / archive_rel

    # Ensure directories exist
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    STATS_DIR.mkdir(parents=True, exist_ok=True)

    # Write archive copy
    archive_path.write_text(content, encoding="utf-8")

    # Build JSONL record
    file_hash = hashlib.sha256(content.encode("utf-8")).hexdigest()

    record = {
        "id": str(uuid.uuid4()),
        "timestamp": now.isoformat(),
        "session_id": hook_input.get("session_id", ""),
        "task_slug": task_slug,
        "phase": phase,
        "agent_name": extract_agent_name(content, filename),
        "file_name": filename,
        "file_path": file_path,
        "file_size": len(content.encode("utf-8")),
        "file_hash": f"sha256:{file_hash}",
        "archive_path": str(archive_path),
        "confidence": extract_confidence(content),
        "status": extract_status(content),
    }

    # Append to JSONL index
    with open(INDEX_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # Never block writes — fail silently
        sys.exit(0)
