# Orchestrate File Formats Reference

**Purpose:** This document defines the required formats for all orchestrate files validated by `.claude/validators/validate-orchestrate-files.py`. Use this reference for self-correction when the validator blocks your writes.

**Validation scope:** Files in `tmp/.orchestrate/{task}/`

---

## 1. task.md — Task Definition

### Required Fields

- **Status:** (one of valid statuses)
- **Created:** YYYY-MM-DD
- **Last-updated:** YYYY-MM-DD

### Required Sections

- **## Phases** (with checkboxes for Research, Architecture, Plan, Execute)

### Valid Statuses

```
initialized, researching, research-complete,
architecting, arch-review, arch-iteration, arch-escalated,
planning, plan-complete, executing, complete,
blocked, abandoned, cancelled
```

### Minimal Valid Example

```markdown
Status: initialized
Created: 2026-02-08
Last-updated: 2026-02-08

# Task: example-task

Description of the task.

## Phases

- [ ] Research
- [ ] Architecture (if needed)
- [ ] Plan
- [ ] Execute
```

---

## 2. plan/tasks.md — Task Breakdown

### Required Sections

- **# Tasks** OR **# Task Breakdown** (header)
- At least one task definition: **## task-01**

### Minimal Valid Example

```markdown
# Tasks

## task-01: Implement feature X

Description of the task.

**Dependencies:** None
```

---

## 3. plan/plan.md — Implementation Plan

### Required Fields

- **Status:** (one of: draft, approved, superseded)

### Minimal Valid Example

```markdown
Status: draft

# Implementation Plan

## Overview

Plan overview here.

## Steps

1. Step 1
2. Step 2
```

---

## 4. plan/_plan.md — Research Plan

### Required Fields

- **Status:** (one of: draft, approved, executing, complete)

### Required Sections

1. **## 2. Research Questions** — Questions to answer during research
2. **## 4. Concerns Matrix** — Table with Concern | Priority | Resolution columns
3. **## 7. Gaps Found** — Tracks knowledge gaps
4. **## 8. Complexity Assessment** — REQUIRED for Architecture gate

### Complexity Assessment Format

```markdown
## 8. Complexity Assessment

**Score:** 7 (threshold: 5)

| Factor | Weight | Score | Weighted |
|--------|--------|-------|----------|
| Factor 1 | 3 | 8 | 24 |
| Factor 2 | 2 | 6 | 12 |
```

**CRITICAL:**
- Score must be a number (can have decimals: `7.5`)
- Format: `**Score:** N (threshold: 5)`
- If score >= 5, Architecture phase is required

### Gap Iterations Format

If present, must follow: `**Gap iterations:** current/max`

Example: `**Gap iterations:** 2/3`

- Current MUST NOT exceed max

### Minimal Valid Example

```markdown
Status: draft

# Research Plan: example-task

## 2. Research Questions

1. Question 1?
2. Question 2?

## 4. Concerns Matrix

| Concern | Priority | Resolution |
|---------|----------|------------|
| Concern 1 | High | Approach |

## 7. Gaps Found

**Gap iterations:** 0/3

No gaps found yet.

## 8. Complexity Assessment

**Score:** 3 (threshold: 5)

| Factor | Weight | Score | Weighted |
|--------|--------|-------|----------|
| Feature complexity | 3 | 4 | 12 |
| Integration risk | 2 | 2 | 4 |
```

---

## 5. research/_summary.md — Research Summary

### Required Sections

1. **## Key Findings** — Must have at least one finding
2. **## Recommendations** — Actionable suggestions
3. **## Sources** — List of all research sources

### Finding Format (RECOMMENDED)

```markdown
- **Finding:** "Quote or description"
  - **Confidence:** High (85%)
  - **Source:** file.md or URL
```

**Note:** Confidence ratings are recommended but not strictly required.

### Minimal Valid Example

```markdown
# Research Summary: example-task

## Key Findings

- **Finding:** "Discovery 1"
  - **Confidence:** High (90%)
  - **Source:** research-file.md

## Recommendations

- Recommendation 1
- Recommendation 2

## Sources

1. research-file.md
2. external-doc.md
```

---

## 6. architecture.md — Architecture Decision Record (ADR)

### Required Sections

1. **## Context** — Problem and constraints
2. **## Alternatives Considered** — Must have at least 1 alternative with rejection reason
3. **## Decision** — Must include both:
   - **Approach:** Description of chosen solution
   - **Rationale:** Why this approach was chosen
4. **## Components** — Table with at least 1 row
5. **## Data Flow** — Description of data movement

### Alternative Format

```markdown
1. **[Alternative Name]** — rejected: specific reason why not chosen
```

- Must include "rejected:" keyword
- Must include rejection reason (non-empty)

### Components Table Format

```markdown
| Action | Path | Purpose |
|--------|------|---------|
| CREATE | `path/to/file.ts` | Description |
| MODIFY | `path/to/existing.ts` | What changes |
| DELETE | `path/to/old.ts` | Why removing |
```

- Action must be one of: CREATE, MODIFY, DELETE
- At least 1 component row required

### Minimal Valid Example

```markdown
# Architecture: example-task

## Context

We need to solve problem X with constraints Y and Z.

## Alternatives Considered

1. **[Alternative 1]** — rejected: reason why not suitable
2. **[Alternative 2]** — rejected: another reason

## Decision

**Approach:** We will use approach X with pattern Y.

**Rationale:** This approach was chosen because it balances performance and maintainability.

## Components

| Action | Path | Purpose |
|--------|------|---------|
| CREATE | `src/feature.ts` | Implements new feature |
| MODIFY | `src/config.ts` | Add configuration |

## Data Flow

1. Input enters via API endpoint
2. Data flows to processor
3. Results return to client
```

---

## Common Mistakes

### task.md
- ❌ Missing Status/Created/Last-updated fields
- ❌ Invalid status (must be from allowed list)
- ❌ Missing ## Phases section

### tasks.md
- ❌ No header (must have `# Tasks` or `# Task Breakdown`)
- ❌ No task definitions (must have at least one `## task-01`)

### plan.md
- ❌ Missing Status field
- ❌ Invalid status (must be: draft, approved, or superseded)

### _plan.md
- ❌ Missing required sections (2, 4, 7, 8)
- ❌ Missing or invalid Complexity Score in section 8
- ❌ Score format wrong (must be `**Score:** N`)
- ❌ Gap iterations exceeded (current > max)

### _summary.md
- ❌ Missing required sections (Key Findings, Recommendations, Sources)
- ❌ Empty Key Findings section (must have at least 1 finding)

### architecture.md
- ❌ Missing required sections
- ❌ No alternatives listed (need at least 1)
- ❌ Alternative without rejection reason
- ❌ Missing "rejected:" keyword in alternatives
- ❌ Empty Components table (need at least 1 row)
- ❌ Decision section missing Approach or Rationale

---

## Validation Process

When you write any of these files to `tmp/.orchestrate/`, the validator:

1. Detects the file type by filename
2. Checks required fields and sections
3. If invalid: Returns JSON deny with actionable error hints
4. If valid: Allows the write

**On validation failure:** Read the error hints, fix the issues, and retry the write.

---

## Quick Reference Table

| File | Key Requirements |
|------|------------------|
| `task.md` | Status + Created + Last-updated + Phases section |
| `tasks.md` | Header + at least one task-NN |
| `plan.md` | Status field (draft/approved/superseded) |
| `_plan.md` | Status + sections 2,4,7,8 + Complexity Score |
| `_summary.md` | Key Findings (>=1) + Recommendations + Sources |
| `architecture.md` | Context + Alternatives (>=1) + Decision (Approach+Rationale) + Components (>=1) + Data Flow |
