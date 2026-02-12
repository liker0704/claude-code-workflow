# Orchestrate Research Command

Phase 1: Research the codebase and explore solution options.

**IMPORTANT:** First read `~/.claude/orchestrator-rules.md` for critical orchestration rules.

---

You are in **ORCHESTRATOR MODE - RESEARCH PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Use Scout for scope analysis, create formal research plan, spawn agents per plan
- **DO**: Scale agent count based on task complexity
- **DO**: Run codebase analysis FIRST, then web research with context
- **DON'T**: Read code yourself, use agent return summaries
- **DON'T**: Skip user approval of research plan
- **DON'T**: Read agent output files while agents are running

---

## Entry/Exit Criteria

**Entry:** `task.md` has `Status: initialized`
**Exit:** `task.md` updated to `Status: research-complete`, `research/_summary.md` created

## Your Task

Research phase for task: **$ARGUMENTS**

## Step 1-3: Validate & Update Status

Check task exists. Handle current status:
- **initialized**: Proceed to Step 3.5 (EnsureIndex)
- **researching**: Check `_agents.json`, resume incomplete agents via TaskOutput
- **research-complete+**: Offer view summary / re-run / proceed to plan

---

## Step 3.5: EnsureIndex (Semantic Search)

**MANDATORY** — always run this step before scout or any agents.

Check if LEANN semantic search is available and index exists.

### Check Availability
1. Try calling `mcp__leann-server__leann_list` MCP tool
2. If MCP tool not available → set `SEARCH_MODE=keyword`, skip to Step 4
3. If available → check if an index exists for current project

### Build Index (auto, if missing)
If LEANN available but no index for current project — build automatically:

```
Building LEANN index for semantic search...
```

**Step 1**: GPU (default):
```bash
leann build {project-name} --use-ast-chunking --docs $(git ls-files)
```

**Step 2**: If CUDA OOM → retry with anti-fragmentation:
```bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True leann build {project-name} --use-ast-chunking --docs $(git ls-files)
```

**Step 3**: If still fails → CPU fallback:
```bash
CUDA_VISIBLE_DEVICES="" leann build {project-name} --use-ast-chunking --docs $(git ls-files)
```

If all three fail → warn and continue without semantic search:
```
LEANN index build failed, continuing with keyword-only search.
```

### Set Search Mode
- `SEARCH_MODE=hybrid` if LEANN available + index exists → tell user: `Search mode: hybrid (semantic + keyword)`
- `SEARCH_MODE=keyword` if LEANN not available or no index → tell user: `Search mode: keyword-only`

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
    5. Task complexity rating (1-5)

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

    ## Complexity Rating

    | Rating | Description |
    |--------|-------------|
    | 1 | Single file, obvious solution |
    | 2 | Few files, clear approach |
    | 3 | Multiple components, some options |
    | 4 | Cross-cutting, architectural decisions |
    | 5 | Unique system, no clear precedent |

    **This task: {1-5}**
    **Justification:** {why this rating}

    **Web Research Agents** (based on complexity):
    - Complexity 1-2: web-official-docs, web-community
    - Complexity 3: + web-issues
    - Complexity 4-5: + web-academic, web-similar-systems

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

## Step 7: Spawn Research Agents (TWO PHASES)

Update `task.md` to `Status: researching`, `_plan.md` to `Status: executing`.

### Research Flow (CRITICAL)

```
PHASE 1: CODEBASE ANALYSIS
├── Spawn all codebase agents (parallel)
├── Wait for ALL to complete
├── Collect: patterns, concerns, questions for web research
└── Output: Context for targeted web search

PHASE 2: WEB RESEARCH (after codebase complete)
├── Use codebase findings as context
├── Spawn web agents based on complexity rating
│   ├── Complexity 1-2: web-official-docs, web-community
│   ├── Complexity 3: + web-issues
│   └── Complexity 4-5: + web-academic, web-similar-systems
├── Wait for ALL to complete
└── Output: External knowledge with sources
```

**IMPORTANT**: Web research receives context from codebase analysis.
This makes web searches TARGETED instead of generic.

### Agent Prompt Template

Every agent MUST receive:

```markdown
## You are: {agent-id}
## Focus: {focus}

## OUTPUT FILE
Write your full report to: {output_file}
Path format: tmp/.orchestrate/{task-slug}/research/{agent-id}.md

## YOUR SCOPE

| Category | Items |
|----------|-------|
| Files | {file patterns} |
| Concerns (R) | {concerns where responsible} |
| Questions | {questions to answer} |

### NOT IN SCOPE
- {exclusions with reasons}

## OUTPUT ORDER (MANDATORY - Anti-hallucination)

For EVERY finding:
1. **QUOTE**: "Exact text or code from source"
2. **CITE**: file:line OR URL
3. **SUMMARIZE**: Your interpretation

**DO NOT summarize before quoting.**
**No quote/cite = Not a valid finding.**

## CONFIDENCE RATING

Rate each finding:
- **High (80-100%)**: Multiple sources agree, official docs confirm
- **Medium (50-79%)**: Single authoritative source, or minor conflicts
- **Low (<50%)**: Limited sources, or significant uncertainty

Include percentage: "Confidence: High (85%)"

## SEARCH STRATEGY

**mcp__leann-server__leann_search is your PRIMARY search tool.** Start every investigation with semantic search.

1. **mcp__leann-server__leann_search** — START HERE for every search task
   - Use for: initial exploration, finding related code by concept
   - Run 1-3 queries with different phrasings for coverage
   - If unavailable: log "mcp__leann-server__leann_search: unavailable", fall back to step 2
2. **mcp__serena__search_for_pattern** — for precise symbol/pattern queries
3. **Grep/Glob** — for exact keyword matches, literal strings, file patterns

Report which tools were used in your output footer:
```
Search tools: mcp__leann-server__leann_search ✅ | serena ✅ | grep ✅
```

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

## Conflicts Found

If you find contradicting information:

| Topic | Source A | Claim A | Source B | Claim B |
|-------|----------|---------|----------|---------|

**Do NOT resolve conflicts yourself. Report them for orchestrator.**

## New Questions Discovered

| Question | Why Important | Suggested Agent |
|----------|---------------|-----------------|

## Context for Other Agents
- {useful info for dependent agents}
```

### Phase 1: Spawn Codebase Agents

Spawn all codebase agents from _plan.md in parallel with `run_in_background: true`.
Save to `research/_agents.json`:
```json
{"phase": "codebase", "agents": [{"id": "xxx", "type": "codebase-analyzer", "status": "running"}]}
```

**Wait for ALL codebase agents to complete before Phase 2.**

### Phase 2: Spawn Web Research Agents

After codebase phase complete, spawn web agents with context.

**Select agents based on complexity rating from Scout:**

| Complexity | Web Agents |
|------------|------------|
| 1-2 | web-official-docs, web-community |
| 3 | + web-issues |
| 4-5 | + web-academic, web-similar-systems |

**Web Agent Prompt Template:**

```yaml
Tool: Task
Parameters:
  subagent_type: "web-official-docs"  # or web-community, web-issues, etc.
  prompt: |
    ## WEB RESEARCH MISSION

    Task: {task description}

    ## OUTPUT FILE
    Write your full report to: {output_file}
    Path format: tmp/.orchestrate/{task-slug}/research/{agent-id}.md

    ## CONTEXT FROM CODEBASE ANALYSIS

    {Summary of codebase findings:}
    - Current patterns: {from codebase agents}
    - Technologies used: {from codebase agents}
    - Specific questions: {from codebase agents}

    ## YOUR FOCUS

    {agent-specific focus}

    ## OUTPUT ORDER (MANDATORY)

    For EVERY finding:
    1. QUOTE: "Exact text from source"
    2. CITE: URL (required)
    3. SUMMARIZE: Your interpretation

    No URL = Not a valid finding.

    ## CONFIDENCE RATING

    Rate each finding: High (80-100%) | Medium (50-79%) | Low (<50%)

    ## OUTPUT FORMAT

    # Web Research Report: {agent-type}

    **Focus**: {focus}
    **Status**: COMPLETE | PARTIAL

    ## Findings

    ### Finding N: {title}
    **Quote**: "{exact text}"
    **Source**: {URL}
    **Confidence**: {rating}
    **Relevance to codebase**: {how it applies}

    ## Sources
    | URL | Type | Reliability |
    |-----|------|-------------|

    ## Conflicts with Codebase
    | Topic | Codebase says | Web says | Resolution needed |
    |-------|---------------|----------|-------------------|

  description: "Web research: {focus}"
```

Update `_agents.json`:
```json
{"phase": "web", "agents": [...]}
```

---

## Step 7.5: Output Validation

Before proceeding to Track Progress, validate agent outputs.

### For Codebase Agents

```python
def validate_codebase_output(output):
    has_references = "file:" in output or ":line" in output or ".ts:" in output or ".py:" in output
    has_findings = "## Findings" in output or "## Key Findings" in output
    has_status = "COMPLETE" in output or "PARTIAL" in output or "BLOCKED" in output
    return has_references and has_findings and has_status
```

### For Web Agents

```python
def validate_web_output(output):
    has_urls = "http://" in output or "https://" in output
    has_sources = "## Sources" in output or "Source:" in output
    has_confidence = "Confidence:" in output
    return has_urls and has_sources and has_confidence
```

### On Validation Failure

```
⚠️ Agent output validation failed

Agent: {agent-id}
Missing: {what's missing}

Options:
1. [Retry] Run agent again
2. [Accept] Proceed anyway (not recommended)
3. [Manual] Mark as incomplete, continue
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
Search-mode: {hybrid | keyword}
Semantic-hits: {count or N/A}
Keyword-hits: {count}

## Key Findings

### From {agent-1}
- {finding with evidence reference}

### From {agent-2}
- ...

## Cross-Compare: Codebase vs Web Best Practices

| Aspect | Current Code | Web Best Practice | Gap | Priority |
|--------|--------------|-------------------|-----|----------|
| {aspect} | {what code does} | {what web says} | Yes/No/Partial | High/Medium/Low |

### Analysis
- What's already following best practices
- What's outdated or needs improvement
- What conflicts exist between sources

## Conflicts Found

| Topic | Source A | Claim A | Source B | Claim B | Resolution |
|-------|----------|---------|----------|---------|------------|

**Note**: Conflicts are documented, not silently resolved.

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

### Synthesis Checklist

Before finalizing _summary.md, verify:

- [ ] All research questions have answers (or explicit "not found")
- [ ] All codebase agents completed successfully
- [ ] All web agents completed successfully
- [ ] Conflicts between agents identified and documented
- [ ] Sources cited for key claims
- [ ] Confidence rated per section
- [ ] Cross-compare section completed
- [ ] Recommendations consistent with findings

---

## Step 11.5: Complexity Assessment

Calculate complexity score for Architecture Gate.

### Metrics to Collect

From research findings, count:
- **new_modules**: New services, major components, or standalone modules
- **modified_files**: Files that need changes
- **new_dependencies**: External packages/libraries to add
- **cross_cutting**: Does task involve logging, auth, caching, error handling, or multiple layers?

### cross_cutting Criteria

Set `cross_cutting: true` if task involves ANY of:
- Logging / monitoring / observability
- Authentication / authorization
- Caching strategy
- Error handling patterns (global)
- Multiple architectural layers (UI + API + DB together)
- Shared utilities used by 3+ modules

### Complexity Formula

```python
score = (
    new_modules * 3 +        # New module = serious decision
    modified_files * 0.5 +   # Many files != complex
    new_dependencies * 2 +   # External dependency = risk
    (4 if cross_cutting else 0)  # Cross-cutting = architectural
)
threshold = 5
```

### Add to _plan.md Section 8

```markdown
## 8. Complexity Assessment

| Metric | Value | Weight | Contribution |
|--------|-------|--------|--------------|
| New modules | {N} | ×3 | {N*3} |
| Modified files | {N} | ×0.5 | {N*0.5} |
| New dependencies | {N} | ×2 | {N*2} |
| Cross-cutting | {Yes/No} | +4 | {0 or 4} |
| **Total** | | | **{score}** |

Threshold: 5
**Requires architecture:** {Yes if score >= 5, else No}

### Cross-cutting Analysis
{If cross_cutting=true, explain which criteria apply}
```

### Present in Summary

Include in Step 12 presentation:

```
### Complexity Assessment
Score: {score} (threshold: 5)
Architecture phase: {Required / Not required}
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

### Complexity Assessment
Score: {score} (threshold: 5)
Architecture phase: {Required / Not required}

---
Full summary: research/_summary.md
Full plan: research/_plan.md

{If architecture required:}
[Approve] → Architecture Phase | [Questions] | [More Research] | [Re-do]

{If architecture NOT required:}
[Approve] → Plan Phase | [Force Architecture] | [Questions] | [More Research]
```

**On Approve:**
1. Update `task.md` to `Status: research-complete`, mark `[x] Research`
2. If complexity >= threshold: Show `Run /orchestrate-architecture {task-slug}`
3. If complexity < threshold: Show `Run /orchestrate-plan {task-slug}`

---

Begin by validating the task status and proceeding to Scout analysis.
