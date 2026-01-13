# Orchestrate Research Command

Phase 1: Research the codebase and explore solution options.

---

You are in **ORCHESTRATOR MODE - RESEARCH PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Use Scout for scope analysis, create formal research plan, spawn agents per plan
- **DO**: Scale agent count based on task complexity
- **DON'T**: Read code yourself, use agent return summaries
- **DON'T**: Skip user approval of research plan

## Entry/Exit Criteria

**Entry:** `task.md` has `Status: initialized`
**Exit:** `task.md` updated to `Status: research-complete`, `research/_summary.md` created

## Your Task

Research phase for task: **$ARGUMENTS**

## Step 1-3: Validate & Update Status

Check task exists. Handle current status:
- **initialized**: Proceed to Step 4
- **researching**: Check `_agents.json`, resume incomplete agents via TaskOutput
- **research-complete+**: Offer view summary / re-run / proceed to plan

---

## Step 4: Scout Analysis

Spawn scout agent for quick scope reconnaissance.

### Scout Prompt

```yaml
Tool: Task
Parameters:
  subagent_type: "codebase-locator"
  prompt: |
    ## SCOUT MISSION

    Task: {task description}

    Quick reconnaissance to determine research scope.
    Time budget: Fast scan, not deep analysis.

    ### Find:
    1. Codebase structure (monorepo/single, by-layer/by-feature)
    2. Affected areas (directories, file patterns)
    3. Key concerns (security, performance, patterns, etc.)
    4. Research questions to answer before implementation

    ### Output Format

    # Scout Report

    ## Codebase Overview
    | Property | Value |
    |----------|-------|
    | Type | monorepo / single |
    | Organization | layers / features / mixed |

    ### Key Directories
    | Path | Purpose |
    |------|---------|

    ## Affected Areas
    | Area | Files | Priority | Why |
    |------|-------|----------|-----|

    ## Concerns
    | Concern | Priority | Aspects |
    |---------|----------|---------|

    ## Research Questions
    | ID | Question | Priority |
    |----|----------|----------|

    ## Recommended Agents
    ### Agent N: {focus}
    | Property | Value |
    |----------|-------|
    | Type | codebase-analyzer / codebase-locator / web-search-researcher |
    | Scope | {files} |
    | Concerns | {what to analyze} |
    | Answers | Q1, Q2... |

  description: "Scout: analyze scope"
```

### Scout Error Handling

**If scout fails (timeout, empty, error):**
```
Scout returned: {empty | error | timeout}

Options:
1. [Retry] — Run scout again (max 2 retries)
2. [Manual] — Define scope yourself
3. [Abort] — Cancel research
```

**On Manual:**
```
## Manual Scope Definition

1. Affected directories (comma-separated):
   >

2. Key concerns (what to analyze):
   >

3. Main questions (what to answer):
   >

[Submit] | [Abort]
```

**Scout Validation:**
- Has at least 1 affected area? If no → warn user
- Has at least 1 question? If no → warn user
- Agent count 1-10? If >10 → suggest simplification

---

## Step 5: Create Research Plan

Based on scout output, create `research/_plan.md`:

```markdown
# Research Plan: {task-slug}

Created: {timestamp}
Status: draft
Scout-based: yes | manual

---

## 1. Task Context
{Original task description}

---

## 2. Research Questions

| # | Question | Priority | Assigned To | Status |
|---|----------|----------|-------------|--------|
| Q1 | {question} | Critical | {agent-id} | ⏳ |

---

## 3. Codebase Scope

### Areas to Analyze
| Area | Files/Patterns | Priority | Assigned To | Status |
|------|----------------|----------|-------------|--------|

### Out of Scope
| Area | Reason |
|------|--------|

---

## 4. Concerns Matrix

| Concern | {agent-1} | {agent-2} | Status |
|---------|-----------|-----------|--------|
| Security | R | C | ⏳ |
| Performance | C | R | ⏳ |

R=Responsible, C=Consulted. Every concern MUST have at least one R.

---

## 5. Agent Assignments

### {agent-id}: {focus}
- **Scope**: {files}
- **Concerns**: {from matrix where R}
- **Questions**: Q1, Q3
- **Status**: ⏳ Pending

---

## 6. Completion Criteria

- [ ] All questions answered
- [ ] All areas covered
- [ ] All concerns have R with ✅
- [ ] No critical gaps

---

## 7. Gaps Found

**Gap iterations:** 0/3

| Gap | Severity | Resolution | Status |
|-----|----------|------------|--------|

---

## 8. Execution Log
| Time | Event | Details |
|------|-------|---------|
```

---

## Step 6: Present Plan to User

```
## Research Plan

Task: {slug}
Scout: ✅ Complete

### Questions ({N})
| # | Question | Agent |
|---|----------|-------|

### Areas ({N})
| Area | Files | Agent |
|------|-------|-------|

### Concerns Matrix
{matrix}

### Agents ({N} total)
| Agent | Focus | Questions |
|-------|-------|-----------|

---
Full plan: research/_plan.md

[Approve] | [Add Question] | [Add Area] | [Modify] | [Reject]
```

**Handle modifications**, then update _plan.md and re-present if needed.

---

## Step 7: Spawn Research Agents

Update `task.md` to `Status: researching`, `_plan.md` to `Status: executing`.

### Agent Prompt Template

Every agent MUST receive:

```markdown
## You are: {agent-id}
## Focus: {focus}

## YOUR SCOPE

| Category | Items |
|----------|-------|
| Files | {file patterns} |
| Concerns (R) | {concerns where responsible} |
| Questions | {questions to answer} |

### NOT IN SCOPE
- {exclusions with reasons}

## CHAIN-OF-VERIFICATION

For EVERY finding:
1. What file:line proves this?
2. Copy exact code as evidence
3. Rate confidence: High / Medium / Low

## COMPLETENESS CHECKLIST

Before finishing:
[ ] All files in scope visited
[ ] All concerns analyzed
[ ] All questions answered (or "not found in scope")

## OUTPUT FORMAT

# Agent Report: {agent-id}

**Mission**: {focus}
**Status**: COMPLETE | PARTIAL | BLOCKED

---

## Questions Answered

### Q1: {question}
**Status**: ✅ Answered | ❌ Not found | ⚠️ Partial
**Confidence**: High | Medium | Low
**Answer**: {text}

**Evidence**:
| File | Line | Code |
|------|------|------|

---

## Findings

### Finding N: {title}
| Attribute | Value |
|-----------|-------|
| Concern | {concern} |
| Severity | Critical / High / Medium / Low |
| File | {path:line} |
| Confidence | High / Medium / Low |

**Observation**: {what was found}
**Evidence**: {code snippet}
**Recommendation**: {what to do}

---

## Coverage
| File | Lines | Notes |
|------|-------|-------|

## Gaps Identified
- {what was missed, may be in other location}

## Context for Other Agents
- {useful info for dependent agents}
```

### Spawn Parallel

Spawn all agents from _plan.md in parallel with `run_in_background: true`.
Save to `research/_agents.json`:
```json
{"agents": [{"id": "xxx", "agent_id": "analyzer-1", "status": "running"}]}
```

---

## Step 8: Track Progress

As agents complete:

1. Read agent output (Markdown)
2. Update _plan.md:
   - Mark questions ✅ or ❌
   - Update concerns matrix
   - Update agent status
3. Show progress:

```
## Research Progress

Agents: 2/4 complete
Questions: 3/5 answered

| Agent | Status | Questions |
|-------|--------|-----------|
| analyzer-1 | ✅ | Q1 ✅, Q4 ✅ |
| analyzer-2 | 🔄 Running | - |

Recent: analyzer-1 found 3 security issues (2 critical)
```

---

## Step 9: Coverage Verification

Formal check against _plan.md:

### 9.1 Questions Check
All questions have status ✅? If ❌ → add to gaps.

### 9.2 Areas Check
All areas analyzed? Check agent coverage reports.

### 9.3 Concerns Matrix Check
Every concern has at least one R with ✅?

### Present Coverage

```
## Coverage Verification

Questions: 4/5 ✅
Areas: 3/3 ✅
Concerns: 2/3 ⚠️

GAPS:
1. Q5 not answered
2. Error handling not analyzed

[Wait] | [Spawn gap agents] | [Mark out-of-scope] | [Proceed anyway]
```

---

## Step 10: Handle Gaps

### Gap Iteration Tracking

Before spawning gap-filling agents:

1. Read current iteration from `_plan.md` Section 7: `**Gap iterations:** X/3`
2. Check limit:

```
If X >= 3:
  ⚠️ Gap resolution limit reached (3/3)

  Still unresolved: {gaps}

  [Accept gaps] | [Force one more] | [Abort]
```

3. If proceeding: Update `_plan.md` to `**Gap iterations:** X+1/3`

### For each gap:

**Option 1: Spawn gap-filling agent**
```yaml
Tool: Task
Parameters:
  subagent_type: "codebase-analyzer"
  prompt: |
    ## GAP-FILLING MISSION
    Previous research missed: {gap}
    Fill this specific gap.
    [Same output format as Step 7]
  description: "Gap-fill: {gap}"
```
Update _plan.md, return to Step 8.

**Option 2: Mark out-of-scope**
Add to _plan.md Section 3.2 with reason.

**Option 3: Proceed with known gap**
Log in _plan.md Section 7, continue.

---

## Step 11: Synthesize

When coverage complete, create `research/_summary.md`:

```markdown
# Research Summary: {task-slug}

Created: {timestamp}
Agents: {N}
Coverage: {percentage}

## Key Findings

### From {agent-1}
- {finding with evidence reference}

### From {agent-2}
- ...

## Conflicts Resolved
{if agents disagreed}

## Solution Options

### Option A: {name}
- Pros: ...
- Cons: ...
- Risk: Low/Medium/High

### Option B: {name}
- ...

## Recommended Approach
{which option and why}

## Files to Modify
| File | Change Type | Reason |
|------|-------------|--------|

## Open Questions
{anything still unclear}
```

---

## Step 12: Present Results

```
## Research Complete

Task: {slug}
Agents: {N} completed
Coverage: {X}%

### Key Findings
{consolidated}

### Recommended Approach
{from summary}

### Files to Modify
{list}

---
Full summary: research/_summary.md
Full plan: research/_plan.md

[Approve] | [Questions] | [More Research] | [Re-do]
```

**On Approve:** Update `task.md` to `Status: research-complete`, mark `[x] Research`.

---

Begin by validating the task status and proceeding to Scout analysis.
