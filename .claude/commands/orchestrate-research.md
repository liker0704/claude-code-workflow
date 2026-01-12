# Orchestrate Research Command

Phase 1: Research the codebase and explore solution options.

---

You are in **ORCHESTRATOR MODE - RESEARCH PHASE**.

## Your Role

You are a **coordinator**:
- **DO**: Spawn research agents, collect summaries, spawn synthesizer
- **DO**: Scale agent count based on task scope (more coverage = better results)
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

## Step 4: Analyze Scope & Plan Research

**CRITICAL: Determine HOW MANY agents of each type to spawn.**

### 4.1: Analyze Task Scope

Evaluate the task and codebase to determine:

```
SCOPE FACTORS:
- Directories involved: How many top-level dirs affected? (src/, tests/, config/, etc.)
- Modules/features: How many distinct features touched?
- Change types: API? Security? Database? UI? Config?
- Keywords: "refactor", "migrate", "redesign" = broad scope
- Codebase size: Small (<50 files), Medium (50-500), Large (500+)
```

### 4.2: Calculate Agent Instances

**For each agent type, decide instance count:**

| Agent Type | Minimum | Scale Up When | Max |
|------------|---------|---------------|-----|
| codebase-locator | 1 | +1 per 3 major directories | 4 |
| codebase-analyzer | 1 | +1 per distinct concern (arch, data, API, security) | 4 |
| codebase-pattern-finder | 1 | +1 if multiple feature areas | 3 |
| web-search-researcher | 1 | +1 per distinct research topic (practices, security, performance) | 3 |

**Example scaling:**

```
Task: "Refactor authentication to use OAuth2"

Scope analysis:
- Directories: src/auth/, src/api/, src/middleware/, tests/auth/, config/
- Concerns: Security, API contracts, Data flow, Error handling
- Keywords: "refactor" → broad
- Topics: OAuth2 best practices, Security considerations, Migration patterns

Agent plan:
- Locators: 2 (src/* focus, tests+config focus)
- Analyzers: 3 (security focus, API focus, data flow focus)
- Pattern Finders: 2 (auth patterns, API patterns)
- Web Researchers: 3 (OAuth2 best practices, security concerns, migration guides)

Total: 10 agents (vs standard 4)
```

### 4.3: Define Focus Areas

**For each agent instance, define specific focus:**

```yaml
Locator instances:
  - focus: "src/auth/, src/middleware/, src/security/"
    output: "research/locator-auth.md"
  - focus: "src/api/, src/services/, src/handlers/"
    output: "research/locator-api.md"
  - focus: "tests/, config/, migrations/"
    output: "research/locator-infra.md"

Analyzer instances:
  - focus: "Security: authentication flow, token handling, permissions"
    output: "research/analyzer-security.md"
  - focus: "Architecture: module structure, dependencies, interfaces"
    output: "research/analyzer-arch.md"
  - focus: "Data flow: how data moves through auth system"
    output: "research/analyzer-data.md"

Pattern Finder instances:
  - focus: "Existing auth patterns in codebase"
    output: "research/patterns-auth.md"
  - focus: "API endpoint patterns, middleware patterns"
    output: "research/patterns-api.md"

Web Researcher instances:
  - focus: "OAuth2 implementation best practices 2024"
    output: "research/web-oauth2.md"
  - focus: "OAuth2 security vulnerabilities and mitigations"
    output: "research/web-security.md"
  - focus: "Migration from session-based to OAuth2"
    output: "research/web-migration.md"
```

### 4.4: Present Research Plan

```
## Research Plan

Task: {slug}
Scope: {NARROW | MODERATE | BROAD | EXTENSIVE}

### Agents to Spawn

| Type | Count | Focus Areas |
|------|-------|-------------|
| codebase-locator | 2 | auth+middleware, api+services |
| codebase-analyzer | 3 | security, architecture, data flow |
| codebase-pattern-finder | 2 | auth patterns, API patterns |
| web-search-researcher | 3 | best practices, security, migration |

**Total: 10 agents** (estimated tokens: ~50k)

---

[Proceed] Start research | [Scale Down] Use fewer agents | [Scale Up] Add more coverage | [Custom] Modify plan
```

## Step 5: Spawn Research Agents (Adaptive)

### 5.1: Spawn All Locators (PARALLEL)

Launch ALL locator instances simultaneously:

```yaml
# Launch all in single message with run_in_background: true

Tool: Task
Parameters:
  subagent_type: "codebase-locator"
  prompt: |
    Task: {description}
    YOUR FOCUS: {focus area 1}
    Find all code locations in your focus area relevant to this task.
    Write to: tmp/.orchestrate/{task-slug}/research/locator-{focus-name}.md
    Return structured summary.
  run_in_background: true
  description: "Locate: {focus-name}"

Tool: Task
Parameters:
  subagent_type: "codebase-locator"
  prompt: |
    Task: {description}
    YOUR FOCUS: {focus area 2}
    ...
  run_in_background: true
  description: "Locate: {focus-name}"

# Continue for all locator instances...
```

Wait for ALL locators via TaskOutput, collect summaries, merge into `{combined_locator_summary}`.

### 5.2: Spawn All Analyzers (PARALLEL)

Launch ALL analyzer instances with combined locator results:

```yaml
Tool: Task
Parameters:
  subagent_type: "codebase-analyzer"
  prompt: |
    Task: {description}
    YOUR FOCUS: {analyzer focus - e.g., "Security analysis"}

    Located files (from all locators):
    {combined_locator_summary}

    Analyze the located code from YOUR FOCUS perspective.
    Write to: tmp/.orchestrate/{task-slug}/research/analyzer-{focus-name}.md
    Return structured summary.
  run_in_background: true
  description: "Analyze: {focus-name}"

# Continue for all analyzer instances...
```

Wait for ALL analyzers, collect summaries, merge into `{combined_analyzer_summary}`.

### 5.3: Spawn Pattern Finders + Web Researchers (ALL PARALLEL)

Launch ALL remaining agents simultaneously:

```yaml
# Pattern Finders
Tool: Task
Parameters:
  subagent_type: "codebase-pattern-finder"
  prompt: |
    Task: {description}
    YOUR FOCUS: {pattern focus}
    Context: {combined_locator_summary}, {combined_analyzer_summary}
    Find patterns related to your focus area.
    Write to: tmp/.orchestrate/{task-slug}/research/patterns-{focus-name}.md
    Return structured summary.
  run_in_background: true
  description: "Patterns: {focus-name}"

# Web Researchers
Tool: Task
Parameters:
  subagent_type: "web-search-researcher"
  prompt: |
    Task: {description}
    YOUR FOCUS: {research topic}
    Context: {combined_locator_summary}, {combined_analyzer_summary}
    Research external information about your topic.
    Write to: tmp/.orchestrate/{task-slug}/research/web-{topic-name}.md
    Return structured summary.
  run_in_background: true
  description: "Web: {topic-name}"

# Continue for all instances...
```

Wait for ALL, collect summaries.

### Session Resume Tracking

After spawning agents, save to `research/_agents.json`:
```json
{
  "locators": [{"id": "xxx", "focus": "auth", "status": "running"}],
  "analyzers": [{"id": "yyy", "focus": "security", "status": "running"}],
  "patterns": [...],
  "web": [...]
}
```

On resume: check `_agents.json`, use TaskOutput to get results of completed agents.

## Step 6: Show Progress

```
## Research Progress

### Locators (2/2)
✅ locator-auth: Found 23 files in src/auth/, src/middleware/
✅ locator-api: Found 15 files in src/api/, src/services/

### Analyzers (3/3)
✅ analyzer-security: JWT validation, permission checks, token storage
✅ analyzer-arch: Service layer pattern, middleware chain
✅ analyzer-data: Request → middleware → handler → response flow

### Pattern Finders (2/2)
✅ patterns-auth: Found decorator-based auth, middleware pattern
✅ patterns-api: REST conventions, error response format

### Web Researchers (3/3)
✅ web-oauth2: Authorization Code flow recommended
✅ web-security: Token rotation, PKCE required
✅ web-migration: Gradual migration strategy found

Total: 10/10 agents completed
```

## Step 7: Handle Failures

```
⚠️ Agent {name} ({focus}) failed.
Error: {message}
Options: 1. Retry | 2. Continue without | 3. Spawn replacement with different focus | 4. Abort
```

## Step 8: Gaps Check

After all agents complete, check for gaps:

```yaml
Tool: Task
Parameters:
  subagent_type: "general-purpose"
  prompt: |
    GAPS ANALYZER - identify what research missed.

    All agent reports: {list all summaries}
    Task: {description}

    Identify:
    1. Areas of codebase not covered by any locator
    2. Concerns not analyzed (security? performance? error handling?)
    3. External topics not researched
    4. Conflicting information between agents

    Output:
    - Critical gaps (MUST research before planning)
    - Recommended additional agent instances with focus
    - Acceptable gaps (low risk)
    - Verdict: PROCEED | NEED_MORE_RESEARCH
  description: "Check research gaps"
```

**If NEED_MORE_RESEARCH:** Spawn additional targeted agents, re-run gaps check.

## Step 9: Spawn Synthesizer

```yaml
Tool: Task
Parameters:
  subagent_type: "general-purpose"
  prompt: |
    SYNTHESIZER - combine findings from ALL research agents.

    Read ALL reports in: tmp/.orchestrate/{task-slug}/research/
    (locator-*.md, analyzer-*.md, patterns-*.md, web-*.md)

    Create: tmp/.orchestrate/{task-slug}/research/_summary.md

    Include:
    - Executive summary (2-3 sentences)
    - Key discoveries by category (location, analysis, patterns, external)
    - Conflicts or contradictions found (and resolution)
    - 2-3 solution options with pros/cons/effort/risk
    - Recommended approach with rationale
    - Files to modify (consolidated from all locators)
    - Open questions for user

    Return:
    ## Agent Summary
    Type: synthesizer
    Status: SUCCESS | PARTIAL | FAILED

    ## Output
    Agents synthesized: {count}
    Options found: {count}
    Recommended: {option} ({effort}, {risk})
    Files affected: {count}
    Open questions: {count}

    ## For Dependents
    Recommended approach: {brief}
    Key files: [{file: change}]
    Patterns: {consolidated from pattern-finders}
  description: "Synthesize research"
```

## Step 10: Present to User

```
## Research Complete

Task: {slug}
Agents: {N}/{N} completed
Coverage: {NARROW | MODERATE | BROAD | EXTENSIVE}

### Summary
{executive summary from synthesizer}

### Key Findings
- **Codebase**: {from locators + analyzers}
- **Patterns**: {from pattern finders}
- **External**: {from web researchers}

### Recommended Approach
{from synthesizer}

### Options Found
{list with pros/cons}

### Open Questions
{questions}

Full research: research/_summary.md
Individual reports: research/*.md

[Approve] Proceed to planning | [Questions] Need clarification | [More Research] Add more agents | [Re-research] Start over
```

## Step 11: Handle Response

**On Approve:**
1. Update `task.md` to `Status: research-complete`, mark `[x] Research`
2. Show: `Research approved. Run /orchestrate-plan {task-slug}`

**On Questions:** Answer from synthesizer summary. If insufficient, read specific report files.
**On More Research:** Spawn additional agents with specified focus, re-run synthesis.
**On Re-research:** Reset to `researching`, re-plan, re-run.

---

Begin by validating the task and checking current status.
