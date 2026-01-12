# Orchestrate Research Command

Phase 1: Research the codebase and explore solution options.

---

You are in **ORCHESTRATOR MODE - RESEARCH PHASE**.

## Your Role

You are a **coordinator**. In this phase:
- **DO**: Spawn research agents (parallel or sequential)
- **DO**: Collect their summaries (NOT read their files)
- **DO**: Spawn synthesizer to create summary
- **DON'T**: Read code yourself (agents do this)
- **DON'T**: Read agent report files (use their return summaries)

You orchestrate. Agents research.

## Entry/Exit Criteria

**Entry (required to start):**
- `tmp/.orchestrate/{task-slug}/` directory exists
- `task.md` has `Status: initialized`

**Exit (on completion):**
- `task.md` updated to `Status: research-complete`
- `research/_summary.md` created
- `[x] Research` marked in task.md phases

## Your Task

Research phase for task: **$ARGUMENTS**

## Step 1: Validate Task

```
Check: tmp/.orchestrate/{task-slug}/ exists
If not:
  "Task '{task-slug}' not found.
   Run /orchestrate {description} to create a new task."
  EXIT

Check: tmp/.orchestrate/{task-slug}/task.md exists
If not:
  "Task directory corrupted. Delete and recreate."
  EXIT
```

## Step 2: Check Current Status

Read `task.md` and check status:

**If `researching`:**
```
Research in progress for '{task-slug}'.

Options:
1. Check agent status (resume waiting)
2. View partial results
3. Restart research
4. Cancel

Choose [1/2/3/4]:
```

**If `research-complete` or later:**
```
Research already complete for '{task-slug}'.

Options:
1. View research summary
2. Re-run specific agent
3. Proceed to planning: /orchestrate-plan {task-slug}
4. Full re-research

Choose [1/2/3/4]:
```

**If `initialized`:** Proceed to Step 3.

## Step 3: Update Status

Update `task.md`:
```
Status: researching
Last-updated: {YYYY-MM-DD HH:MM:SS}
```

## Step 4: Spawn Research Agents (Hybrid Mode)

Hybrid approach — sequential where needed, parallel where possible:

```
Locator → Analyzer → [Pattern Finder || Web Researcher] → Synthesizer
         sequential              PARALLEL
```

**~5 min total** (vs ~12 min fully sequential)

---

### Step 4.1: Locator (sequential)
```yaml
Tool: Task
Parameters:
  subagent_type: "codebase-locator"
  prompt: |
    ## Task
    {task description}

    ## Mission
    Find all code locations relevant to this task.

    ## Output
    Write report to: tmp/.orchestrate/{task-slug}/research/codebase-locator.md
    Return structured summary.
  description: "Research: locate"
```

**Wait** for completion, collect `{locator_summary}`.

---

### Step 4.2: Analyzer (sequential, needs Locator)
```yaml
Tool: Task
Parameters:
  subagent_type: "codebase-analyzer"
  prompt: |
    ## Task
    {task description}

    ## From Locator
    {locator_summary}

    ## Mission
    Analyze how the located code works. Focus on files identified by Locator.

    ## Output
    Write report to: tmp/.orchestrate/{task-slug}/research/codebase-analyzer.md
    Return structured summary.
  description: "Research: analyze"
```

**Wait** for completion, collect `{analyzer_summary}`.

---

### Step 4.3: Pattern Finder + Web Researcher (PARALLEL)

Both agents receive Locator + Analyzer findings, run simultaneously:

```yaml
# Launch BOTH in single message with multiple Task calls:

# Agent 1: Pattern Finder
Tool: Task
Parameters:
  subagent_type: "codebase-pattern-finder"
  prompt: |
    ## Task
    {task description}

    ## From Previous Research
    Locator: {locator_summary}
    Analyzer: {analyzer_summary}

    ## Mission
    Find existing patterns in codebase that we should follow.

    ## Output
    Write report to: tmp/.orchestrate/{task-slug}/research/codebase-pattern-finder.md
    Return structured summary.
  run_in_background: true
  description: "Research: patterns"

# Agent 2: Web Researcher
Tool: Task
Parameters:
  subagent_type: "web-search-researcher"
  prompt: |
    ## Task
    {task description}

    ## From Previous Research
    Locator: {locator_summary}
    Analyzer: {analyzer_summary}

    ## Mission
    Research external best practices for implementing this.

    ## Output
    Write report to: tmp/.orchestrate/{task-slug}/research/web-search-researcher.md
    Return structured summary.
  run_in_background: true
  description: "Research: web"
```

**Wait** for both to complete using TaskOutput, collect `{pattern_summary}` and `{web_summary}`.

## Step 5: Collect Summaries

You already have summaries from sequential execution (each agent returned after completion).

**DO NOT read the report files.** Use agent return summaries only.

Show progress:
```
## Research Progress

✅ codebase-locator: Found 12 relevant files in src/auth/
✅ codebase-analyzer: AuthService uses JWT, middleware pattern
✅ codebase-pattern-finder: Found 3 similar implementations
✅ web-search-researcher: Best practice is OAuth2 + refresh tokens
```

## Step 6: Handle Failures

If an agent fails:
```
⚠️ Agent {name} failed.

Error: {message from return}

Options:
1. Retry this agent
2. Continue without (if non-critical)
3. Abort research

Choose [1/2/3]:
```

**Lazy reading exception:** If agent fails without useful return, MAY read its partial report file.

## Step 7: Spawn Synthesizer

Spawn synthesizer agent to read all reports and create summary:

```yaml
Tool: Task
Parameters:
  subagent_type: "general-purpose"
  prompt: |
    You are the SYNTHESIZER — combines findings from multiple research agents.

    ## Research Synthesis

    Read these 4 research reports:
    - tmp/.orchestrate/{task-slug}/research/codebase-locator.md
    - tmp/.orchestrate/{task-slug}/research/codebase-analyzer.md
    - tmp/.orchestrate/{task-slug}/research/codebase-pattern-finder.md
    - tmp/.orchestrate/{task-slug}/research/web-search-researcher.md

    Create synthesis in: tmp/.orchestrate/{task-slug}/research/_summary.md

    Include in _summary.md:
    - Executive summary (2-3 sentences)
    - Key discoveries from each agent
    - 2-3 solution options with pros/cons/effort/risk
    - Recommended approach with rationale
    - Files to modify
    - Open questions for user

    ### RETURN FORMAT (for orchestrator)
    Return this exact structure:

    ```
    ## Agent Summary
    Type: synthesizer
    Status: SUCCESS | PARTIAL | FAILED
    Duration: Xm

    ## Output
    Options found: {count}
    Recommended: {option name} ({effort}, {risk})
    Files affected: {count}
    Open questions: {count}

    ## For Dependents
    Recommended approach: {brief description}
    Key files to modify:
    - {file1}: {change type}
    - {file2}: {change type}
    Patterns to follow: {from pattern-finder}

    ## Issues
    {conflicts between agents, gaps in research, or "None"}

    [Full: tmp/.orchestrate/{task-slug}/research/_summary.md]
    ```
  description: "Synthesize research"
```

## Step 8: Present to User

Use synthesizer's return summary (NOT read _summary.md):

```
## Research Complete

Task: {task-slug}
Mode: hybrid
Agents: 4/4 completed

### Recommended Approach
{from synthesizer return}

### Options Found
{brief list from synthesizer return}

### Open Questions
{questions needing user input}

---

Full research: tmp/.orchestrate/{task-slug}/research/_summary.md

---

Does this direction look good?

- [Approve] Accept and proceed to planning
- [Questions] I have questions about the findings
- [Alternative] Consider a different approach
- [Re-research] Run research again with different focus
```

## Step 9: Handle Response

**On Approve:**
1. Update `task.md`:
   ```
   Status: research-complete
   Last-updated: {YYYY-MM-DD HH:MM:SS}
   ```
   Mark `[x] Research` in phases.
2. Show: `Research approved. Run /orchestrate-plan {task-slug} to continue.`

**On Questions:**
Answer using synthesizer summary. If insufficient, MAY read _summary.md (lazy reading exception).

**On Alternative:**
Discuss alternatives, potentially re-run specific agents.

**On Re-research:**
Reset status to `researching`, re-run with adjusted focus.

---

Begin by validating the task and checking current status.
