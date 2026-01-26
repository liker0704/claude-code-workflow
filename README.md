# Claude Code Workflow

A complete set of agents, commands, and hooks for multi-phase task orchestration in Claude Code.

## What's Inside

```
.claude/
├── orchestrator-rules.md        # Shared rules for all orchestrate commands
│
├── commands/                    # Slash commands
│   ├── orchestrate.md          # /orchestrate - entry point
│   ├── orchestrate-research.md # /orchestrate-research - research phase
│   ├── orchestrate-architecture.md # /orchestrate-architecture - architecture phase
│   ├── orchestrate-plan.md     # /orchestrate-plan - planning phase
│   ├── orchestrate-execute.md  # /orchestrate-execute - execution phase
│   └── orchestrate-auto.md     # /orchestrate-auto - automatic mode
│
├── agents/                      # Custom agents
│   ├── codebase-locator.md     # Find files by description
│   ├── codebase-analyzer.md    # Analyze implementation
│   ├── codebase-pattern-finder.md # Find patterns and examples
│   ├── web-search-researcher.md   # General web research
│   ├── web-official-docs.md    # Official documentation search
│   ├── web-community.md        # Stack Overflow, blogs, gotchas
│   ├── web-issues.md           # GitHub issues, bugs, deprecations
│   ├── web-academic.md         # Papers, benchmarks, research
│   ├── web-similar-systems.md  # "How we built X", architecture decisions
│   ├── devil-advocate.md       # Critical plan review
│   ├── second-opinion.md       # Independent validation
│   └── core/                   # Core agents
│       ├── implementer.md      # Write code
│       ├── reviewer.md         # Code review
│       ├── tester.md           # Testing
│       ├── architect.md        # Architecture design
│       ├── debugger.md         # Debugging
│       ├── documenter.md       # Documentation
│       ├── research.md         # Research
│       ├── research-prompt.md  # Prompts for external LLMs
│       ├── stuck.md            # Escalation on problems
│       └── teacher.md          # Teaching and explanations
│
├── validators/
│   └── validate-orchestrate-files.py  # Orchestrator file validation
│
└── hooks.json                  # Hooks configuration
```

## Installation

```bash
git clone https://github.com/liker0704/claude-code-workflow.git
cd claude-code-workflow
./install.sh
```

The script:
- Copies only missing files (doesn't overwrite existing ones)
- Creates backups when updating validators
- Configures hooks in settings.json

### Upgrade

```bash
./install.sh --upgrade
```

Forces update of all files (commands, agents, validators) with automatic backup.

### Uninstall

```bash
./uninstall.sh
```

## Usage

### Workflow: Research → Plan → Execute

```bash
# 1. Initialize task
/orchestrate "Add user authentication"

# 2. Research the codebase
/orchestrate-research add-user-auth
# Scout → Research Plan → User Approval → Agents → Synthesis

# 3. Create plan and decompose into tasks
/orchestrate-plan add-user-auth

# 4. Execute the plan via specialized agents
/orchestrate-execute add-user-auth
```

### Status only

```bash
/orchestrate  # Shows active tasks
```

## Phases

### Phase 1: Research
1. **Scout agent** → quick scope reconnaissance + complexity rating (1-5)
2. **Research Plan** (`_plan.md`) → questions, areas, concerns matrix
3. **User approval** → modify plan if needed
4. **Research agents** → codebase-analyzer, codebase-locator, specialized web agents
5. **Coverage verification** → gap detection and resolution
- Output: `research/_plan.md` + `research/_summary.md`

### Phase 1.5: Architecture (conditional)
- Triggered when complexity score >= threshold (5)
- **architect agent** → creates architecture.md (ADR format)
- **User approval** → review and approve architecture
- Output: `architecture.md`

### Phase 2: Plan
- **architect** → designs the solution
- **devil-advocate** → critiques the plan
- **second-opinion** → independent validation
- Output: `plan/plan.md` + `plan/tasks.md`

### Phase 3: Execute
- **implementer** → writes code
- **tester** → creates tests
- **reviewer** → checks quality (always full review)
- **multi-agent final review** → 4 parallel reviewers (code quality, security, requirements, devil's advocate)
- Output: working code

## Task Structure

```
tmp/.orchestrate/{task-slug}/
├── task.md                  # Metadata and status
├── research/
│   ├── _plan.md             # Research plan (questions, scope, agents)
│   ├── _summary.md          # Synthesized findings
│   ├── _agents.json         # Agent tracking for resume
│   ├── scout.md             # Scout analysis output
│   └── {agent-id}.md        # Individual agent reports
├── architecture.md          # Architecture decision (if complexity >= 5)
├── plan/
│   ├── plan.md              # Detailed plan
│   └── tasks.md             # Task decomposition
└── execution/
    ├── _progress.md
    ├── _tasks.json
    ├── _final-review.md
    └── task-XX-*.md
```

## Status Flow

```
initialized → researching → research-complete → [architecting] → planning → plan-complete → executing → complete
                                 ↓                    ↓                                          ↓
                            (skip if low        arch-review                                  blocked
                             complexity)        arch-iteration
```

## Key Features

- **Conditional Architecture Phase**: Complex tasks (score >= 5) get dedicated architecture design with ADR format
- **Specialized Web Agents**: 5 focused agents for different research types (docs, community, issues, academic, similar systems)
- **Multi-Agent Final Review**: 4 parallel reviewers ensure quality before completion
- **Shared Orchestrator Rules**: Common rules in `orchestrator-rules.md` prevent context pollution
- **Smart Installation**: Merges with existing `.claude/` configuration without overwriting
- **Validation Hooks**: Automatic validation of orchestrator files on write

## License

MIT
