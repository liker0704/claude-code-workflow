# Orchestrate Execute Command

Phase 3: Execute the plan through specialized agents.

---

You are in **ORCHESTRATOR MODE - EXECUTION PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Spawn implementer/tester/reviewer agents, track progress, pass context between tasks
- **DON'T**: Write code yourself, read agent report files unless fallback needed

## Entry/Exit Criteria

**Entry:** `task.md` has `Status: plan-complete`, `plan/plan.md` approved, `plan/tasks.md` exists
**Exit:** `task.md` updated to `Status: complete`, all tasks done, `[x] Execute` marked

## Lazy Reading Rule

Read agent report files ONLY when:
- Agent returns FAILED/BLOCKED without details
- Conflict detected (same file modified by 2+ tasks)
- Resume validation needed

Otherwise use agent return summaries.

## Your Task

Execute plan for task: **$ARGUMENTS**

## Configuration

```yaml
task_timeout: 600000      # 10 minutes per task
max_parallel_tasks: 3
```

## Review Strategy

**ALL reviews are MANDATORY BLOCKING GATES. Cannot proceed without approval.**

### Pipeline (ENFORCED)

```
implementer → tester → REVIEW GATE → complete
                          ↓
                    BLOCKED until APPROVED
```

### Task-Level Review

After every task completes:

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    Review task-{XX}: tmp/.orchestrate/{task-slug}/execution/task-{XX}-{name}.md
    Checklist: patterns, bugs, error handling, tests, security
    Output to: tmp/.orchestrate/{task-slug}/execution/task-{XX}-review.md
    Verdict: APPROVED | NEEDS_CHANGES | BLOCKED
  description: "Review task-{XX}"
```

**NEEDS_CHANGES:** Fix → re-test → re-review. DO NOT proceed until APPROVED.

### Batch-Level Review

After all tasks in batch complete:

**Mode Selection:**
- LIGHT: All tasks low risk → git diff + summaries only
- DEEP: Any high/medium risk OR conflict detected → full report reading

**Conflict Detection (before review):**
```
Collect modified files from each task
If same file modified by 2+ tasks → force DEEP mode
```

```yaml
# LIGHT
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    Batch {N} light review: git diff, check for conflicts, verify tests pass
    Verdict: APPROVED | NEEDS_DEEP_REVIEW
  description: "Light review batch {N}"

# DEEP
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    Batch {N} deep review: Read all reports in execution/
    Check: integration, conflicts, architecture, security
    Output to: execution/batch-{N}-review.md
    Verdict: APPROVED | NEEDS_CHANGES | BLOCKED
  description: "Deep review batch {N}"
```

**Batch must be APPROVED before next batch starts.**

## Step 1: Validate Task

```
Check: tmp/.orchestrate/{task-slug}/ exists
Check: plan/plan.md has "Status: approved"
Check: plan/tasks.md exists
Create: execution/ directory if missing
```

## Step 2: Check Current Status

**If `executing`:** Offer resume/view progress/pause/abort
**If `complete`:** Offer view summary/re-execute/verify/archive
**If `plan-complete`:** Proceed to Step 3
**Otherwise:** Error, suggest appropriate phase

## Step 3: Initialize Execution

Update `task.md` to `Status: executing`

Create `execution/_progress.md`:
```markdown
# Execution Progress: {task-slug}
Started: {timestamp}
- Total: {N}, Completed: 0, In progress: 0, Pending: {N}

| Task | Status | Agent | Started | Updated |
|------|--------|-------|---------|---------|
| task-01 | ⏳ pending | - | - | - |
```

## Step 4: Read Task Definitions

Parse `plan/tasks.md` for: task list, dependencies, batches, agent assignments, verification commands

## Execution Loop

### Ready Tasks

Task is ready when: status=pending, all dependencies complete, not blocked

### Execute Batch (up to 3 parallel)

**Pre-Implementation: Gather Context**

BEFORE spawning implementer, collect from all dependencies:
- files_created, exports, interfaces, usage_example

### Implementer Template

```yaml
Tool: Task
Parameters:
  subagent_type: "implementer"
  prompt: |
    ## Task: task-{XX}: {name}
    Description: {from tasks.md}
    Files: {to modify}
    Requirements: {specific}
    Patterns: {from research}

    ## FROM DEPENDENCIES (CRITICAL)
    {For each dep: files created, exports, interfaces, usage}
    USE EXACTLY these interfaces.

    ## YOU MUST PRODUCE (CONTRACT)
    Files: {you create}, Exports: {you export}, Interface: {signatures}

    ## Verification
    {commands to run}

    ## OUTPUT (CRITICAL)
    Write to: tmp/.orchestrate/{task-slug}/execution/task-{XX}-{name}.md

    Include:
    1. Files Changed (table)
    2. Implementation Summary
    3. Test Results
    4. Issues
    5. FOR DEPENDENTS:
       ```yaml
       files_created: [{path, description}]
       exports: [{name, type, signature, location}]
       interfaces: [{name, signature, usage}]
       config_changes: [{file, key, required}]
       patterns_to_follow: [...]
       ```
  run_in_background: true
  description: "Execute task-{XX}"
```

### Tester Template

```yaml
Tool: Task
Parameters:
  subagent_type: "tester"
  prompt: |
    Test task-{XX}: {summary from implementer}
    Files: {from implementer}
    Verification: {commands from tasks.md}
    Output to: tmp/.orchestrate/{task-slug}/execution/task-{XX}-test.md
    Return: pass/fail counts, coverage, failed test details
  description: "Test task-{XX}"
```

### Track Progress

Save to `execution/_tasks.json`:
```json
{"in_progress": {"task-05": {"task_id": "xyz", "agent": "implementer"}}, "completed_ids": ["task-01"]}
```

Update `_progress.md` as tasks execute.

### Handle Completion

1. Check success
2. Run verification
3. Update status
4. Write report
5. Find newly ready tasks
6. Continue

## Handling Failures

**Verification fails:** Retry / Debug with stuck agent / Skip / Abort
**Timeout (>10min):** Keep waiting / Check status / Cancel / Mark blocked
**Agent error:** Retry / Different approach / Escalate / Skip

## FINAL REVIEW (MANDATORY)

When all tasks finish, perform comprehensive final review.

### F1: Generate Summary

```bash
git diff HEAD~{N}..HEAD --stat
```

Create `execution/_final-summary.md` with all changes, tasks completed, requirements coverage.

### F2: Comprehensive Verification

```bash
pytest tests/ -v
mypy src/ || true
ruff check . || true
npm run build || cargo build || go build ./... || true
```

**If fails:** Fix before proceeding.

### F3: Holistic Review

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    Final review: {task-slug}
    Read: task.md, plan.md
    Run: git diff HEAD~{N}..HEAD
    Check: requirements coverage, code consistency, integration, quality, tests
    Output to: execution/_final-review.md
    Return: requirements X/Y, issues count, verdict APPROVED|NEEDS_CHANGES
  description: "Final holistic review"
```

### F4: Devil's Advocate

```yaml
Tool: Task
Parameters:
  subagent_type: "devil-advocate"
  prompt: |
    Devil's advocate: {task-slug}
    Read: task.md, _final-review.md
    Run: git diff HEAD~{N}..HEAD
    Find: production issues, security, edge cases, hidden assumptions, failure modes, maintainability
    Output to: execution/_devils-advocate.md
    Return: risk level, critical/major concerns, verdict APPROVE_WITH_NOTES|RECOMMEND_CHANGES|BLOCK
  description: "Devil's advocate final"
```

### F5: Present to User

```
FINAL REVIEW COMPLETE

Task: {task-slug}
Tasks: {N}/{N}, Files: {X}, Lines: +{add} -{rem}

Verification: Tests ✅ | Types ✅ | Lint ✅ | Build ✅
Holistic Review: {verdict}
Devil's Advocate: Risk {level}

Review: git diff HEAD~{N}..HEAD
Reports: execution/_final-*.md

[Complete] Approve | [Fix] Address concerns | [Revert] Undo
```

**WAIT FOR USER APPROVAL.**

### F6: On Approval

Update `task.md` to `Status: complete`, mark `[x] Execute`

```
TASK COMPLETED: {task-slug}
[x] Research [x] Plan [x] Execute
Next: git commit or /commit
```

## Session Resume

Use **file existence + validation** (task IDs don't persist):

```
For each task in tasks.md:
  task-{XX}-{name}.md VALID → implementer done
  task-{XX}-test.md VALID → tester done
  task-{XX}-review.md VALID → review done
  File EXISTS but INVALID → re-run that step

Validation rules:
  Implementer: len>100, has "IMPLEMENTATION COMPLETE" or "IMPLEMENTATION BLOCKED", has "## Status"
  Tester: len>100, has "## Test Results" or "## Verification"
  Reviewer: len>100, has "## Review" or "Verdict:", has "APPROVED" or "NEEDS_CHANGES" or "BLOCKED"
```

---

Begin by validating the task and checking plan approval.
