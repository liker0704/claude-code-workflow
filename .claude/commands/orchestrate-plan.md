# Orchestrate Plan Command

Phase 2: Create detailed implementation plan and decompose into tasks.

**IMPORTANT:** First read `~/.claude/orchestrator-rules.md` for critical orchestration rules.

---

You are in **ORCHESTRATOR MODE - PLANNING PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Read research summary, create plan, decompose into tasks, define dependencies
- **DO**: Wait for ALL agents to complete before reading results
- **DON'T**: Implement anything yourself
- **DON'T**: Read agent output files while agents are running

---

## Entry/Exit Criteria

**Entry:** `task.md` has `Status: research-complete` OR `planning`, `research/_summary.md` exists
**Additional:** If complexity >= 5, `architecture.md` should exist and be approved
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

## Step 2.5: Check Architecture (NEW)

Read `research/_plan.md` Section 8 (Complexity Assessment).

**If complexity score >= 5:**

Check if `architecture.md` exists in task directory:

- **If missing:**
```
⚠️ Architecture required but not found.

Complexity score: {score} (threshold: 5)
This task requires architectural decision.

Options:
1. Run architecture: /orchestrate-architecture {task-slug}
2. Skip architecture (not recommended)
```

- **If exists but task.md shows arch-review or arch-iteration:**
```
⚠️ Architecture pending review.

Run /orchestrate-architecture {task-slug} to continue review.
```

- **If task.md shows arch-escalated:**
```
⚠️ Architecture escalated (max iterations reached).

Run /orchestrate-architecture {task-slug} to resolve:
- Provide manual requirements
- Skip architecture
- Abandon task
```

- **If exists and approved:** Proceed to Step 3.

**If complexity score < 5:**
Proceed to Step 3 (architecture optional).

## Step 3: Check Current Status

**If `planning`:** Offer view draft/continue/restart/cancel
**If `plan-complete` or later:** Offer view plan/view tasks/modify/re-create/proceed to execute
**If `research-complete`:** Proceed to Step 4
**Otherwise:** Error, suggest appropriate phase

## Step 4: Update Status

Update `task.md` to `Status: planning`

## Step 5: Read Research Summary

Read `research/_summary.md` for: recommended approach, files to modify, patterns, open questions

## Step 5.5: Determine Planning Mode

Read `research/_plan.md` Section 8 (Complexity Assessment) to extract complexity score.

```
complexity = {score from Section 8}

IF complexity < 4:
  MODE: SIMPLE
  → Proceed with Step 6 (single-plan flow)

IF complexity >= 4:
  MODE: MULTI-PLAN
  → Proceed with Step 5.6 (multi-plan flow)
  → Steps 6-14 are REPLACED by Steps 5.6-5.12
```

**Present mode decision:**
```
## Planning Mode Selected

Complexity: {score}
Mode: {SIMPLE | MULTI-PLAN}

{SIMPLE}: Creating single plan with standard review
{MULTI-PLAN}: Generating multiple strategies, simulation, and critic panel

[Continue]
```

---

### MULTI-PLAN MODE (complexity >= 4)

The following steps (5.6-5.12) REPLACE Steps 6-14 when in multi-plan mode.

## Step 5.6: Strategy Generation

```yaml
Tool: Task
Parameters:
  subagent_type: "strategy-generator"
  prompt: |
    Research: tmp/.orchestrate/{task-slug}/research/_summary.md
    Architecture: tmp/.orchestrate/{task-slug}/architecture.md (if exists)
    Task: {description from task.md}

    Generate 2-3 fundamentally different implementation strategies.
    Each strategy should represent a distinct architectural approach.
  description: "Generate implementation strategies"
```

Wait for strategy-generator to complete.

**Present strategies:**
```
## Implementation Strategies

### Strategy 1: {name}
{brief overview}
Pros: {key advantages}
Cons: {key disadvantages}
Risk: {low|medium|high}

### Strategy 2: {name}
{brief overview}
Pros: {key advantages}
Cons: {key disadvantages}
Risk: {low|medium|high}

### Strategy 3: {name} (if provided)
{brief overview}
Pros: {key advantages}
Cons: {key disadvantages}
Risk: {low|medium|high}

---
Select 1-2 strategies to develop into full plans:
[1] [2] [3] [1+2] [1+3] [2+3] [All 3]
```

## Step 5.7: Strategy Selection

User selects strategies (1-2 recommended, max 3).

Create strategy tracking:
```
Selected strategies: [{N}, {M}]
Plans to develop: {count}
```

## Step 5.8: Blueprint Planning

For each selected strategy, create full plan and task decomposition:

**For strategy N:**

1. Write `plan/plan-{N}.md` following Step 6 template
2. Decompose into tasks following Steps 8-10
3. Write `plan/tasks-{N}.md`
4. Validate decomposition (Step 8.5)

**Repeat for all selected strategies in parallel if possible.**

Present blueprint completion:
```
## Blueprint Plans Created

Plan 1 (Strategy {N}): plan/plan-1.md + tasks-1.md ({X} tasks)
Plan 2 (Strategy {M}): plan/plan-2.md + tasks-2.md ({Y} tasks)

[Continue to Simulation]
```

## Step 5.9: Plan Simulation

For each plan, spawn plan-simulator agent:

```yaml
Tool: Task
Parameters:
  subagent_type: "plan-simulator"
  prompt: |
    Plan: tmp/.orchestrate/{task-slug}/plan/plan-{N}.md
    Tasks: tmp/.orchestrate/{task-slug}/plan/tasks-{N}.md

    Simulate execution against test scenarios.
    Return: READY | NEEDS_REVISION | NOT_READY with detailed analysis.
  description: "Simulate plan {N} execution"
```

**Run simulations in parallel for all plans.**

Wait for ALL simulators to complete.

**Present simulation results:**
```
## Simulation Results

Plan 1 (Strategy {N}): {READY | NEEDS_REVISION | NOT_READY}
{key findings}

Plan 2 (Strategy {M}): {READY | NEEDS_REVISION | NOT_READY}
{key findings}

---
Plans with READY or NEEDS_REVISION proceed to critics.
Plans with NOT_READY are eliminated.

[Continue to Critics Panel]
```

Filter out NOT_READY plans. If zero plans remain, ABORT and report to user.

## Step 5.10: Critics Panel (4-way Parallel)

For each surviving plan, spawn 4 critics in parallel:

```yaml
# For plan-{N}:

Tool: Task (x4 in parallel)
Parameters:
  - subagent_type: "devil-advocate"
    prompt: |
      Review plan: tmp/.orchestrate/{task-slug}/plan/plan-{N}.md
      And tasks: tmp/.orchestrate/{task-slug}/plan/tasks-{N}.md
      Context: {task description}
      Identify risks, flaws, and overlooked issues.
    description: "Devil's Advocate for plan {N}"

  - subagent_type: "security-critic"
    prompt: |
      Review plan: tmp/.orchestrate/{task-slug}/plan/plan-{N}.md
      Focus: security implications, vulnerabilities, attack vectors.
    description: "Security Critic for plan {N}"

  - subagent_type: "performance-critic"
    prompt: |
      Review plan: tmp/.orchestrate/{task-slug}/plan/plan-{N}.md
      Focus: performance bottlenecks, scalability, resource usage.
    description: "Performance Critic for plan {N}"

  - subagent_type: "second-opinion"
    prompt: |
      Validate plan: tmp/.orchestrate/{task-slug}/plan/plan-{N}.md
      MAY read _summary.md for fact verification.
      Judge technical merit, completeness, and feasibility.
      Return: VALIDATED or CONCERNS with details.
    description: "Second Opinion for plan {N}"
```

**Wait for ALL critics to complete for ALL plans.**

**Present critics summary:**
```
## Critics Panel Results

### Plan 1 (Strategy {N})
- Devil's Advocate: {X concerns} - {critical/moderate/minor}
- Security Critic: {Y issues} - {severity summary}
- Performance Critic: {Z concerns} - {impact summary}
- Second Opinion: {VALIDATED | CONCERNS}

### Plan 2 (Strategy {M})
- Devil's Advocate: {X concerns} - {critical/moderate/minor}
- Security Critic: {Y issues} - {severity summary}
- Performance Critic: {Z concerns} - {impact summary}
- Second Opinion: {VALIDATED | CONCERNS}

[Continue to Scoring]
```

## Step 5.11: Confidence Scoring

Calculate confidence score for each plan using formula:

```
confidence = 0.35*coverage + 0.25*simulation + 0.20*risk + 0.10*complexity + 0.10*clarity
```

**Where:**

- **coverage**: Percentage of plan goals addressed by tasks (from Step 8.5 validation)
  ```
  coverage = (goals_with_tasks / total_goals)
  ```

- **simulation**: Normalized simulation verdict
  ```
  simulation = 1.0 if READY
               0.5 if NEEDS_REVISION
               0.0 if NOT_READY
  ```

- **risk**: Risk score based on critic findings
  ```
  critical_issues = count from all 4 critics
  total_issues = count from all 4 critics
  risk = 1.0 - (critical_issues / max(total_issues, 1))
  ```

- **complexity**: Normalized complexity estimate
  ```
  estimated_complexity = task_count / 10  (capped at 1.0)
  complexity = 1.0 - min(estimated_complexity, 1.0)
  ```

- **clarity**: Average clarity rating from critics (if provided)
  ```
  clarity = average of critic clarity scores, or 0.7 if not provided
  ```

**Present scores:**
```
## Confidence Scores

Plan 1 (Strategy {N}): {0.XX}
  Coverage: {0.XX} ({X}/{Y} goals)
  Simulation: {0.XX} ({verdict})
  Risk: {0.XX} ({critical}/{total} issues)
  Complexity: {0.XX} ({task_count} tasks)
  Clarity: {0.XX}

Plan 2 (Strategy {M}): {0.XX}
  Coverage: {0.XX} ({X}/{Y} goals)
  Simulation: {0.XX} ({verdict})
  Risk: {0.XX} ({critical}/{total} issues)
  Complexity: {0.XX} ({task_count} tasks)
  Clarity: {0.XX}

[Continue to Selection]
```

## Step 5.12: Plan Selection & Finalization

**Present comparison table:**
```
## Plan Comparison & Selection

| Metric | Plan 1 (Strategy {N}) | Plan 2 (Strategy {M}) |
|--------|----------------------|----------------------|
| Confidence | {0.XX} | {0.XX} |
| Coverage | {X}% | {Y}% |
| Simulation | {verdict} | {verdict} |
| Risk Level | {low/med/high} | {low/med/high} |
| Task Count | {N} | {M} |
| Critics Summary | {brief} | {brief} |

Recommendation: Plan {N} (higher confidence score)

---
Select plan to proceed with:
[Plan 1] [Plan 2] [Modify Plan 1] [Modify Plan 2] [Restart]
```

**On plan selection:**

1. **Freeze selected plan:**
   - Copy `plan/plan-{N}.md` → `plan/plan.md`
   - Copy `plan/tasks-{N}.md` → `plan/tasks.md`

2. **Generate risks.md:**
   ```markdown
   # Risks: {task-slug}

   Generated from critics panel analysis.

   ## Critical Issues
   {from devil-advocate, security-critic, performance-critic}

   ## Security Concerns
   {from security-critic}

   ## Performance Concerns
   {from performance-critic}

   ## General Risks
   {from devil-advocate, second-opinion}

   ## Mitigation Strategy
   {how these will be addressed during execution}
   ```

3. **Generate acceptance.md:**
   ```markdown
   # Acceptance Criteria: {task-slug}

   Based on plan goals and Definition of Done.

   ## Functional Requirements
   {from plan.md goals → checkable criteria}

   ## Non-Functional Requirements
   - Performance: {from performance-critic}
   - Security: {from security-critic}

   ## Testing Requirements
   {from plan.md testing strategy}

   ## Review Checklist
   - [ ] All functional requirements met
   - [ ] All security concerns addressed
   - [ ] Performance targets achieved
   - [ ] All tests passing
   - [ ] Documentation complete
   ```

4. **Update plan.md status to `approved`**

5. **Update task.md:**
   - Status: `plan-complete`
   - Mark `[x] Plan`

**Present completion:**
```
## Multi-Plan Mode Complete

Selected: Plan {N} (Strategy {name})
Confidence: {0.XX}

Generated artifacts:
- plan/plan.md (approved)
- plan/tasks.md ({X} tasks)
- plan/risks.md (from critics)
- plan/acceptance.md (DoD criteria)

Alternative plans archived:
- plan/plan-{other}.md (not selected)
- plan/tasks-{other}.md (not selected)

Ready for execution: /orchestrate-execute {task-slug}
```

---

### END OF MULTI-PLAN MODE STEPS

When in MULTI-PLAN mode, Steps 5.6-5.12 REPLACE Steps 6-14.

---

### SIMPLE MODE (complexity < 4)

When in SIMPLE mode, proceed with Steps 6-14 below as normal.

## Step 6: Create Plan Document

Write `plan/plan.md`:

```markdown
# Implementation Plan: {task-slug}

Created: {timestamp}
Status: draft
Based on: research/_summary.md
Architecture: {../architecture.md (approved) | not required | skipped}

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

## Step 8.5: Validate Task Decomposition

Before creating tasks.md, validate decomposition:

### Completeness Check
```
For each goal in plan.md:
  Find tasks that contribute to this goal
  If none found → ERROR: Goal "{goal}" not covered by any task
```

### Dependency Validation
```
Build dependency graph from tasks

Check for cycles:
  If cycle detected → ERROR: Circular dependency: task-02 → task-03 → task-02

Check for orphans:
  If task has no dependents and task != final-review:
    WARNING: Task "{task}" doesn't block anything - is it needed?

Check for missing deps:
  If task depends on non-existent task:
    ERROR: task-03 depends on task-99 which doesn't exist
```

### Parallelization Analysis
```
batches = topological_sort(tasks)
max_parallel = max(len(batch) for batch in batches)
total_batches = len(batches)

Show: "Execution: {total_batches} batches, max {max_parallel} parallel"
```

### Present Validation
```
## Task Decomposition Validation

Goals coverage: ✅ All 3 goals have tasks
Dependencies: ✅ No cycles, no missing
Orphan tasks: ⚠️ task-04 doesn't block anything
Parallelization: 4 batches, max 3 parallel

[Proceed] | [Fix Issues]
```

---

## Step 9: Define Interface Contracts

**CRITICAL: Before tasks.md, define CONTRACTS between tasks.**

```markdown
## Contract: task-01 → task-02

### task-01 PRODUCES:
| Type | Name | Location |
|------|------|----------|
| File | src/models/user.py | created |
| Export | User, UserSchema | from src/models/user |
| Interface | User.to_dict() | `def to_dict(self) -> dict` |

### task-02 EXPECTS:
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
| Type | Name | Details |
|------|------|---------|
| File | src/models/user.py | exports: User, UserSchema |
| Interface | User.to_dict() | `def to_dict(self) -> dict` |

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

**PRODUCES:**
| Type | Name | Details |
|------|------|---------|
| File | {path} | exports: {list} |
| Interface | {name} | `{signature}` |

**EXPECTS:** None (first task)

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

## Step 11: Devil's Advocate (SIMPLE MODE)

**Note:** In multi-plan mode, devil-advocate is part of 4-critic panel (Step 5.10).

```yaml
Tool: Task
Parameters:
  subagent_type: "devil-advocate"
  prompt: |
    Review plan: tmp/.orchestrate/{task-slug}/plan/plan.md
    And tasks: tmp/.orchestrate/{task-slug}/plan/tasks.md
    Context: {task description}
    Identify risks, flaws, and overlooked issues.
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

## Step 12: Second Opinion (SIMPLE MODE)

**Note:** In multi-plan mode, second-opinion is part of 4-critic panel (Step 5.10).

```yaml
Tool: Task
Parameters:
  subagent_type: "second-opinion"
  prompt: |
    Validate plan: tmp/.orchestrate/{task-slug}/plan/plan.md
    MAY read _summary.md for fact verification.
    Judge technical merit, completeness, and feasibility.
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
