# Orchestrate Research Command

Phase 1: Research the codebase and explore solution options.

---

You are in **ORCHESTRATOR MODE - RESEARCH PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Spawn research agents, collect summaries, spawn synthesizer
- **DON'T**: Read code yourself, read agent report files (use return summaries)

## Entry/Exit Criteria

**Entry:** `task.md` has `Status: initialized`
**Exit:** `task.md` updated to `Status: research-complete`, `research/_summary.md` created

## Your Task

Research phase for task: **$ARGUMENTS**

## Step 1: Validate Task

```
Check: tmp/.orchestrate/{task-slug}/ exists
Check: tmp/.orchestrate/{task-slug}/task.md exists
```

## Step 2: Check Current Status

**If `researching`:** Offer check agents/view partial/restart/cancel
**If `research-complete` or later:** Offer view summary/re-run agent/proceed to plan/full re-research
**If `initialized`:** Proceed to Step 3
**Otherwise:** Error, suggest appropriate phase

## Step 3: Update Status

Update `task.md` to `Status: researching`

## Step 4: Assess Complexity

```
Simple (1-2 files): Standard research (4 agents)
Medium (3-10 files): Standard + domain agent
Complex (10+ files, architectural): Extended (6-8 agents, gaps check)
```

**Complex indicators:** multiple modules, security/auth/payments, DB schema changes, API changes, "refactor"/"migrate"/"redesign"

Show assessment:
```
## Complexity Assessment
Task: {slug}
Indicators: [x] Multiple modules, [x] API changes, [ ] DB migration
Complexity: {SIMPLE|MEDIUM|COMPLEX}
Research plan: {agents to spawn}

Proceed? [Yes/Modify/Simple]
```

## Step 5: Spawn Research Agents

### Standard Mode (Simple/Medium)
```
Locator → Analyzer → [Pattern Finder || Web Researcher] → Synthesizer
         sequential              PARALLEL
```

### Extended Mode (Complex)
```
Phase A: Locator → Architecture Overview
Phase B: [Analyzer || Pattern Finder || Web Researcher || Domain Specialist] PARALLEL
Phase C: Gaps Analyzer → Additional research if needed
Phase D: Synthesizer
```

### 5.1: Locator (sequential)

```yaml
Tool: Task
Parameters:
  subagent_type: "codebase-locator"
  prompt: |
    Task: {description}
    Find all code locations relevant to this task.
    Write to: tmp/.orchestrate/{task-slug}/research/codebase-locator.md
    Return structured summary.
  description: "Research: locate"
```

Wait, collect `{locator_summary}`.

### 5.2: Analyzer (sequential, needs Locator)

```yaml
Tool: Task
Parameters:
  subagent_type: "codebase-analyzer"
  prompt: |
    Task: {description}
    From Locator: {locator_summary}
    Analyze how located code works.
    Write to: tmp/.orchestrate/{task-slug}/research/codebase-analyzer.md
    Return structured summary.
  description: "Research: analyze"
```

Wait, collect `{analyzer_summary}`.

### 5.3: Pattern Finder + Web Researcher (PARALLEL)

```yaml
# Launch BOTH in single message:

Tool: Task
Parameters:
  subagent_type: "codebase-pattern-finder"
  prompt: |
    Task: {description}
    From: Locator: {locator_summary}, Analyzer: {analyzer_summary}
    Find existing patterns to follow.
    Write to: tmp/.orchestrate/{task-slug}/research/codebase-pattern-finder.md
    Return structured summary.
  run_in_background: true
  description: "Research: patterns"

Tool: Task
Parameters:
  subagent_type: "web-search-researcher"
  prompt: |
    Task: {description}
    From: Locator: {locator_summary}, Analyzer: {analyzer_summary}
    Research external best practices.
    Write to: tmp/.orchestrate/{task-slug}/research/web-search-researcher.md
    Return structured summary.
  run_in_background: true
  description: "Research: web"
```

Wait for both via TaskOutput, collect `{pattern_summary}` and `{web_summary}`.

### Session Resume Tracking

After spawning background agents, save to `research/_agents.json`:
```json
{"pattern_finder": {"task_id": "xxx", "status": "running"}, "web_researcher": {"task_id": "yyy", "status": "running"}}
```

On resume: check `_agents.json`, use TaskOutput to get results of completed agents.

## Step 6: Show Progress

```
## Research Progress
✅ codebase-locator: {summary}
✅ codebase-analyzer: {summary}
✅ codebase-pattern-finder: {summary}
✅ web-search-researcher: {summary}
```

## Step 7: Handle Failures

```
⚠️ Agent {name} failed.
Error: {message}
Options: 1. Retry | 2. Continue without | 3. Abort
```

## Step 8: Gaps Check (Complex tasks only)

```yaml
Tool: Task
Parameters:
  subagent_type: "general-purpose"
  prompt: |
    GAPS ANALYZER - identify what research missed.
    Reports: {summaries of all agents}
    Task: {description}

    Identify:
    1. Missing areas (modules, DB, config, tests not covered)
    2. Unanswered questions
    3. Risk areas

    Output:
    - Critical gaps (MUST research before planning)
    - Recommended additional agents
    - Acceptable gaps (low risk)
    - Verdict: PROCEED | NEED_MORE_RESEARCH
  description: "Check research gaps"
```

**If NEED_MORE_RESEARCH:** Show gaps, offer additional agents, re-run gaps check.

## Step 9: Spawn Synthesizer

```yaml
Tool: Task
Parameters:
  subagent_type: "general-purpose"
  prompt: |
    SYNTHESIZER - combine findings from research agents.

    Read these reports:
    - tmp/.orchestrate/{task-slug}/research/codebase-locator.md
    - tmp/.orchestrate/{task-slug}/research/codebase-analyzer.md
    - tmp/.orchestrate/{task-slug}/research/codebase-pattern-finder.md
    - tmp/.orchestrate/{task-slug}/research/web-search-researcher.md

    Create: tmp/.orchestrate/{task-slug}/research/_summary.md

    Include:
    - Executive summary (2-3 sentences)
    - Key discoveries from each agent
    - 2-3 solution options with pros/cons/effort/risk
    - Recommended approach with rationale
    - Files to modify
    - Open questions for user

    Return:
    ## Agent Summary
    Type: synthesizer
    Status: SUCCESS | PARTIAL | FAILED

    ## Output
    Options found: {count}
    Recommended: {option} ({effort}, {risk})
    Files affected: {count}
    Open questions: {count}

    ## For Dependents
    Recommended approach: {brief}
    Key files: [{file: change}]
    Patterns: {from pattern-finder}
  description: "Synthesize research"
```

## Step 10: Present to User

```
## Research Complete

Task: {slug}
Agents: 4/4 completed

### Recommended Approach
{from synthesizer}

### Options Found
{list}

### Open Questions
{questions}

Full research: research/_summary.md

[Approve] Proceed to planning | [Questions] Need clarification | [Alternative] Different approach | [Re-research] Run again
```

## Step 11: Handle Response

**On Approve:**
1. Update `task.md` to `Status: research-complete`, mark `[x] Research`
2. Show: `Research approved. Run /orchestrate-plan {task-slug}`

**On Questions:** Answer from synthesizer summary. If insufficient, read _summary.md (fallback)
**On Alternative:** Discuss, potentially re-run specific agents
**On Re-research:** Reset to `researching`, re-run

---

Begin by validating the task and checking current status.
