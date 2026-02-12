# Claude Code Workflow

A comprehensive orchestration system for Claude Code that turns complex software engineering tasks into structured, multi-phase workflows with specialized AI agents, quality gates, and automated verification.

## What's Inside

```
.claude/
├── orchestrator-rules.md              # Shared rules for all orchestrate commands
│
├── commands/                          # Slash commands (8)
│   ├── orchestrate.md                 # /orchestrate - entry point, task initialization
│   ├── orchestrate-research.md        # /orchestrate-research - research phase
│   ├── orchestrate-architecture.md    # /orchestrate-architecture - architecture phase
│   ├── orchestrate-plan.md            # /orchestrate-plan - planning with multi-plan support
│   ├── orchestrate-execute.md         # /orchestrate-execute - execution with test gates
│   ├── orchestrate-auto.md            # /orchestrate-auto - fully automatic mode
│   ├── verify.md                      # /verify - comprehensive quality checks
│   └── build-fix.md                   # /build-fix - auto-fix build errors
│
├── agents/                            # Specialized agents (16 custom + 10 core)
│   │
│   │  # Codebase analysis (with LEANN semantic search)
│   ├── codebase-locator.md            # Find files by description
│   ├── codebase-analyzer.md           # Analyze implementation details
│   ├── codebase-pattern-finder.md     # Find patterns and examples
│   │
│   │  # Web research (5 specialized)
│   ├── web-search-researcher.md       # General web research
│   ├── web-official-docs.md           # Official documentation
│   ├── web-community.md              # Stack Overflow, blogs, gotchas
│   ├── web-issues.md                  # GitHub issues, bugs, deprecations
│   ├── web-academic.md                # Papers, benchmarks, research
│   ├── web-similar-systems.md         # "How we built X", architecture posts
│   │
│   │  # Planning critics (4 — used in multi-plan mode)
│   ├── strategy-generator.md          # Generate 2-3 orthogonal strategies
│   ├── plan-simulator.md              # Simulate plan execution, find gaps
│   ├── performance-critic.md          # Review performance implications
│   ├── security-critic.md             # Review security implications
│   │
│   │  # Review & validation
│   ├── devil-advocate.md              # Critical review, find weaknesses
│   ├── second-opinion.md              # Independent validation via web research
│   ├── security-reviewer.md           # OWASP Top 10 security audit
│   │
│   └── core/                          # Core execution agents (10)
│       ├── implementer.md             # Write code (with mandatory self-test)
│       ├── reviewer.md                # Code review
│       ├── tester.md                  # Testing (structured reports)
│       ├── debugger.md                # Debugging (auto-debug pipeline)
│       ├── architect.md               # Architecture design
│       ├── documenter.md              # Documentation
│       ├── research.md                # Research
│       ├── research-prompt.md         # Prompts for external LLMs
│       ├── stuck.md                   # Escalation on problems
│       └── teacher.md                 # Teaching and explanations
│
├── rules/                             # Auto-loaded rules (always active)
│   ├── security.md                    # Secrets, injection, XSS, CSRF, auth, path traversal
│   ├── coding-style.md               # Immutability, size limits, naming, DRY, SRP
│   └── performance.md                # Model selection, caching, queries, lazy loading
│
├── docs/
│   └── orchestrate-file-formats.md    # File format reference for validator
│
├── validators/
│   └── validate-orchestrate-files.py  # Structure validation + secrets detection
│
└── hooks/
    ├── session-start.py               # Restore previous session context
    └── session-end.py                 # Persist active task state
```

## Installation

```bash
git clone https://github.com/liker0704/claude-code-workflow.git
cd claude-code-workflow
./install.sh
```

The installer:
- Copies only missing files (doesn't overwrite your existing config)
- Configures 3 hooks in `settings.json` (PreToolUse validator, SessionStart, SessionEnd)
- Uses atomic writes with backup for `settings.json` safety
- Installs [LEANN](https://github.com/lemontheme/leann) semantic search MCP server via `uv`
- Registers LEANN MCP with `claude mcp add` and verifies binary is on PATH

### Options

```bash
./install.sh --upgrade    # Force update all files (creates backups)
./install.sh --no-leann   # Skip LEANN MCP installation
```

### Uninstall

```bash
./uninstall.sh
```

Cleanly removes everything: 8 commands, 16 agents, 3 rules, docs, validators, hooks, all entries from `settings.json`, and LEANN MCP registration. Does not touch files it didn't install (your custom agents, other hooks, etc).

---

## Quick Start

```bash
# Full workflow
/orchestrate "Add user authentication with JWT"

# Or run phases manually
/orchestrate-research my-task-slug
/orchestrate-plan my-task-slug
/orchestrate-execute my-task-slug

# Utility commands
/verify                  # Run all quality checks (build, types, lint, tests, secrets)
/build-fix               # Auto-fix build errors in a loop (max 5 attempts)
```

---

## Workflow Phases

### Phase 1: Research (`/orchestrate-research`)

Systematic codebase and web research with specialized agents.

```
Scout (quick recon) → Research Plan → User Approval → Parallel Agents → Coverage Check → Summary
```

**What's new:**
- **LEANN semantic search** — if installed, builds a project index and uses AI-powered code search alongside keyword grep. Agents find code by concept ("authentication logic") even when exact keywords don't match.
- **EnsureIndex step** — checks for existing LEANN index, offers to build one if missing, sets `SEARCH_MODE=hybrid` or `SEARCH_MODE=keyword`
- **Hybrid retrieval** — agents use a 3-tier search priority:
  1. `leann_search` (semantic, concept-based)
  2. Serena MCP tools (structural, symbol-based)
  3. Grep/Glob (keyword, always available)
- **Graceful degradation** — if LEANN or Serena unavailable, agents silently fall back to keyword search
- **Output file enforcement** — every research agent receives explicit `output_file` path in its prompt
- **Coverage tracking** — summary includes `Search-mode`, `Semantic-hits`, `Keyword-hits` metrics

**Agents used:** scout, codebase-locator, codebase-analyzer, codebase-pattern-finder, web-search-researcher, web-official-docs, web-community, web-issues, web-academic, web-similar-systems

**Output:** `research/_plan.md`, `research/_summary.md`, per-agent reports

### Phase 1.5: Architecture (`/orchestrate-architecture`)

Triggered automatically for complex tasks (complexity >= 5).

- Architect agent creates `architecture.md` in ADR (Architecture Decision Record) format
- User reviews and approves architecture before planning begins

### Phase 2: Plan (`/orchestrate-plan`)

Two planning modes based on task complexity:

#### Single-Plan Mode (complexity < 4)
```
Architect → Plan + Tasks → Devil's Advocate → Second Opinion → User Approval
```

#### Multi-Plan Mode (complexity >= 4)

```
Strategy Generator (2-3 strategies)
    ↓
Plan Simulator (per strategy — simulate execution, find gaps)
    ↓
4-Critic Panel (per strategy):
  ├── performance-critic — latency, memory, scalability analysis
  ├── security-critic — threat modeling, attack surface review
  ├── devil-advocate — structural weaknesses, hidden assumptions
  └── second-opinion — independent web-verified validation
    ↓
Confidence Scoring:
  score = 0.35×coverage + 0.25×simulation + 0.20×risk + 0.10×complexity + 0.10×clarity
    ↓
Best strategy selected → Full plan generated → User Approval
```

**New agents:**
- **strategy-generator** — generates 2-3 *orthogonal* strategies (not variations of the same idea). Analyzes decision axes (storage, architecture, patterns) and combines them into fundamentally different approaches
- **plan-simulator** — stress-tests each plan against 3-5 scenarios (happy path, edge cases, failures, scale, legacy integration). Outputs gap analysis and risk scores
- **performance-critic** — reviews computational complexity, memory usage, I/O patterns, caching strategy, concurrency approach
- **security-critic** — threat modeling with STRIDE, attack surface analysis, data flow trust boundaries, authentication/authorization review

**Output:** `plan/plan.md`, `plan/tasks.md`, `plan/risks.md`, `plan/acceptance.md`

### Phase 3: Execute (`/orchestrate-execute`)

Batched execution with multi-layer quality gates.

#### Execution Pipeline (per task)

```
Implementer (write code + mandatory self-test)
    ↓
TEST GATE (/verify — build, types, lint, tests, secrets, debug statements)
    ↓ FAIL?
AUTO-DEBUG CYCLE (max 3 iterations):
    debugger (analyze failures) → implementer (FIX MODE) → retest
    ↓ still FAIL after 3?
    BLOCKED → escalate to human
    ↓ PASS
Tester (structured test report)
    ↓
Next task in batch
```

#### Batch Pipeline

```
Batch N (max 3 parallel tasks)
    ↓
BATCH GATE (reviewer validates all tasks in batch)
    ↓ APPROVED?
Batch N+1
    ↓ ... all batches done ...
FINAL GATE (check acceptance.md Definition of Done)
    ↓
4-REVIEWER FINAL REVIEW (parallel):
  ├── Code Quality reviewer
  ├── Security reviewer (OWASP patterns)
  ├── Requirements reviewer (task-by-task verification)
  └── Devil's Advocate (find what everyone missed)
    ↓
COMPLETE or FIX → iterate
```

**What's new:**
- **Implementer self-test** — before reporting success, implementer runs syntax check, import check, and existing tests. Self-fix up to 2 attempts
- **Test gate** — `/verify` runs 6 automated checks: build, type checking, linting, tests, secrets scanning, debug statement detection
- **Auto-debug cycle** — on test failure, debugger analyzes root cause, provides structured fix instructions, implementer applies fixes, retests. Max 3 cycles before escalating to human
- **Debugger pipeline integration** — debugger outputs structured report with per-failure root cause, fix instructions, file locations, confidence level, and escalation recommendations
- **Tester structured reports** — consistent pass/fail format with test counts for machine parsing
- **_issues.md tracking** — all gate failures, debug cycles, and blocked tasks logged for transparency
- **Batch gate** — reviewer checks cross-task consistency before proceeding to next batch
- **Final gate** — validates `acceptance.md` Definition of Done checklist before triggering final review

**Output:** `execution/_progress.md`, `execution/_issues.md`, per-task reports, batch reviews, 4 final review reports

---

## New Commands

### `/verify` — Comprehensive Quality Checks

Auto-detects project type (Node.js, Python, Go, Rust, Java) and runs up to 6 checks:

| Check | What it does |
|-------|-------------|
| Build | Compile/transpile the project |
| Types | Type checking (tsc, mypy, go vet) |
| Lint | Linting (ESLint, ruff, golangci-lint) |
| Tests | Run test suite |
| Secrets | Scan for hardcoded API keys, passwords, private keys |
| Debug | Find leftover console.log, debugger, print() statements |

Output: unified PASS/FAIL report with per-check results table.

### `/build-fix` — Auto-Fix Build Errors

Incremental build error fixing loop:
1. Run build command (auto-detected)
2. Parse FIRST error only
3. Fix it with Read/Edit
4. Re-run build
5. Repeat until clean or max 5 attempts

---

## Auto-Loaded Rules

Three rule files in `.claude/rules/` are automatically loaded into every Claude Code session:

### `security.md`
Covers: secrets management, injection prevention, XSS, CSRF, authentication, authorization, path traversal, input validation, error handling, dependency security, data protection.

### `coding-style.md`
Covers: immutability preference, file size limits (500 lines), function size limits (50 lines), error handling, naming conventions, DRY principle, single responsibility, comments philosophy, code organization, dependency management.

### `performance.md`
Covers: model selection strategy (Haiku/Sonnet/Opus by complexity), caching, query optimization, lazy loading, file I/O, algorithm efficiency, network batching, memory management, concurrency, premature optimization avoidance.

---

## LEANN Semantic Search

[LEANN](https://github.com/lemontheme/leann) provides AI-powered code search via MCP (Model Context Protocol).

**How it works:**
1. `install.sh` installs LEANN via `uv tool install leann-core --with leann --with "astchunk-extended[all]"`
2. Registers `leann_mcp` as a user-scoped MCP server
3. During `/orchestrate-research`, the EnsureIndex step builds a project index: `leann build {name} --use-ast-chunking --docs $(git ls-files)`
4. Agents use `mcp__leann-server__leann_search` as primary search tool alongside grep

**Two MCP tools:**
- `leann_search` — natural language code search ("how does authentication work?")
- `leann_list` — list available indexes

**Agents with LEANN:** codebase-locator, codebase-analyzer (both have `leann_search` in their tools list with graceful degradation if unavailable).

**Skip LEANN:** `./install.sh --no-leann` or agents automatically fall back to keyword-only search.

---

## Validation & Hooks

### PreToolUse Validator (`validate-orchestrate-files.py`)

Runs automatically on every Write to `tmp/.orchestrate/` files. Validates:

| File | Checks |
|------|--------|
| `task.md` | Required headers (Task, Status, Complexity, etc.) |
| `tasks.md` | Task table with ID/Title/Status columns |
| `plan.md` | Sections: Overview, Tasks, Dependencies, Risks |
| `_plan.md` | Research plan: Questions, Scope, Agents |
| `_summary.md` | Summary: Key Findings, Coverage, Gaps |
| `architecture.md` | ADR: Context, Decision, Consequences |
| `risks.md` | Risk table: Risk, Likelihood, Impact, Mitigation |
| `acceptance.md` | Definition of Done with checklist items |

**Secrets detection** — scans ALL orchestrate files for:
- API keys (`sk-...`)
- AWS access keys (`AKIA...`)
- Hardcoded passwords (`password="..."`)
- Private keys (`-----BEGIN...PRIVATE KEY-----`)

Blocks the write and shows actionable error messages with references to `orchestrate-file-formats.md`.

### Session Hooks

- **SessionStart** (`session-start.py`) — loads previous session context, shows active orchestrate tasks
- **SessionEnd** (`session-end.py`) — persists current task state (slug, phase, cwd) to `~/.cache/claude-code/sessions/`
- **CWD resilience** — hooks use a fallback chain: `sys.argv[1]` → `CLAUDE_PROJECT_DIR` env → `PROJECT_DIR` env → `INIT_CWD` env → `os.getcwd()`

### Security Reviewer Agent

Dedicated agent for comprehensive security audits with:
- Full **OWASP Top 10** checklist with grep patterns for each category
- **647 lines** of security rules covering: broken access control, cryptographic failures, injection, insecure design, security misconfiguration, vulnerable components, authentication failures, data integrity, logging failures, SSRF
- Secrets scanning patterns for 10+ key types (OpenAI, AWS, GitHub, Slack, Google, Stripe, database URLs, JWTs)

---

## Task Structure

```
tmp/.orchestrate/{task-slug}/
├── task.md                     # Metadata: status, complexity, description
├── research/
│   ├── _plan.md                # Research plan (questions, scope, agents)
│   ├── _summary.md             # Synthesized findings + coverage metrics
│   ├── _agents.json            # Agent tracking for resume
│   ├── scout.md                # Scout analysis
│   └── {agent-id}.md           # Individual agent reports
├── architecture.md             # Architecture decision record (complexity >= 5)
├── plan/
│   ├── plan.md                 # Implementation plan
│   ├── tasks.md                # Task decomposition table
│   ├── risks.md                # Risk assessment matrix
│   └── acceptance.md           # Definition of Done checklist
└── execution/
    ├── _progress.md            # Execution progress tracker
    ├── _issues.md              # Gate failures, debug cycles, blocked tasks
    ├── batch-N-review.md       # Per-batch review reports
    ├── task-XX-*.md            # Per-task implementation reports
    ├── _final-code-quality.md  # Final review: code quality
    ├── _final-security.md      # Final review: security
    ├── _final-requirements.md  # Final review: requirements coverage
    └── _final-devils-advocate.md # Final review: critical analysis
```

## Status Flow

```
initialized → researching → research-complete → [architecting] → planning → plan-complete → executing → complete
                                 ↓                    ↓                                          ↓
                            (skip if low        arch-review                                  blocked
                             complexity)        arch-iteration
```

---

## Summary of Components

| Category | Count | Details |
|----------|-------|---------|
| Slash commands | 8 | orchestrate (6) + verify + build-fix |
| Custom agents | 16 | 3 codebase + 5 web + 4 critics + 3 review + 1 security |
| Core agents | 10 | implementer, tester, debugger, reviewer, architect, etc. |
| Rules | 3 | security, coding-style, performance (auto-loaded) |
| Validators | 1 | structure validation + secrets detection (8 file types) |
| Hooks | 3 | PreToolUse validator + SessionStart + SessionEnd |
| MCP servers | 1 | LEANN semantic search (2 tools) |
| Python scripts | 4 | validator, session-start, session-end, merge-settings |

## License

MIT
