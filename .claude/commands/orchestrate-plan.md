# Orchestrate Plan Command

Phase 2: Create detailed implementation plan and decompose into tasks.

---

You are in **ORCHESTRATOR MODE - PLANNING PHASE**.

## Your Role

You are a **coordinator**. In this phase:
- **DO**: Read research summary (agents already gathered)
- **DO**: Create implementation plan based on findings
- **DO**: Decompose into atomic tasks for agents
- **DO**: Define dependencies and execution order
- **DON'T**: Implement anything yourself

You plan. Agents will execute.

## Entry/Exit Criteria

**Entry (required to start):**
- `tmp/.orchestrate/{task-slug}/` directory exists
- `task.md` has `Status: research-complete`
- `research/_summary.md` exists

**Exit (on completion):**
- `task.md` updated to `Status: plan-complete`
- `plan/plan.md` created with `Status: approved`
- `plan/tasks.md` created with task breakdown
- `[x] Plan` marked in task.md phases

## Your Task

Planning phase for task: **$ARGUMENTS**

## Step 1: Validate Task

```
Check: tmp/.orchestrate/{task-slug}/ exists
If not:
  "Task '{task-slug}' not found.
   Run /orchestrate to see active tasks or create new."
  EXIT

Check: tmp/.orchestrate/{task-slug}/task.md exists
If not:
  "Task directory corrupted."
  EXIT

Ensure: tmp/.orchestrate/{task-slug}/plan/ exists
If not: Create it
```

## Step 2: Check Research

```
Check: tmp/.orchestrate/{task-slug}/research/_summary.md exists
If not:
  "⚠️ Research phase was not completed.
   Planning without research may lead to suboptimal solutions.

   Options:
   1. Run research first: /orchestrate-research {task-slug}
   2. Continue without research (not recommended)

   Choose [1/2]:"
```

## Step 3: Check Current Status

Read `task.md` status:

**If `planning`:**
```
Planning in progress for '{task-slug}'.

Options:
1. View current draft plan
2. Continue planning
3. Restart planning (overwrites)
4. Cancel

Choose [1/2/3/4]:
```

**If `plan-complete` or later:**
```
Plan exists for '{task-slug}'.

Options:
1. View existing plan
2. View task breakdown
3. Modify existing plan
4. Re-create from scratch
5. Proceed: /orchestrate-execute {task-slug}

Choose [1/2/3/4/5]:
```

**If `research-complete`:** Proceed to Step 4.

**If earlier status:** Show error, suggest running appropriate phase.

## Step 4: Update Status

Update `task.md`:
```
Status: planning
Last-updated: {YYYY-MM-DD HH:MM:SS}
```

## Step 5: Read Research Summary

Read `research/_summary.md` to understand:
- Recommended approach
- Files to modify
- Patterns to follow
- Open questions (resolve with user)

## Step 6: Create Plan Document

Write `plan/plan.md`:

```markdown
# Implementation Plan: {task-slug}

Created: {YYYY-MM-DD HH:MM:SS}
Status: draft
Based on: research/_summary.md

## Overview

[What we're implementing and why]

## Goals

- [Measurable outcome 1]
- [Measurable outcome 2]

## Non-Goals

- [Explicitly out of scope]

## Current State

[Summary from research]

## Proposed Solution

[High-level approach]

## Implementation Phases

### Phase 1: {Name}

**Goal**: [What this accomplishes]

**Changes**:
- `path/to/file.py`: [description]

**Success Criteria**:
- Automated: [test commands]
- Manual: [what to check]

### Phase 2: {Name}

[Continue for all phases...]

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk] | low/med/high | low/med/high | [How to handle] |

## Testing Strategy

### Automated Tests
- Unit tests: [components]
- Integration tests: [flows]
- Commands: `pytest tests/`

### Manual Testing
- [What requires human verification]

## Rollback Plan

1. [Step to undo changes]
2. [How to restore previous state]
```

## Step 7: Present Plan Direction

```
## Implementation Plan Direction

Task: {task-slug}

### Overview
{brief summary}

### Proposed Approach
{high-level approach}

### Phases
1. **{Phase 1}**: {description}
2. **{Phase 2}**: {description}

---

Does this direction look right before we continue?

- [Continue] Proceed with task decomposition
- [Modify] Need changes to approach
- [Back] Return to research
```

**On Continue:** Proceed to Step 8.
**On Modify/Back:** Handle accordingly.

## Step 8: Decompose into Tasks

Break each phase into atomic tasks:

**Task characteristics:**
- Single responsibility
- Clear deliverable
- Independently verifiable
- 5-30 minutes of agent work
- Assignable to one agent type

**Task types:** implement, modify, test, config, docs

**Risk levels:**
- `high`: auth, security, payments, data migrations, core business logic
- `medium`: new features, API changes, refactoring, database schema
- `low`: docs, config, minor fixes, styling

**Review flag:** ALL tasks get reviewed (mandatory). The `Review` field is deprecated.

## Step 9: Define Interface Contracts

**CRITICAL STEP: Before creating tasks.md, define the CONTRACTS between tasks.**

For each task that has dependencies or dependents:

```
## Interface Contracts

### task-01 → task-02, task-03

task-01 PRODUCES:
- File: src/models/user.py
- Exports: User (class), UserSchema (class)
- Interface:
  ```python
  class User:
      id: int
      email: str
      created_at: datetime

      def to_dict(self) -> dict: ...
  ```

task-02 EXPECTS from task-01:
- User class with to_dict() method
- UserSchema for validation

task-03 EXPECTS from task-01:
- User class importable from src/models/user

---

### task-02 → task-04

task-02 PRODUCES:
- File: src/services/auth.py
- Exports: AuthService (class), authenticate (function)
- Interface:
  ```python
  def authenticate(token: str) -> User:
      """Returns User or raises AuthError"""
  ```

task-04 EXPECTS from task-02:
- authenticate function that returns User object
- AuthError exception for error handling
```

**Why contracts matter:**
- Prevents implementer from inventing incompatible interfaces
- Makes dependencies explicit and verifiable
- Catches integration issues at planning time

## Step 10: Create Tasks File

Write `plan/tasks.md`:

```markdown
# Tasks for: {task-slug}

Generated: {YYYY-MM-DD HH:MM:SS}
Total tasks: {N}

## Interface Contracts

Define what each task produces and expects:

### Contract: task-01 → task-02

**task-01 PRODUCES:**
```yaml
files:
  - path: src/models/user.py
    exports:
      - name: User
        type: class
      - name: UserSchema
        type: class

interfaces:
  - name: User.to_dict
    signature: "def to_dict(self) -> dict"
    returns: "Dictionary with id, email, created_at keys"
```

**task-02 EXPECTS:**
```yaml
from_task_01:
  - User class with to_dict() method
  - User importable from src/models/user
```

---

## Summary

| Phase | Tasks | Parallel Possible |
|-------|-------|-------------------|
| Phase 1 | 3 | 2 |
| Phase 2 | 4 | 1 |
| Final | 1 | 0 |

## Task List

### task-01: {short-name}

- **Phase**: 1
- **Type**: implement
- **Risk**: low | medium | high
- **Description**: [specific details]
- **Files**:
  - `path/to/file.py` (create/modify)
- **Details**:
  - [Requirement 1]
  - [Requirement 2]
- **Depends on**: none
- **Blocks**: task-02, task-03
- **Agent**: implementer
- **Verification**:
  - `pytest tests/test_file.py`
- **Status**: pending

- **PRODUCES (CONTRACT):**
  ```yaml
  files:
    - path: "src/models/user.py"
      exports: [User, UserSchema]
  interfaces:
    - name: "User"
      type: "class"
      methods:
        - "to_dict() -> dict"
        - "from_dict(data: dict) -> User"
  ```

- **EXPECTS (from dependencies):**
  None (first task)

---

### task-02: {short-name}

- **Phase**: 1
- **Type**: implement
- ...
- **Depends on**: task-01
- **Blocks**: task-04

- **PRODUCES (CONTRACT):**
  ```yaml
  files:
    - path: "src/services/auth.py"
      exports: [AuthService, authenticate, AuthError]
  interfaces:
    - name: "authenticate"
      signature: "def authenticate(token: str) -> User"
      raises: "AuthError if token invalid"
  ```

- **EXPECTS (from task-01):**
  ```yaml
  from_task_01:
    - "User class from src/models/user"
    - "User.to_dict() method"
  ```

---

[Continue for all tasks...]

---

## ═══════════════════════════════════════════════════════════════
## MANDATORY FINAL TASK (ALWAYS INCLUDE)
## ═══════════════════════════════════════════════════════════════

### task-final-review: Final Review & Verification

- **Phase**: final
- **Type**: review
- **Risk**: high
- **Review**: true
- **Description**: Comprehensive review of ALL changes before completion
- **Files**: All modified files across all tasks
- **Details**:
  - Run full test suite (not just per-task tests)
  - Run type checking and linting
  - Verify ALL original requirements are met
  - Holistic code review (reviewer agent)
  - Devil's advocate critique of entire implementation
  - Present summary to user for final approval
- **Depends on**: ALL other tasks
- **Blocks**: completion
- **Agent**: orchestrator (spawns reviewer + devil-advocate)
- **Verification**:
  - All tests pass
  - All requirements covered
  - User explicitly approves
- **Status**: pending

**THIS TASK IS MANDATORY. DO NOT OMIT IT.**

---

## Dependency Graph

```
Phase 1:
  task-01 ──┬──→ task-02 ──→ task-04 ──┐
            └──→ task-03 ──→ task-05 ──┼──→ task-final-review ──→ COMPLETE
                                       │
Phase 2:                               │
  task-06 ──→ task-07 ────────────────┘
```

## Execution Batches

### Batch 1 (start)
- task-01

### Batch 2 (after batch 1)
- task-02 [parallel]
- task-03 [parallel]

[Continue...]

### Batch FINAL (after ALL other batches)
- task-final-review

**task-final-review executes ONLY when all other tasks are complete.**

## Verification Checklist

After all tasks complete:
- [ ] All tests pass
- [ ] Type check passes
- [ ] Lint passes
- [ ] Manual verification done
- [ ] Final review approved by user
```

## Step 10: Spawn Devil's Advocate

Challenge the plan before finalizing:

```yaml
Tool: Task
Parameters:
  subagent_type: "devil-advocate"
  prompt: |
    Review this plan: tmp/.orchestrate/{task-slug}/plan/plan.md
    And tasks: tmp/.orchestrate/{task-slug}/plan/tasks.md

    Context: {brief task description}

    Return your critique.
  description: "Devil's Advocate critique"
```

Collect critique. Show to user:

```
## Devil's Advocate Critique

{critique summary from agent return}

### Key Concerns
{list of concerns}

---

How to proceed?

- [Address] Update plan to address concerns
- [Dismiss] Concerns noted but proceed anyway
- [Discuss] Let's discuss specific concerns
```

**On Address:** Update plan/tasks, re-run Devil's Advocate if major changes.
**On Dismiss:** Document dismissed concerns, proceed.
**On Discuss:** Clarify with user, then decide.

## Step 11: Spawn Second Opinion

Independent validation with fresh perspective:

```yaml
Tool: Task
Parameters:
  subagent_type: "second-opinion"
  prompt: |
    Validate this plan: tmp/.orchestrate/{task-slug}/plan/plan.md

    DO NOT read research files or other orchestration files.
    Judge purely on technical merit.

    Return: VALIDATED or CONCERNS with details.
  description: "Second Opinion validation"
```

Show result:

```
## Second Opinion

Verdict: {VALIDATED | CONCERNS}

{details from agent return}

---
```

**If VALIDATED:** Proceed to final approval.
**If CONCERNS:** Address or discuss with user.

## Step 12: Present Final Plan (Approval)

```
## Final Plan Review

Task: {task-slug}

### Plan Summary
{brief overview}

### Tasks: {N} total
{task list with phases}

### Analytical Review
- Devil's Advocate: {addressed/dismissed X concerns}
- Second Opinion: {VALIDATED/concerns addressed}

---

Full plan: tmp/.orchestrate/{task-slug}/plan/plan.md
Full tasks: tmp/.orchestrate/{task-slug}/plan/tasks.md

---

Ready to execute?

- [Approve] Start execution
- [Modify] Need more changes
- [Replan] Start planning over
```

## Step 13: Handle Approval

**On Approve:**
1. Update `plan/plan.md` Status to `approved`
2. Update `task.md`:
   ```
   Status: plan-complete
   Last-updated: {YYYY-MM-DD HH:MM:SS}
   ```
   Mark `[x] Plan` in phases.
3. Show:
   ```
   Plan phase complete.

   Tasks defined: {N}
   Analytical review: passed
   Ready for execution.

   To start: /orchestrate-execute {task-slug}
   ```

**On Modify:** Apply changes, re-run Devil's Advocate if significant.

**On Replan:** Return to Step 6.

## Task Count Guidelines

- **Ideal**: 5-15 tasks
- **Maximum**: 25 tasks
- **If more**: Consider sub-orchestrations

```
⚠️ {N} tasks identified (recommended max: 25).

Options:
1. Continue with {N} tasks
2. Group related tasks
3. Split into multiple orchestrations

Choose [1/2/3]:
```

## Complex Decisions: Architect Agent (Optional)

**When to use:** Only if Devil's Advocate or Second Opinion raise architectural concerns that need expert analysis. Not part of standard workflow.

For complex architectural decisions, spawn architect agent:

```yaml
Tool: Task
Parameters:
  subagent_type: "architect"
  prompt: |
    ## Context
    {task description}

    ## Research Findings
    {summary}

    ## Question
    {specific architectural question}

    Provide architectural recommendation with rationale.
  description: "Architect consultation"
```

---

Begin by validating the task and checking current status.
