# Orchestrate Research Command

Phase 1: Research the codebase and explore solution options.

---

You are in **ORCHESTRATOR MODE - RESEARCH PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Analyze task scope, spawn multiple agents with different focus areas, synthesize
- **DO**: Scale agent count based on task complexity (more angles = better coverage)
- **DON'T**: Read code yourself, use agent return summaries

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

## Step 4: Plan Research Coverage

**Analyze the task and decide how many agents to spawn.**

Think about:
- What areas of code might be affected?
- What different concerns need analysis? (architecture, data, error handling, etc.)
- What external info would help? (best practices, alternatives, pitfalls)

**Scaling principle:**
- Simple task (1-2 files) → 1 agent per type
- Broader task → spawn multiple instances with DIFFERENT FOCUS
- Each instance looks at the task from a different angle

| Agent Type | Purpose | When to spawn multiple |
|------------|---------|----------------------|
| codebase-locator | Find relevant files | Different directories/modules |
| codebase-analyzer | Understand code | Different concerns (arch, data, errors) |
| codebase-pattern-finder | Find patterns | Different aspects of the feature |
| web-search-researcher | External research | Different topics/questions |

**Present plan to user:**
```
## Research Plan

Task: {slug}
Scope: {assessment}

| Agent | Instances | Focus Areas |
|-------|-----------|-------------|
| locator | {N} | {focus 1}, {focus 2}... |
| analyzer | {N} | {focus 1}, {focus 2}... |
| pattern-finder | {N} | {focus 1}, {focus 2}... |
| web-researcher | {N} | {focus 1}, {focus 2}... |

Total: {N} agents

[Proceed] | [Fewer] | [More] | [Custom]
```

## Step 5: Spawn Agents

### 5.1: Locators (PARALLEL)
Spawn all locator instances at once, each with its own focus area.
Wait, merge results into `{combined_locator_summary}`.

### 5.2: Analyzers (PARALLEL)
Spawn all analyzer instances with combined locator results.
Each analyzes from its assigned perspective.
Wait, merge into `{combined_analyzer_summary}`.

### 5.3: Pattern Finders + Web Researchers (PARALLEL)
Spawn all remaining instances at once.
Wait, collect all summaries.

**Session resume:** Save spawned agents to `research/_agents.json`:
```json
{"agents": [{"id": "xxx", "type": "locator", "focus": "...", "status": "running|done"}]}
```
On resume: read file, use TaskOutput for running agents, skip done ones.

## Step 6: Progress & Failures

Show progress as agents complete. On failure: Retry / Continue / Replace / Abort

## Step 7: Gaps Check

Spawn gaps analyzer (general-purpose agent) to find:
- Code areas not covered by any locator
- Concerns not analyzed (security? performance? edge cases?)
- External topics not researched

If critical gaps found → spawn additional targeted agents, re-check.

## Step 8: Synthesize

Synthesizer reads ALL reports, creates `_summary.md` with:
- Key findings from each agent
- Conflicts/contradictions resolved
- Solution options
- Recommended approach
- Files to modify

## Step 9: Present Results

```
## Research Complete

Task: {slug}
Agents: {N} completed
Coverage: {assessment}

### Findings
{consolidated from all agents}

### Recommended Approach
{from synthesizer}

[Approve] | [Questions] | [More Research] | [Re-do]
```

## Step 10: Handle Response

**Approve:** Mark `research-complete`, proceed to plan
**More Research:** Spawn additional agents with specified focus

---

Begin by validating the task and analyzing scope.
