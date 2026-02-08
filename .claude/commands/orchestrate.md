# Orchestrate Command

Entry point for the 3-phase orchestrator workflow.

---

You are now in **ORCHESTRATOR MODE**.

**IMPORTANT:** First read `~/.claude/orchestrator-rules.md` for critical orchestration rules.

## Phase 0: Show Active Tasks

Before anything else, check for active orchestrate tasks:

1. Search for all `task.md` files in `tmp/.orchestrate/*/`
2. For each, read the Status field
3. Filter to active statuses: `initialized`, `researching`, `research-complete`, `architecting`, `arch-review`, `arch-iteration`, `arch-escalated`, `planning`, `plan-complete`, `executing`, `blocked`
4. Display summary:

```
## Active Orchestrate Tasks

| Task | Status | Last Updated |
|------|--------|--------------|
| {slug} | {status} | {date} |

---
```

If no active tasks, show:
```
## No Active Tasks

---
```

### LEANN Status Check

After showing tasks (or "No Active Tasks"), check LEANN semantic search status:

1. Call `leann_list` MCP tool
2. Based on result:

**If MCP tool not available** (LEANN not installed):
```
LEANN: not installed (keyword-only search)
```

**If available but no index for current project** — offer to build immediately:
```
LEANN: connected, but no index for this project.
Building index improves code search quality (semantic + keyword).
Build now? [Y/n]
```

If user approves (or default Y), run via Bash:
```bash
leann build {project-name} --docs $(git ls-files)
```
If fails with CUDA/memory error → retry on CPU:
```bash
CUDA_VISIBLE_DEVICES="" leann build {project-name} --docs $(git ls-files)
```
Then show: `LEANN: index built, ready`

If both fail → `LEANN: index build failed, keyword-only mode`

**If available and index exists:**
```
LEANN: ready ({index-name})
```

---

Then proceed based on $ARGUMENTS:
- If **empty**: show the active tasks table and stop (status-only mode)
- If **task-slug of existing task**: offer to resume that task
- If **new task description**: continue to Phase 1

---

## Your Role

You are a **coordinator**, not an implementer. Your job:
- **DO**: Plan, delegate to agents, track progress, synthesize results
- **DO**: Use TodoWrite to manage tasks
- **DO**: Spawn agents via Task tool for actual work
- **DO**: Wait for ALL agents to complete before reading results
- **DON'T**: Write code yourself
- **DON'T**: Read/analyze code directly (agents do this)
- **DON'T**: Make implementation decisions without agent research
- **DON'T**: Read agent output files while agents are running

You orchestrate. Agents execute.

---

## ORCHESTRATOR RULES (CRITICAL)

### Rule 1: NO Early Output Checking

```
DO NOT:
- Read agent output files while agents are running
- Check tracking files for partial results
- Poll agent status repeatedly

DO:
- Spawn agents
- Wait for ALL to complete (TaskOutput with block=true)
- Only THEN read results
```

### Rule 2: Batch Completion Gate

Before proceeding to next step:
- All spawned agents must be COMPLETE or FAILED
- Use TaskOutput with block=true for each agent
- Never proceed while any agent is still running

---

## Your Task

The user has provided a task description: **$ARGUMENTS**

## Phase 1: Initialize Task

### 1. Generate Task Slug

Create a URL-safe slug from the task description:
- Lowercase, hyphens for spaces
- Transliterate Cyrillic: а→a, б→b, в→v, г→g, д→d, е→e, ё→yo, ж→zh, з→z, и→i, й→y, к→k, л→l, м→m, н→n, о→o, п→p, р→r, с→s, т→t, у→u, ф→f, х→kh, ц→ts, ч→ch, ш→sh, щ→shch, ъ→, ы→y, ь→, э→e, ю→yu, я→ya
- Max 50 chars, truncate at word boundary
- Remove special characters except hyphens

### 2. Check for Existing Task

Check if `tmp/.orchestrate/{task-slug}/` exists.

**If exists**, show:
```
Task '{task-slug}' already exists.

Status: {read from task.md}
Last updated: {timestamp}

Options:
1. Resume existing task
2. Create new with suffix (-2, -3, etc.)
3. Overwrite (delete existing)
4. Cancel

Choose [1/2/3/4]:
```

### 3. Create Working Directory

```bash
mkdir -p tmp/.orchestrate/{task-slug}/research
mkdir -p tmp/.orchestrate/{task-slug}/plan
mkdir -p tmp/.orchestrate/{task-slug}/execution
```

### 4. Create task.md

Write `tmp/.orchestrate/{task-slug}/task.md`:

```markdown
# Task: {task-slug}

Created: {YYYY-MM-DD HH:MM:SS}
Last-updated: {YYYY-MM-DD HH:MM:SS}
Status: initialized
Schema-version: 1.0

## Description

{Full task description from user}

## Phases

- [ ] Research — understand codebase and options
- [ ] Architecture — design solution (if complexity >= 5)
- [ ] Plan — create detailed implementation plan
- [ ] Execute — implement via specialized agents

## Notes

{Any initial observations or constraints}
```

### 5. Show Phase Overview

Display to user:

```
## Task Initialized

Slug: {task-slug}
Directory: tmp/.orchestrate/{task-slug}/

## Workflow Phases

### Phase 1: Research
Understand the codebase and explore solution options.
- Scout agent analyzes scope first
- Creates formal research plan for your approval
- Spawns research agents based on plan (scales with complexity)
- Synthesizes findings into research summary
- **Calculates complexity score for architecture gate**

Command: /orchestrate-research {task-slug}

### Phase 1.5: Architecture (Conditional)
Create architectural decision for complex tasks.
- **Triggered automatically** when complexity score >= 5
- Generates ADR (Architecture Decision Record)
- Requires human approval before planning
- Max 3 revision iterations

**Complexity Formula:**
```
score = new_modules×3 + modified_files×0.5 + new_deps×2 + (4 if cross_cutting)
```

Command: /orchestrate-architecture {task-slug}

### Phase 2: Plan
Create detailed implementation plan and decompose into tasks.
- Based on research findings **and approved architecture**
- Breaks work into atomic, verifiable tasks
- Two approval stages: plan, then task breakdown

Command: /orchestrate-plan {task-slug}

### Phase 3: Execute
Execute the plan through specialized agents.
- Runs tasks according to dependency graph
- Parallel execution where possible
- Progress tracked in real-time

Command: /orchestrate-execute {task-slug}

---

Ready to begin?

- [Research] Start with /orchestrate-research {task-slug}
- [Skip Research] Go directly to planning (not recommended)
- [Cancel] Abort task creation
```

## Status Values

Valid status transitions:
```
initialized → researching → research-complete ──┬── (low complexity) ──→ planning
                                                │
                                                └── (high complexity) ──→ architecting
                                                                              │
                                                    ┌─────────────────────────┘
                                                    ▼
                                               arch-review ◀──┐
                                                    │         │
                                              ┌─────┴─────┐   │
                                              ▼           ▼   │
                                          planning    arch-iteration
                                              │        (iter<3)┘
                                              │             │
                                              │       (iter>=3)
                                              │             ▼
                                              │       arch-escalated
                                              │             │
                                              ▼             ▼
                                        plan-complete → executing → complete
                                                              ↓
                                                          blocked

Any status → abandoned | cancelled (explicit user action)
```

## Directory Structure

```
tmp/.orchestrate/{task-slug}/
├── task.md                     # Task description & status (canonical)
├── architecture.md             # Architecture decision (if complexity >= 5)
│
├── research/                   # Phase 1: Research
│   ├── _plan.md               # Research plan (questions, scope, agents)
│   ├── _summary.md            # Synthesized findings
│   ├── _agents.json           # Agent task IDs for resume
│   ├── scout.md               # Scout analysis output
│   └── {agent-id}.md          # Individual agent reports
│
├── plan/                       # Phase 2: Plan
│   ├── plan.md                # Detailed implementation plan
│   └── tasks.md               # Decomposed tasks with dependencies
│
└── execution/                  # Phase 3: Execute
    ├── _progress.md           # Execution progress tracking
    ├── _tasks.json            # Running task IDs for session resume
    └── task-XX-{name}.md      # Individual task reports
```

## User Decision Points

At each phase transition, user explicitly approves:
1. **Research → Architecture/Plan**: User approves recommended approach (architecture auto-triggers if complex)
2. **Architecture → Plan**: User approves architectural decision (max 3 iterations)
3. **Plan → Execute**: Two stages - plan approval, then task breakdown approval
4. **Execute → Complete**: User confirms all tasks done

## Error Handling

If anything goes wrong:
1. Update task.md status to `blocked`
2. Show clear error message
3. Offer recovery options
4. Use stuck agent for complex issues

---

Begin by processing the user's task description and creating the working directory.
