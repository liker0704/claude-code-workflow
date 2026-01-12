# Orchestrate Execute Command

Phase 3: Execute the plan through specialized agents.

---

You are in **ORCHESTRATOR MODE - EXECUTION PHASE**.

## Your Role

You are a **coordinator**. In this phase:
- **DO**: Spawn implementer/tester/reviewer agents for each task
- **DO**: Run tasks in parallel where dependencies allow
- **DO**: Track progress using agent return summaries
- **DO**: Pass "For Dependents" info to dependent tasks
- **DON'T**: Write code yourself (implementer agent does this)
- **DON'T**: Read agent report files (use their return summaries)

You orchestrate. Agents implement.

## Entry/Exit Criteria

**Entry (required to start):**
- `tmp/.orchestrate/{task-slug}/` directory exists
- `task.md` has `Status: plan-complete`
- `plan/plan.md` exists with `Status: approved`
- `plan/tasks.md` exists with task breakdown

**Exit (on completion):**
- `task.md` updated to `Status: complete`
- All tasks in `execution/task-*.md` files
- All tests passed
- `[x] Execute` marked in task.md phases

## Lazy Reading Rule

```
READ agent report file ONLY when:
✅ Agent returns FAILED/BLOCKED AND return summary lacks details
✅ Agent returns empty/malformed summary (fallback)
✅ User explicitly asks "show me the report" or "details"
✅ Conflict detected: same file modified by 2+ tasks
✅ Resume validation: checking if existing file is valid

NEVER read file when:
❌ Agent returns SUCCESS with complete summary
❌ Agent returns PARTIAL with actionable summary
❌ Moving to next task (use summary)
❌ Batch completed normally (summaries sufficient)
❌ Updating status (use in-memory state)
```

**Decision Tree:**
```
Agent completed:
  ↓
Return summary present and complete?
  YES → Use summary, DON'T read file
  NO  → READ file (fallback)
  ↓
Status is FAILED/BLOCKED?
  YES → Summary has error details?
        YES → Use summary
        NO  → READ file for debug info
  NO  → Continue with summary
```

## Your Task

Execute plan for task: **$ARGUMENTS**

## Configuration

```yaml
task_timeout: 600000      # 10 minutes per task
max_parallel_tasks: 3     # Max concurrent tasks
```

## Review Strategy

### Task Pipeline

Each task follows this pipeline:
```
implementer → tester → [task review] → complete
```

### Task-Level Review

Triggered when task has `Review: true` in tasks.md.
- Happens immediately after tester completes
- Catches issues before they affect dependent tasks
- Uses `reviewer` agent

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## Task Review: task-{XX}

    ### Implementation Report
    Read: tmp/.orchestrate/{task-slug}/execution/task-{XX}-{name}.md

    ### Files Changed
    {list of files from report}

    ### Review Checklist
    - Code follows project patterns
    - No obvious bugs or issues
    - Error handling adequate
    - Tests cover main paths
    - No security vulnerabilities

    ### Output
    Write review to: tmp/.orchestrate/{task-slug}/execution/task-{XX}-review.md

    Final verdict: APPROVED | NEEDS_CHANGES | BLOCKED
    If NEEDS_CHANGES: list specific fixes required
  description: "Review task-{XX}"
```

**If NEEDS_CHANGES:** spawn implementer to fix, then re-test, re-review.

### Batch-Level Review

**ALWAYS** happens after all tasks in a batch complete.
- Reviews integration of all batch changes together
- Ensures no conflicts between parallel tasks
- Uses `reviewer` agent with broader scope

#### Review Mode Selection

Determine mode based on batch risk:

**LIGHT mode** (low-risk batches):
- All tasks are low risk
- No architectural changes
- Uses: git diff + agent summaries only

**DEEP mode** (high-risk batches):
- Any task is high/medium risk
- Architectural or security changes
- Uses: full report reading + verification

**Field Validation (before selection):**
```
For each task in batch:
  if task.risk is missing:
    task.risk = "medium"  # Default: assume medium risk
    log: "Warning: task-{XX} missing risk field, defaulting to medium"

  if task.risk not in ["low", "medium", "high"]:
    task.risk = "medium"  # Invalid value → default
    log: "Warning: task-{XX} invalid risk '{value}', defaulting to medium"

  if task.type is missing:
    task.type = "feature"  # Default type
```

**Selection Algorithm:**
```
For each task in batch:
  Check task.risk from tasks.md (low | medium | high)

If ANY task has risk == "high":
  → DEEP mode
Else if ANY task has risk == "medium" AND task.type in [security, auth, database]:
  → DEEP mode
Else:
  → LIGHT mode
```

**Pre-Review: Conflict Detection**
```
Before spawning reviewer, check for file conflicts:

1. Collect modified files from each task's "For Dependents" section
2. Run: git diff --name-only {commit-before-batch}..HEAD
3. Check for overlap:
   - If same file modified by 2+ tasks → potential conflict
   - If conflict detected → force DEEP mode + flag for reviewer

conflict_check = {}
for task in batch:
    files = task.for_dependents.files_modified
    for f in files:
        if f in conflict_check:
            conflict_check[f].append(task.id)  # CONFLICT!
        else:
            conflict_check[f] = [task.id]

conflicts = {f: tasks for f, tasks in conflict_check.items() if len(tasks) > 1}
if conflicts:
    review_mode = "DEEP"
    add_to_prompt: "CONFLICTS DETECTED: {conflicts}"
```

```yaml
# LIGHT MODE
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## Batch Review (LIGHT): Batch {N}

    ### Tasks Completed
    {task IDs with return summaries}

    ### Changes
    Run: git diff {commit-before-batch}..HEAD

    ### Review Focus
    - No obvious conflicts
    - Tests still pass
    - No security red flags

    Verdict: APPROVED | NEEDS_DEEP_REVIEW
  description: "Light review batch {N}"

# DEEP MODE
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## Batch Review (DEEP): Batch {N}

    ### Task Reports
    Read all reports in: tmp/.orchestrate/{task-slug}/execution/

    ### Review Focus
    - Integration between tasks
    - No conflicting changes
    - Architectural integrity
    - Security implications
    - Error handling coverage

    ### Output
    Write review to: tmp/.orchestrate/{task-slug}/execution/batch-{N}-review.md

    Final verdict: APPROVED | NEEDS_CHANGES | BLOCKED
  description: "Deep review batch {N}"
```

**Batch must be APPROVED before next batch starts.**

### Review Flow Summary

```
Batch 1:
  task-01 → impl → test → complete
  task-02 → impl → test → [TASK REVIEW] → complete  (Review: true)
  task-03 → impl → test → complete
  ↓
  BATCH REVIEW (always)
  ↓
Batch 2:
  ...
```

## Step 1: Validate Task

```
Check: tmp/.orchestrate/{task-slug}/ exists
If not:
  "Task '{task-slug}' not found.
   Run /orchestrate to see active tasks."
  EXIT

Check: plan/plan.md exists AND has "Status: approved"
If not:
  "Cannot execute: plan not approved.
   Run /orchestrate-plan {task-slug} first."
  EXIT

Check: plan/tasks.md exists
If not:
  "Cannot execute: task breakdown not found."
  EXIT

Ensure: execution/ directory exists
```

## Step 2: Check Current Status

Read `task.md` status:

**If `executing`:**
```
Execution in progress for '{task-slug}'.

Progress:
- Completed: {X}/{N} tasks
- In progress: {Y}
- Pending: {Z}

Options:
1. Resume execution
2. View progress details
3. Pause and review
4. Abort execution

Choose [1/2/3/4]:
```

**If `complete`:**
```
Task '{task-slug}' is already complete.

Options:
1. View execution summary
2. Re-execute specific task
3. Run additional verification
4. Archive task

Choose [1/2/3/4]:
```

**If `plan-complete`:** Proceed to Step 3.

**If earlier status:** Show error, suggest running appropriate phase.

## Step 3: Initialize Execution

Update `task.md`:
```
Status: executing
Last-updated: {YYYY-MM-DD HH:MM:SS}
```

Create `execution/_progress.md`:
```markdown
# Execution Progress: {task-slug}

Started: {YYYY-MM-DD HH:MM:SS}
Last updated: {YYYY-MM-DD HH:MM:SS}

## Summary

- Total tasks: {N}
- Completed: 0
- In progress: 0
- Pending: {N}
- Blocked: 0

## Task Status

| Task | Status | Agent | Started | Updated |
|------|--------|-------|---------|---------|
| task-01 | ⏳ pending | - | - | - |
| task-02 | ⏳ pending | - | - | - |

## Current Activity

Starting execution...

## Blockers

None

## Next Steps

1. Execute task-01
```

## Step 4: Read Task Definitions

Parse `plan/tasks.md` to get:
- Task list with descriptions
- Dependencies between tasks
- Execution batches
- Agent assignments
- Verification commands

## Execution Loop

### Identify Ready Tasks

A task is ready when:
- Status is `pending`
- All dependencies are `complete`
- Not blocked

### Execute Batch

For ready tasks (up to 3 parallel):

```
## Executing Batch

Tasks starting:
- task-{XX}: {description}
- task-{YY}: {description}

[Starting {N} parallel agents...]
```

Spawn agents in parallel (single message, multiple Task calls):

```yaml
Tool: Task
Parameters:
  subagent_type: "implementer"
  prompt: |
    ## Task: task-{XX}: {short-name}

    ### Description
    {detailed description from tasks.md}

    ### Files to Modify
    {list of files}

    ### Requirements
    {specific requirements}

    ### Patterns to Follow
    {patterns from research}

    ### Verification
    After implementation, run:
    {verification commands}

    ### OUTPUT REQUIREMENTS (CRITICAL)
    Write your report to this EXACT path:
    tmp/.orchestrate/{task-slug}/execution/task-{XX}-{name}.md

    Rules:
    - Use this EXACT path - no modifications
    - Create parent directories if needed
    - Format: Markdown with sections below

    Include in report:
    1. Files changed (with change type)
    2. Brief summary of implementation
    3. Test results (pass/fail)
    4. Any issues encountered
    5. **For Dependents** section (CRITICAL for downstream tasks):
       - New files/exports created
       - API signatures introduced
       - Config changes needed
       - Patterns to follow
  run_in_background: true
  description: "Execute task-{XX}"
```

### Tester Spawn Template

After implementer completes, spawn tester:

```yaml
Tool: Task
Parameters:
  subagent_type: "tester"
  prompt: |
    ## Test: task-{XX}: {short-name}

    ### What Was Implemented
    {summary from implementer return}

    ### Files Changed
    {list from implementer return}

    ### From Implementer (For Dependents)
    {For Dependents section from implementer return}

    ### Verification Commands
    {verification commands from tasks.md}

    ### OUTPUT REQUIREMENTS (CRITICAL)
    Write your report to this EXACT path:
    tmp/.orchestrate/{task-slug}/execution/task-{XX}-test.md

    Return standard format with:
    - Test results (pass/fail counts)
    - Coverage if available
    - Failed test details with file:line
  description: "Test task-{XX}"
```

### Track Running Tasks

Save to `execution/_tasks.json`:
```json
{
  "last_updated": "YYYY-MM-DD HH:MM:SS",
  "in_progress": {
    "task-05": {
      "task_id": "xyz123",
      "agent": "implementer",
      "started": "YYYY-MM-DD HH:MM:SS"
    }
  },
  "completed_ids": ["task-01", "task-02"]
}
```

### Monitor Progress

Update `_progress.md` as tasks execute:
```markdown
## Task Status

| Task | Status | Agent | Started | Updated |
|------|--------|-------|---------|---------|
| task-01 | ✅ complete | implementer | 14:30:00 | 14:35:00 |
| task-02 | 🔄 in-progress | implementer | 14:35:00 | 14:40:00 |
| task-03 | ⏳ pending | - | - | - |

## Current Activity

Executing task-02: Modifying auth middleware...
```

### Handle Task Completion

When agent returns:
1. Check if succeeded
2. Run verification commands
3. Update status (complete or failed)
4. Write task report
5. Identify newly ready tasks
6. Continue loop

## Task Report Format

Each task creates `execution/task-{XX}-{name}.md`:

```markdown
# Task: task-{XX}-{name}

## Metadata

- Status: complete
- Agent: implementer
- Started: {timestamp}
- Completed: {timestamp}
- Duration: {X} minutes

## Implementation

### Files Changed

| File | Change | Lines | Description |
|------|--------|-------|-------------|
| path/file.py | modified | +45 -12 | Added auth |

### Summary

{Brief description of implementation}

## Verification

### Tests

```
$ pytest tests/test_auth.py
12 passed in 2.34s
```

- Tests passed: 12
- Tests failed: 0

## Issues

{Any problems and resolutions}
```

## Handling Failures

### Task Fails Verification

```
❌ Task task-{XX} failed verification.

Test output:
{error output}

Options:
1. Retry task
2. Debug with stuck agent
3. Skip and continue
4. Abort execution

Choose [1/2/3/4]:
```

### Task Times Out

```
⚠️ Task task-{XX} taking longer than 10 minutes.

Options:
1. Keep waiting
2. Check status
3. Cancel and retry
4. Mark as blocked

Choose [1/2/3/4]:
```

### Agent Error

```
❌ Agent error on task-{XX}:
{error message}

Options:
1. Retry
2. Try different approach
3. Escalate to stuck agent
4. Skip task

Choose [1/2/3/4]:
```

## Progress Display

```
## Execution Progress

Task: {task-slug}
Elapsed: {X} minutes

### Status
━━━━━━━━━━━━━━━━━━━━ 40% (4/10 tasks)

✅ task-01: Setup database schema
✅ task-02: Create user model
🔄 task-05: Implement API endpoints (in progress)
⏳ task-07: Integration tests

### Current Activity
- task-05: Creating POST /users endpoint...
```

## Completion

When all tasks finish, proceed to **MANDATORY Final Review**.

---

## ═══════════════════════════════════════════════════════════════
## FINAL REVIEW (MANDATORY)
## ═══════════════════════════════════════════════════════════════

**THIS SECTION IS NOT OPTIONAL. DO NOT SKIP.**

Before marking task as complete, you MUST perform comprehensive final review.

### Step F1: Generate Changes Summary

```bash
# Get full diff of all changes
git diff HEAD~{N}..HEAD --stat
git diff HEAD~{N}..HEAD
```

Create `execution/_final-summary.md`:
```markdown
# Final Summary: {task-slug}

## All Changes

| File | Lines Changed | Type |
|------|---------------|------|
| {file} | +{X} -{Y} | {added/modified/deleted} |

Total: {N} files, +{X} -{Y} lines

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| task-01 | {desc} | ✅ |
| task-02 | {desc} | ✅ |

## Requirements Coverage

Original requirements from task.md:
- [ ] {requirement 1} → implemented in task-XX
- [ ] {requirement 2} → implemented in task-YY
```

### Step F2: Run Comprehensive Verification

Run ALL verification, not just per-task:

```bash
# Full test suite
pytest tests/ -v

# Type checking (if applicable)
mypy src/ || true

# Linting (if applicable)
ruff check . || true

# Build (if applicable)
npm run build || cargo build || go build ./... || true
```

Document results:
```
### Verification Results

| Check | Status | Details |
|-------|--------|---------|
| Tests | ✅/❌ | {X} passed, {Y} failed |
| Types | ✅/❌ | {X} errors |
| Lint | ✅/❌ | {X} issues |
| Build | ✅/❌ | {result} |
```

**If any verification fails:** Fix before proceeding. Spawn implementer to fix issues.

### Step F3: Holistic Review (reviewer agent)

```yaml
Tool: Task
Parameters:
  subagent_type: "reviewer"
  prompt: |
    ## Final Holistic Review: {task-slug}

    ### Original Task
    Read: tmp/.orchestrate/{task-slug}/task.md
    Focus on: Description, Requirements

    ### Implementation Plan
    Read: tmp/.orchestrate/{task-slug}/plan/plan.md

    ### All Changes
    Run: git diff HEAD~{N}..HEAD

    ### Review Checklist

    1. **Requirements Coverage**
       - Does implementation satisfy ALL requirements from task.md?
       - Any requirements missed or partially implemented?

    2. **Code Consistency**
       - Consistent patterns across all changes?
       - No conflicting approaches in different tasks?
       - Naming conventions followed?

    3. **Integration**
       - Do all components work together?
       - No broken imports/references?
       - API contracts respected?

    4. **Quality**
       - Error handling adequate everywhere?
       - Edge cases covered?
       - No obvious bugs?

    5. **Tests**
       - Test coverage adequate?
       - Tests actually test the functionality?
       - No flaky or skipped tests?

    ### Output
    Write review to: tmp/.orchestrate/{task-slug}/execution/_final-review.md

    ### Return Summary
    ```
    ## Agent Summary
    Type: final-reviewer
    Status: SUCCESS | FAILED

    ## Output
    Requirements covered: {X}/{Y}
    Issues found: {count}
    Verdict: APPROVED | NEEDS_CHANGES

    ## Issues (if any)
    - {issue 1}
    - {issue 2}

    ## For Dependents
    Final review complete. Ready for devil's advocate.
    ```
  description: "Final holistic review"
```

**If NEEDS_CHANGES:** Fix issues, re-run this step.

### Step F4: Devil's Advocate (MANDATORY)

```yaml
Tool: Task
Parameters:
  subagent_type: "devil-advocate"
  prompt: |
    ## Devil's Advocate: Final Implementation Review

    Task: {task-slug}

    ### Context
    Read: tmp/.orchestrate/{task-slug}/task.md (original requirements)
    Read: tmp/.orchestrate/{task-slug}/execution/_final-review.md (holistic review)
    Run: git diff HEAD~{N}..HEAD (all changes)

    ### Your Mission

    Find problems the reviewer missed. Challenge everything.

    1. **What could go wrong in production?**
       - Race conditions?
       - Memory leaks?
       - Performance under load?

    2. **Security implications?**
       - New attack vectors?
       - Data exposure?
       - Input validation gaps?

    3. **Edge cases not covered?**
       - Empty/null inputs?
       - Concurrent access?
       - Network failures?

    4. **Hidden assumptions?**
       - About environment?
       - About data format?
       - About user behavior?

    5. **What happens when things fail?**
       - Error messages helpful?
       - Recovery possible?
       - Logs adequate?

    6. **Maintainability concerns?**
       - Will this be clear in 6 months?
       - Dependencies risky?
       - Technical debt introduced?

    ### Output
    Write critique to: tmp/.orchestrate/{task-slug}/execution/_devils-advocate.md

    ### Return Summary
    ```
    ## Agent Summary
    Type: devil-advocate
    Status: SUCCESS

    ## Output
    Risk level: LOW | MEDIUM | HIGH | CRITICAL
    Critical concerns: {count}
    Major concerns: {count}

    ## Key Risks
    - {risk 1}
    - {risk 2}

    ## Verdict
    APPROVE_WITH_NOTES | RECOMMEND_CHANGES | BLOCK
    ```
  description: "Devil's advocate final review"
```

### Step F5: Present Final Review to User

```
═══════════════════════════════════════════════════════════════
                    FINAL REVIEW COMPLETE
═══════════════════════════════════════════════════════════════

Task: {task-slug}
Total time: {X} minutes

### Implementation Summary
- Tasks completed: {N}/{N}
- Files changed: {X}
- Lines: +{added} -{removed}

### Verification
| Check | Status |
|-------|--------|
| Tests | ✅ {X} passed |
| Types | ✅ No errors |
| Lint | ✅ Clean |
| Build | ✅ Success |

### Holistic Review: {APPROVED/NEEDS_CHANGES}
{summary from reviewer}

### Devil's Advocate: Risk Level {LOW/MEDIUM/HIGH}
{key concerns if any}

### Requirements Coverage
{X}/{Y} requirements implemented

═══════════════════════════════════════════════════════════════

Review the changes:
  git diff HEAD~{N}..HEAD

Full reports:
  execution/_final-summary.md
  execution/_final-review.md
  execution/_devils-advocate.md

═══════════════════════════════════════════════════════════════

**Approve and complete?**

- [Complete] ✅ Approve implementation and mark complete
- [Fix] 🔧 Address concerns first
- [Revert] ⏪ Undo all changes
```

**WAIT FOR USER APPROVAL before marking complete.**

### Step F6: On User Approval

Only after user explicitly chooses [Complete]:

1. Update `task.md`:
   ```
   Status: complete
   Last-updated: {YYYY-MM-DD HH:MM:SS}
   ```
   Mark `[x] Execute` in phases.

2. Show completion message:
   ```
   ═══════════════════════════════════════════════════════════════
                       TASK COMPLETED
   ═══════════════════════════════════════════════════════════════

   Task '{task-slug}' completed successfully!

   All phases done:
   [x] Research
   [x] Plan
   [x] Execute

   Working directory: tmp/.orchestrate/{task-slug}/

   Next: git commit or /commit
   ═══════════════════════════════════════════════════════════════
   ```

---

## Why Final Review is Mandatory

Per-task reviews catch issues within a task.
Batch reviews catch issues within a batch.
**Final Review catches:**
- Issues BETWEEN tasks that individual reviews miss
- Requirements that fell through the cracks
- Holistic problems only visible when viewing ALL changes
- Security/performance concerns across the full implementation

**DO NOT SKIP THIS PHASE.**

## Session Resume

If disconnected during execution, use **file existence** to determine state (task IDs don't persist between sessions):

```
Resume Algorithm:
1. List execution/task-*-*.md files
2. For each file, VALIDATE content (not just existence):
   - Contains "## Agent Summary" header
   - Contains "Status:" line with valid value
   - Contains "## For Dependents" section
   - File size > 100 bytes (not truncated)
3. For each task in tasks.md:
   - If task-{XX}-{name}.md VALID → implementer done
   - If task-{XX}-test.md VALID → tester done
   - If task-{XX}-review.md VALID → review done
   - If file EXISTS but INVALID → re-run that step
4. Find first task without all valid files
5. Resume from that task's next step
```

**Validation Function (pseudo):**
```
def is_valid_report(file_path):
    content = read(file_path)
    if len(content) < 100:
        return False  # Truncated
    if "## Agent Summary" not in content:
        return False
    if not re.search(r"Status:\s*(SUCCESS|FAILED|PARTIAL|BLOCKED)", content):
        return False
    if "## For Dependents" not in content:
        return False
    return True
```

**Example:**
```
execution/
  task-01-setup.md      ✓ valid (has all sections)
  task-01-test.md       ✓ valid
  task-02-auth.md       ✗ INVALID (missing Status) → Re-run implementer
```

**DO NOT rely on `_tasks.json` task IDs** — they don't persist.
`_tasks.json` is only for same-session status checks.

Running `/orchestrate-execute {task-slug}` will detect existing execution and offer to resume.

---

Begin by validating the task and checking plan approval.
