# Orchestrate Architecture Command

Phase 1.5: Create architectural decision for complex tasks.

**IMPORTANT:** First read `.claude/orchestrator-rules.md` for critical orchestration rules.

---

You are in **ORCHESTRATOR MODE - ARCHITECTURE PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Delegate architecture creation to architect agent
- **DO**: Iterate based on feedback (max 3 iterations)
- **DO**: Wait for architect agent to complete before reading results
- **DON'T**: Generate architecture yourself (delegate to architect agent)
- **DON'T**: Skip human approval
- **DON'T**: Proceed to Plan without approved architecture
- **DON'T**: Read agent output files while agents are running

---

## Entry/Exit Criteria

**Entry:** `task.md` has `Status: research-complete`, complexity score >= threshold
**Exit:** `task.md` updated to `Status: planning`, `architecture.md` approved

## When This Phase Runs

This phase is **conditional** based on complexity score from Research Phase.

**Complexity Gate Formula:**
```python
score = (
    new_modules * 3 +        # New module = serious decision
    modified_files * 0.5 +   # Many files != complex
    new_dependencies * 2 +   # External dependency = risk
    (4 if cross_cutting else 0)  # Cross-cutting = architectural
)
threshold = 5
```

**cross_cutting = true** if task involves:
- Logging / monitoring / observability
- Authentication / authorization
- Caching strategy
- Error handling patterns (global)
- Multiple architectural layers (UI + API + DB)
- Shared utilities used by 3+ modules

## Your Task

Architecture phase for task: **$ARGUMENTS**

## Step 1: Validate Entry

```
Check: tmp/.orchestrate/{task-slug}/task.md exists
Check: Status is research-complete OR architecting OR arch-review OR arch-iteration
Check: research/_plan.md contains Complexity Assessment
```

## Step 2: Check Complexity Gate

Read `research/_plan.md` Section 8 (Complexity Assessment):

**If score < threshold:**
```
Complexity score: {score} (threshold: {threshold})
Architecture phase not required.

[Skip] Proceed to Plan | [Force] Run architecture anyway
```

**If score >= threshold:**
Proceed to Step 3.

## Step 3: Check Current Status

**If `research-complete`:** Proceed to Step 4 (first generation)
**If `architecting`:** Check for partial, resume or restart
**If `arch-review`:** Show architecture for review
**If `arch-iteration`:** Generate revised architecture with feedback
**If `arch-escalated`:** Show escalation options

## Step 4: Update Status

Update `task.md`:
```yaml
Status: architecting

architecture:
  iterations: 0
  max_iterations: 3
```

## Step 5: Spawn Architect Agent

**DO NOT generate architecture yourself. Delegate to architect agent.**

```yaml
Tool: Task
Parameters:
  subagent_type: "architect"
  prompt: |
    ## ARCHITECTURE TASK

    Task: {task description}
    Task slug: {task-slug}

    ## CONTEXT FROM RESEARCH

    {Content of research/_summary.md}

    Key findings:
    - {finding 1}
    - {finding 2}

    Recommended approach from research: {approach}

    ## YOUR MISSION

    Create architecture decision document for this task.

    Output file: tmp/.orchestrate/{task-slug}/architecture.md

    ## REQUIREMENTS

    1. Quote research findings when making decisions:
       "Research found: '{exact quote}' (source: research/_summary.md)"

    2. Consider at least 2 alternatives before deciding

    3. Rate confidence for each decision:
       - High: Multiple research sources agree
       - Medium: Single source or some uncertainty
       - Low: Limited research, needs validation

    ## OUTPUT FORMAT

    Write to: tmp/.orchestrate/{task-slug}/architecture.md

    ```markdown
    # Architecture: {task name}

    Task: {task-slug}
    Date: {YYYY-MM-DD}

    ---

    ## Context

    {2-3 sentences from research findings: what we're doing and why}

    **Research basis:** "{quote from research}" (source: research/_summary.md)

    ## Alternatives Considered

    1. **[Alternative A]** — rejected: {reason in 1 sentence}
    2. **[Alternative B]** — rejected: {reason in 1 sentence}

    ## Decision

    **Approach:** {Chosen approach in 1-2 sentences}

    **Rationale:** {Why this approach, 2-3 sentences}
    **Confidence:** {High/Medium/Low} — {why}

    **Trade-offs:**
    - (+) {Benefit 1}
    - (+) {Benefit 2}
    - (-) {Drawback / accepted limitation}

    ## Components

    | Action | File | Purpose |
    |--------|------|---------|
    | CREATE | `src/path/to/new.ts` | {What it does} |
    | MODIFY | `src/path/to/existing.ts` | {What changes} |

    ## Data Flow

    ```
    {Input} → {Component A} → {Component B} → {Output}
    ```

    ---

    *Requires human review before proceeding to Plan Phase.*
    ```

    ## VALIDATION (before finishing)

    - [ ] Context explains problem clearly
    - [ ] Research findings are quoted, not paraphrased
    - [ ] At least 2 alternatives considered
    - [ ] Decision has clear rationale with confidence
    - [ ] Components table lists all files
    - [ ] Data flow shows architecture

  description: "Architect: design for {task-slug}"
```

### Wait for Architect Agent

```
TaskOutput(architect-task-id, block=true) → wait until complete
```

### Validate Architecture Output

After architect agent completes:

1. Read `architecture.md`
2. Validate required sections exist:
   - `## Context` (non-empty, has research quote)
   - `## Alternatives Considered` (at least 1)
   - `## Decision` (has Approach, Rationale, Confidence)
   - `## Components` (has at least 1 row)
   - `## Data Flow` (non-empty)

3. If validation fails:
```
⚠️ Architecture validation failed

Missing: {what's missing}

Options:
1. [Retry] Ask architect to fix
2. [Manual] Edit architecture.md manually
3. [Skip] Proceed without full architecture
```

## Step 6: Present for Review

Update `task.md` Status to `arch-review`.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Architecture Review Required
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task: {task-slug}
Iteration: {N}/3

Summary:
  Approach: {approach from Decision section}
  New files: {count CREATE}
  Modified files: {count MODIFY}
  Trade-off: {main trade-off}

Alternatives rejected:
  - {Alternative A}: {reason}
  - {Alternative B}: {reason}

Full document: tmp/.orchestrate/{task-slug}/architecture.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[a] Approve - continue to Plan Phase
[r] Reject  - provide feedback for revision
[v] View    - show full architecture.md
[s] Skip    - proceed without architecture (warning)

Choice:
```

## Step 7: Handle User Decision

### On Approve [a]

1. Update `task.md` Status to `planning`
2. Mark architecture phase complete
3. Show: `Architecture approved. Run /orchestrate-plan {task-slug}`

### On Reject [r]

1. Prompt for feedback:
```
Provide feedback for revision:
>
```

2. Check iteration count:
   - If iterations < 3: Update to `arch-iteration`, save feedback, go to Step 8
   - If iterations >= 3: Go to Step 9 (Escalation)

3. Update `task.md`:
```yaml
architecture:
  iterations: {N+1}
  max_iterations: 3
  last_feedback: "{user feedback}"
  history:
    - iteration: {N}
      action: rejected
      reason: "{feedback}"
      timestamp: "{ISO timestamp}"
```

### On View [v]

Show full content of `architecture.md`, then return to review prompt.

### On Skip [s]

```
⚠️ Warning: Proceeding without architecture review.

This may lead to:
- Design issues discovered late
- Rework during implementation
- Inconsistent component design

Are you sure? [y/n]
```

If confirmed:
1. Update `task.md` Status to `planning`
2. Add note: `architecture: skipped`
3. Show: `Architecture skipped. Run /orchestrate-plan {task-slug}`

## Step 8: Revise Architecture

Read previous feedback from `task.md` architecture.last_feedback.

Regenerate `architecture.md` addressing the feedback specifically.

Show what changed:
```
## Architecture Revised (Iteration {N}/3)

Changes made:
- {Change 1 addressing feedback}
- {Change 2}

Previous feedback: "{feedback}"
```

Return to Step 6 (present for review).

## Step 9: Escalation

When iterations >= 3:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Architecture Escalation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task: {task-slug}
Status: Maximum iterations (3) reached

Rejection history:
  1. "{feedback 1}"
  2. "{feedback 2}"
  3. "{feedback 3}"

The AI cannot satisfy requirements within iteration limit.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[m] Manual   - provide detailed requirements for new attempt
[s] Skip     - proceed without architecture (at your risk)
[x] Abandon  - cancel this task

Choice:
```

### On Manual [m]

1. Prompt for detailed requirements
2. Reset iterations to 0
3. Update `task.md` Status to `architecting`
4. Go to Step 5 with manual input

### On Skip [s]

Same as Step 7 Skip.

### On Abandon [x]

1. Update `task.md` Status to `cancelled`
2. Show: `Task cancelled.`

## Error Handling

| Situation | Action |
|-----------|--------|
| Research summary missing | Error: Run /orchestrate-research first |
| Complexity assessment missing | Warn, assume score >= threshold |
| Generation fails | Retry once, then escalate |
| Invalid architecture.md | Show validation errors, regenerate |

## Validation

Architecture.md must have:
- `## Context` section (non-empty)
- `## Alternatives Considered` with at least 1 alternative
- `## Decision` with Approach and Rationale
- `## Components` table with at least 1 row
- `## Data Flow` section

---

Begin by validating the task and checking complexity gate.
