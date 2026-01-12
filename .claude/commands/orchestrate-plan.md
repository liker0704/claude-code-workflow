# Orchestrate Plan Command

Phase 2: Create detailed implementation plan and decompose into tasks.

---

You are in **ORCHESTRATOR MODE - PLANNING PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Read research summary, create plan, decompose into tasks, define dependencies
- **DON'T**: Implement anything yourself

## Entry/Exit Criteria

**Entry:** `task.md` has `Status: research-complete`, `research/_summary.md` exists
**Exit:** `task.md` updated to `Status: plan-complete`, `plan/plan.md` approved, `plan/tasks.md` created

## Your Task

Planning phase for task: **$ARGUMENTS**

## Step 1: Validate Task

```
Check: tmp/.orchestrate/{task-slug}/ exists
Check: tmp/.orchestrate/{task-slug}/task.md exists
Create: tmp/.orchestrate/{task-slug}/plan/ if missing
```

## Step 2: Check Research

If `research/_summary.md` missing:
```
⚠️ Research not completed. Options:
1. Run research: /orchestrate-research {task-slug}
2. Continue without (not recommended)
```

## Step 3: Check Current Status

**If `planning`:** Offer view draft/continue/restart/cancel
**If `plan-complete` or later:** Offer view plan/view tasks/modify/re-create/proceed to execute
**If `research-complete`:** Proceed to Step 4
**Otherwise:** Error, suggest appropriate phase

## Step 4: Update Status

Update `task.md` to `Status: planning`

## Step 5: Read Research Summary

Read `research/_summary.md` for: recommended approach, files to modify, patterns, open questions

## Step 6: Create Plan Document

Write `plan/plan.md`:

```markdown
# Implementation Plan: {task-slug}

Created: {timestamp}
Status: draft
Based on: research/_summary.md

## Overview
[What and why]

## Goals
- [Measurable outcome 1]

## Non-Goals
- [Out of scope]

## Current State
[From research]

## Proposed Solution
[High-level approach]

## Implementation Phases

### Phase 1: {Name}
**Goal**: [What this accomplishes]
**Changes**: `path/file.py`: [description]
**Success Criteria**: Automated: [test], Manual: [check]

### Phase 2: {Name}
...

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk] | low/med/high | low/med/high | [Handle] |

## Testing Strategy
- Unit/Integration: [components/flows]
- Commands: `pytest tests/`
- Manual: [what needs human check]

## Rollback Plan
1. [How to undo]
```

## Step 7: Present Plan Direction

```
## Implementation Plan Direction

Task: {task-slug}
Overview: {brief}
Approach: {high-level}
Phases: 1. {Phase 1}, 2. {Phase 2}

---
[Continue] Proceed | [Modify] Need changes | [Back] Return to research
```

## Step 8: Decompose into Tasks

Break each phase into atomic tasks with:
- Single responsibility, clear deliverable, independently verifiable
- 5-30 minutes of agent work
- Assignable to one agent type

**Types:** implement, modify, test, config, docs
**Risk levels:** high (auth, security, payments), medium (features, API, refactoring), low (docs, config, styling)

## Step 9: Define Interface Contracts

**CRITICAL: Before tasks.md, define CONTRACTS between tasks.**

```yaml
## Contract: task-01 → task-02

task-01 PRODUCES:
  files: [src/models/user.py]
  exports: [User, UserSchema]
  interface:
    name: User.to_dict
    signature: "def to_dict(self) -> dict"

task-02 EXPECTS from task-01:
  - User class with to_dict() method
  - Importable from src/models/user
```

## Step 10: Create Tasks File

Write `plan/tasks.md`:

```markdown
# Tasks for: {task-slug}

Generated: {timestamp}
Total tasks: {N}

## Interface Contracts

### Contract: task-01 → task-02
**task-01 PRODUCES:**
```yaml
files: [{path: src/models/user.py, exports: [User, UserSchema]}]
interfaces: [{name: User.to_dict, signature: "def to_dict(self) -> dict"}]
```
**task-02 EXPECTS:** User class from src/models/user

---

## Summary

| Phase | Tasks | Parallel |
|-------|-------|----------|
| Phase 1 | 3 | 2 |

## Task List

### task-01: {short-name}
- **Phase**: 1
- **Type**: implement
- **Risk**: low|medium|high
- **Description**: [details]
- **Files**: `path/file.py` (create/modify)
- **Details**: [requirements]
- **Depends on**: none
- **Blocks**: task-02, task-03
- **Agent**: implementer
- **Verification**: `pytest tests/test_file.py`
- **Status**: pending
- **PRODUCES:**
  ```yaml
  files: [{path, exports}]
  interfaces: [{name, signature}]
  ```
- **EXPECTS:** None (first task)

---

### task-final-review: Final Review (MANDATORY)
- **Phase**: final
- **Type**: review
- **Risk**: high
- **Description**: Comprehensive review of ALL changes
- **Depends on**: ALL other tasks
- **Agent**: orchestrator (spawns reviewer + devil-advocate)
- **Verification**: All tests pass, all requirements covered, user approves
- **Status**: pending

## Dependency Graph

```
task-01 ──┬──→ task-02 ──→ task-final-review
          └──→ task-03 ──┘
```

## Execution Batches

### Batch 1: task-01
### Batch 2: task-02, task-03 [parallel]
### Batch FINAL: task-final-review

## Verification Checklist
- [ ] All tests pass
- [ ] Type check passes
- [ ] Final review approved
```

## Step 11: Devil's Advocate

```yaml
Tool: Task
Parameters:
  subagent_type: "devil-advocate"
  prompt: |
    Review plan: tmp/.orchestrate/{task-slug}/plan/plan.md
    And tasks: tmp/.orchestrate/{task-slug}/plan/tasks.md
    Context: {task description}
    Return critique.
  description: "Devil's Advocate critique"
```

Show critique:
```
## Devil's Advocate Critique
{summary}

### Key Concerns
{list}

[Address] Update plan | [Dismiss] Proceed anyway | [Discuss] Clarify
```

## Step 12: Second Opinion

```yaml
Tool: Task
Parameters:
  subagent_type: "second-opinion"
  prompt: |
    Validate plan: tmp/.orchestrate/{task-slug}/plan/plan.md
    DO NOT read research files. Judge purely on technical merit.
    Return: VALIDATED or CONCERNS with details.
  description: "Second Opinion validation"
```

## Step 13: Present Final Plan

```
## Final Plan Review

Task: {task-slug}
Tasks: {N} total

### Analytical Review
- Devil's Advocate: {addressed/dismissed X concerns}
- Second Opinion: {VALIDATED/concerns addressed}

Full plan: plan/plan.md
Full tasks: plan/tasks.md

[Approve] Start execution | [Modify] Changes needed | [Replan] Start over
```

## Step 14: Handle Approval

**On Approve:**
1. Update `plan/plan.md` Status to `approved`
2. Update `task.md` to `Status: plan-complete`, mark `[x] Plan`
3. Show: `Plan complete. Run /orchestrate-execute {task-slug}`

**On Modify:** Apply changes, re-run Devil's Advocate if significant
**On Replan:** Return to Step 6

## Task Count Guidelines

- Ideal: 5-15 tasks
- Maximum: 25 tasks
- If more: Consider sub-orchestrations

## Architect Agent (Optional)

Use only if Devil's Advocate or Second Opinion raise architectural concerns:

```yaml
Tool: Task
Parameters:
  subagent_type: "architect"
  prompt: |
    Context: {task}, Research: {summary}, Question: {specific}
    Provide recommendation with rationale.
  description: "Architect consultation"
```

---

Begin by validating the task and checking current status.
