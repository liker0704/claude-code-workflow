# Orchestrate Execute Command

Phase 3: Execute the plan through specialized agents.

**IMPORTANT:** First read `~/.claude/orchestrator-rules.md` for critical orchestration rules.

---

You are in **ORCHESTRATOR MODE - EXECUTION PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Spawn implementer/tester/reviewer agents, track progress, pass context between tasks
- **DO**: Wait for ALL agents to complete before proceeding to next phase
- **DON'T**: Write code yourself
- **DON'T**: Read agent output files while agents are running

---

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

### Batch-Level Review (ALWAYS FULL)

After ALL tasks in batch complete, run FULL review.

**No light/deep modes. Always comprehensive review.**

**Conflict Detection (before review):**
```
Collect modified files from each task
If same file modified by 2+ tasks → flag for reviewer
```

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## BATCH REVIEW: Batch {N}

    Task: {task-slug}
    Tasks in batch: {list of task-XX}

    ## REVIEW SCOPE

    Review ALL changes from this batch:

    1. Read task reports: execution/task-{XX}-*.md
    2. Run: git diff HEAD~{batch_commits}
    3. Check integration between tasks in batch
    4. Check consistency with architecture.md (if exists)

    ## CHECKLIST

    - [ ] All tasks completed successfully
    - [ ] Tests pass after batch
    - [ ] No conflicts between tasks
    - [ ] Code follows project patterns
    - [ ] No security issues introduced
    - [ ] Changes match plan

    ## OUTPUT

    Write to: execution/batch-{N}-review.md

    ### Verdict: APPROVED | NEEDS_CHANGES | BLOCKED

    ### Summary
    {what was done in this batch}

    ### Issues Found
    | Issue | Severity | Task | Action |
    |-------|----------|------|--------|

  description: "Review batch {N}"
```

**Batch MUST be APPROVED before next batch starts.**
**If NEEDS_CHANGES:** Fix issues → re-run batch review.
**If BLOCKED:** Stop execution, escalate to user.

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

## Step 4.5: Load Architecture Scope (NEW)

If `architecture.md` exists in task directory:

1. Parse Components table to get expected files:
```python
architecture_scope = {
    "create": ["src/path/new.ts", ...],    # Files marked CREATE
    "modify": ["src/path/existing.ts", ...],  # Files marked MODIFY
    "delete": ["src/path/old.ts", ...]     # Files marked DELETE
}
```

2. Store for scope checking during execution.

**If architecture.md missing or was skipped:** Skip scope checking.

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
    | Type | Name | Details |
    |------|------|---------|
    | File | {path} | {description} |
    | Export | {name} | {signature} |

    ## IMPLEMENTATION PROCESS (MANDATORY)

    ### Step 1: Understand First
    BEFORE writing code:
    - Read ALL files you will modify
    - Read interface contracts from dependencies
    - List your assumptions

    ### Step 2: Plan
    Write brief implementation plan:
    - What changes to each file?
    - What could go wrong?

    ### Step 3: Implement
    Write the code.

    ### Step 4: Self-Review (Chain-of-Verification)
    For each change:
    - Does it follow project patterns? (check existing code)
    - Does it handle errors?
    - Does it match interface contract?

    ### Step 5: Test
    Run: {verification commands}

    ## OUTPUT FORMAT

    Write to: tmp/.orchestrate/{task-slug}/execution/task-{XX}-{name}.md

    ```markdown
    # Task Report: task-{XX}

    ## Status
    IMPLEMENTATION COMPLETE | IMPLEMENTATION BLOCKED

    ## Understanding Phase
    **Files read**: {list}
    **Assumptions**: {list}

    ## Implementation Plan
    {brief plan}

    ## Changes Made
    | File | Type | Description |
    |------|------|-------------|

    ## Self-Review
    - Patterns followed: ✅/❌
    - Error handling: ✅/❌
    - Contract matched: ✅/❌

    ## Verification
    **Command**: {what ran}
    **Result**: PASS / FAIL
    **Output**: {summary}

    ## FOR DEPENDENTS

    ### Files Created
    | File | Exports |
    |------|---------|

    ### Interfaces
    | Name | Signature | Usage |
    |------|-----------|-------|

    ### Config Changes
    | File | Key | Required |
    |------|-----|----------|

    ## Concerns
    - {any risks or issues}
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
3. **Scope check (if architecture exists)**
4. Update status
5. Write report
6. Find newly ready tasks
7. Continue

### Scope Check (NEW)

After task completes, if `architecture_scope` is loaded:

```python
# Get files modified by this task (from task report "## Changes Made" table)
task_files = extract_modified_files(task_report)

for file in task_files:
    all_expected = (
        architecture_scope.get("create", []) +
        architecture_scope.get("modify", []) +
        architecture_scope.get("delete", [])
    )
    if file not in all_expected:
        # File not in architecture
        show_warning(file)
```

**Warning format:**
```
⚠️ Scope Warning

File `{path}` was modified but not in architecture.md

This may indicate scope creep or missing architecture update.

Options:
1. [Continue] Proceed (file is legitimate addition)
2. [Update] Add to architecture.md
3. [Revert] Undo this change
4. [Stop] Pause execution for review
```

**If user selects Update:** Add file to architecture.md Components table.
**If user selects Continue:** Log warning and proceed.
**If user selects Revert:** Run `git checkout -- {file}` and re-run task.
**If user selects Stop:** Set status to `blocked`.

## Handling Failures

**Verification fails:** Retry / Debug with stuck agent / Skip / Abort
**Timeout (>10min):** Keep waiting / Check status / Cancel / Mark blocked
**Agent error:** Retry / Different approach / Escalate / Skip

## FINAL REVIEW (MANDATORY - MULTI-AGENT)

When all tasks finish, perform comprehensive final review with **4 parallel reviewers**.

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

### F3: Spawn 4 Reviewers (PARALLEL)

Spawn ALL 4 reviewers simultaneously:

#### 1. Code Quality Reviewer

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## CODE QUALITY REVIEW

    Task: {task-slug}

    Run: git diff HEAD~{N}..HEAD
    Read: plan/plan.md for context

    ## CHECK

    - [ ] Code follows project patterns (check existing code)
    - [ ] No code duplication (DRY)
    - [ ] Functions are focused (single responsibility)
    - [ ] Error handling is consistent
    - [ ] Tests exist for new code
    - [ ] Tests are meaningful (not just coverage)
    - [ ] No TODO/FIXME left without ticket
    - [ ] No commented-out code
    - [ ] Naming is clear and consistent

    ## OUTPUT

    Write to: execution/_final-code-quality.md

    ### Verdict: PASS | ISSUES | FAIL

    ### Issues Found
    | File | Line | Issue | Severity |
    |------|------|-------|----------|

  run_in_background: true
  description: "Final review: code quality"
```

#### 2. Security Reviewer

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## SECURITY REVIEW

    Task: {task-slug}

    Run: git diff HEAD~{N}..HEAD
    Focus: Security vulnerabilities

    ## CHECK (OWASP Top 10 + common issues)

    - [ ] No SQL injection (parameterized queries?)
    - [ ] No XSS (output encoding?)
    - [ ] No secrets in code (API keys, passwords)
    - [ ] Auth checks on protected routes
    - [ ] Input validation on user data
    - [ ] No path traversal vulnerabilities
    - [ ] No insecure deserialization
    - [ ] Rate limiting where needed
    - [ ] Proper error messages (no stack traces to users)
    - [ ] HTTPS/TLS requirements met

    ## OUTPUT

    Write to: execution/_final-security.md

    ### Verdict: PASS | ISSUES | FAIL

    ### Vulnerabilities Found
    | File | Line | Vulnerability | Severity | Fix |
    |------|------|---------------|----------|-----|

  run_in_background: true
  description: "Final review: security"
```

#### 3. Requirements Reviewer

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## REQUIREMENTS REVIEW

    Task: {task-slug}

    Read: task.md (original requirements)
    Read: plan/plan.md (implementation plan)
    Read: architecture.md (if exists)
    Run: git diff HEAD~{N}..HEAD

    ## CHECK

    - [ ] All goals from task.md addressed
    - [ ] All tasks from plan completed
    - [ ] Architecture decisions followed
    - [ ] No scope creep (extra stuff not in plan)
    - [ ] No scope miss (stuff in plan not done)
    - [ ] Success criteria met
    - [ ] Edge cases from plan handled

    ## OUTPUT

    Write to: execution/_final-requirements.md

    ### Coverage
    | Requirement | Status | Evidence |
    |-------------|--------|----------|

    ### Verdict: COMPLETE | PARTIAL | INCOMPLETE

  run_in_background: true
  description: "Final review: requirements"
```

#### 4. Devil's Advocate

```yaml
Tool: Task
Parameters:
  subagent_type: "devil-advocate"
  prompt: |
    ## DEVIL'S ADVOCATE REVIEW

    Task: {task-slug}

    Run: git diff HEAD~{N}..HEAD

    ## YOUR MISSION

    Find problems others might miss. Be critical.

    ## CHECK

    - What can break in production?
    - What edge cases are missed?
    - What assumptions are wrong?
    - What happens under load?
    - What happens with bad/malicious input?
    - What happens if external service fails?
    - What's the worst case scenario?
    - Hidden dependencies?
    - Technical debt introduced?

    ## OUTPUT

    Write to: execution/_final-devils-advocate.md

    ### Risk Level: LOW | MEDIUM | HIGH | CRITICAL

    ### Concerns
    | Concern | Severity | Likelihood | Impact |
    |---------|----------|------------|--------|

    ### Verdict: APPROVE_WITH_NOTES | RECOMMEND_CHANGES | BLOCK

  run_in_background: true
  description: "Final review: devil's advocate"
```

### F4: Wait for All Reviewers

```
1. TaskOutput(code-quality, block=true) → wait
2. TaskOutput(security, block=true) → wait
3. TaskOutput(requirements, block=true) → wait
4. TaskOutput(devils-advocate, block=true) → wait
5. ALL done → read all reports
```

### F5: Aggregate Results

Read all `_final-*.md` files and aggregate:

| Reviewer | Verdict | Critical Issues |
|----------|---------|-----------------|
| Code Quality | {PASS/ISSUES/FAIL} | {count} |
| Security | {PASS/ISSUES/FAIL} | {count} |
| Requirements | {COMPLETE/PARTIAL/INCOMPLETE} | {count} |
| Devil's Advocate | {APPROVE/RECOMMEND_CHANGES/BLOCK} | {count} |

### F6: Present to User

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FINAL MULTI-AGENT REVIEW COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task: {task-slug}
Tasks: {N}/{N}, Files: {X}, Lines: +{add} -{rem}

Verification: Tests ✅ | Types ✅ | Lint ✅ | Build ✅

### Review Results
| Reviewer | Verdict | Issues |
|----------|---------|--------|
| Code Quality | ✅ PASS | 0 |
| Security | ⚠️ ISSUES | 2 minor |
| Requirements | ✅ COMPLETE | 0 |
| Devil's Advocate | ⚠️ CONCERNS | 1 edge case |

### Action Required
{List any issues that need attention}

### Reports
- execution/_final-code-quality.md
- execution/_final-security.md
- execution/_final-requirements.md
- execution/_final-devils-advocate.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Complete] Approve and finish
[Fix] Address issues first
[Revert] Undo all changes
```

**WAIT FOR USER APPROVAL.**

### F7: On Approval

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
