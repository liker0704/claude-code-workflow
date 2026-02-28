#!/usr/bin/env bash
# Validates Claude Code Workflow configuration for both Claude Code and OpenCode setups.
# Usage: ./validate-config.sh [--installed] [--fix]
#   --installed  Validate installed config (~/.claude, ~/.config/opencode) instead of repo
#   --fix        Show fix suggestions for each error

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

ERRORS=0
WARNINGS=0
CHECKS=0

INSTALLED=false
SHOW_FIX=false
for arg in "$@"; do
    case "$arg" in
        --installed) INSTALLED=true ;;
        --fix) SHOW_FIX=true ;;
    esac
done

if [ "$INSTALLED" = true ]; then
    CLAUDE_DIR="$HOME/.claude"
    OPENCODE_DIR="$HOME/.config/opencode"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CLAUDE_DIR="$SCRIPT_DIR/.claude"
    OPENCODE_DIR="$SCRIPT_DIR/.opencode"
fi

pass() {
    CHECKS=$((CHECKS + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
    CHECKS=$((CHECKS + 1))
    ERRORS=$((ERRORS + 1))
    echo -e "  ${RED}✗${NC} $1"
    if [ "$SHOW_FIX" = true ] && [ -n "${2:-}" ]; then
        echo -e "    ${BLUE}Fix:${NC} $2"
    fi
}

warn() {
    CHECKS=$((CHECKS + 1))
    WARNINGS=$((WARNINGS + 1))
    echo -e "  ${YELLOW}⚠${NC} $1"
}

section() {
    echo -e "\n${BOLD}$1${NC}"
}

# ─────────────────────────────────────────────────────────────
# CLAUDE CODE VALIDATION
# ─────────────────────────────────────────────────────────────

section "Claude Code Configuration ($CLAUDE_DIR)"

# Check directory exists
if [ ! -d "$CLAUDE_DIR" ]; then
    fail "Directory $CLAUDE_DIR not found" "Run ./install.sh"
    echo -e "\n${RED}Cannot continue Claude Code validation.${NC}"
else

# --- Agents ---
section "  Agents"

CLAUDE_AGENTS_FLAT=("codebase-analyzer" "codebase-locator" "codebase-pattern-finder"
    "devil-advocate" "performance-critic" "plan-simulator" "second-opinion"
    "security-critic" "security-reviewer" "strategy-generator"
    "web-academic" "web-community" "web-issues" "web-official-docs"
    "web-search-researcher" "web-similar-systems")

CLAUDE_AGENTS_CORE=("architect" "debugger" "documenter" "implementer"
    "research" "research-prompt" "reviewer" "stuck" "teacher" "tester")

for agent in "${CLAUDE_AGENTS_FLAT[@]}"; do
    f="$CLAUDE_DIR/agents/${agent}.md"
    if [ -f "$f" ]; then
        pass "$agent"
    else
        fail "$agent missing" "Copy from repo: .claude/agents/${agent}.md"
    fi
done

for agent in "${CLAUDE_AGENTS_CORE[@]}"; do
    f="$CLAUDE_DIR/agents/core/${agent}.md"
    if [ -f "$f" ]; then
        pass "core/$agent"
    else
        fail "core/$agent missing" "Copy from repo: .claude/agents/core/${agent}.md"
    fi
done

# Check frontmatter fields on key agents
section "  Agent Frontmatter"

check_frontmatter() {
    local file="$1" field="$2" label="$3"
    if [ ! -f "$file" ]; then return; fi
    if head -20 "$file" | grep -q "^${field}:"; then
        pass "$label has $field"
    else
        fail "$label missing $field" "Add '$field:' to YAML frontmatter"
    fi
}

check_frontmatter "$CLAUDE_DIR/agents/core/implementer.md" "maxTurns" "implementer"
check_frontmatter "$CLAUDE_DIR/agents/core/implementer.md" "isolation" "implementer"
check_frontmatter "$CLAUDE_DIR/agents/devil-advocate.md" "memory" "devil-advocate"
check_frontmatter "$CLAUDE_DIR/agents/devil-advocate.md" "maxTurns" "devil-advocate"
check_frontmatter "$CLAUDE_DIR/agents/security-reviewer.md" "memory" "security-reviewer"
check_frontmatter "$CLAUDE_DIR/agents/codebase-analyzer.md" "memory" "codebase-analyzer"
check_frontmatter "$CLAUDE_DIR/agents/security-critic.md" "memory" "security-critic"
check_frontmatter "$CLAUDE_DIR/agents/core/tester.md" "maxTurns" "tester"

# --- Commands ---
section "  Commands"

COMMANDS=("orchestrate" "orchestrate-research" "orchestrate-architecture"
    "orchestrate-plan" "orchestrate-execute" "orchestrate-auto"
    "verify" "build-fix" "canary-agent-teams")

for cmd in "${COMMANDS[@]}"; do
    f="$CLAUDE_DIR/commands/${cmd}.md"
    if [ -f "$f" ]; then
        pass "$cmd"
    else
        fail "$cmd missing" "Copy from repo: .claude/commands/${cmd}.md"
    fi
done

# Check key features in commands
section "  Command Features"

check_content() {
    local file="$1" pattern="$2" label="$3"
    if [ ! -f "$file" ]; then
        fail "$label — file missing"
        return
    fi
    if grep -q "$pattern" "$file" 2>/dev/null; then
        pass "$label"
    else
        fail "$label"
    fi
}

check_content "$CLAUDE_DIR/commands/orchestrate-architecture.md" "L2 Discovery" "architecture: L2 Discovery step"
check_content "$CLAUDE_DIR/commands/orchestrate-architecture.md" "## Interfaces" "architecture: Interfaces section"
check_content "$CLAUDE_DIR/commands/orchestrate-architecture.md" "System Diagram" "architecture: System Diagram"
check_content "$CLAUDE_DIR/commands/orchestrate-architecture.md" "previous_block_concerns" "architecture: convergence loop"
check_content "$CLAUDE_DIR/commands/orchestrate-architecture.md" "Step 7.5" "architecture: 4-critic review"

check_content "$CLAUDE_DIR/commands/orchestrate-plan.md" "previous_block_concerns" "plan: convergence loop (no max_iterations)"
check_content "$CLAUDE_DIR/commands/orchestrate-plan.md" "Step 6.5" "plan: clarification check"
check_content "$CLAUDE_DIR/commands/orchestrate-plan.md" "Step 8.7" "plan: TDD mode assignment"
check_content "$CLAUDE_DIR/commands/orchestrate-plan.md" "TDD.*full.*skip" "plan: TDD field in task template"

check_content "$CLAUDE_DIR/commands/orchestrate-execute.md" "TDD-First" "execute: TDD-first step"
check_content "$CLAUDE_DIR/commands/orchestrate-execute.md" "TDD CONTEXT.*STRICT" "execute: TDD STRICT context"
check_content "$CLAUDE_DIR/commands/orchestrate-execute.md" "PURPOSEFUL" "execute: purposeful review questions"
check_content "$CLAUDE_DIR/commands/orchestrate-execute.md" "F6.5" "execute: post-review refactoring"
check_content "$CLAUDE_DIR/commands/orchestrate-execute.md" "tdd.*full" "execute: dual pipeline diagram"

# No max_iterations anywhere
if grep -rq "max_iterations" "$CLAUDE_DIR/commands/orchestrate-"*.md 2>/dev/null; then
    fail "max_iterations still present in orchestrate commands" "Replace with convergence loop"
else
    pass "no max_iterations in orchestrate commands"
fi

# --- Rules ---
section "  Rules"

for rule in security coding-style performance; do
    f="$CLAUDE_DIR/rules/${rule}.md"
    if [ -f "$f" ]; then
        pass "$rule"
    else
        fail "$rule missing" "Copy from repo: .claude/rules/${rule}.md"
    fi
done

# --- Hooks ---
section "  Hooks"

for hook in format-on-write.py guard-config.py; do
    f="$CLAUDE_DIR/hooks/${hook}"
    if [ -f "$f" ]; then
        if [ -x "$f" ] || head -1 "$f" | grep -q "python"; then
            pass "$hook"
        else
            warn "$hook exists but may not be executable"
        fi
    else
        fail "$hook missing" "Copy from repo: .claude/hooks/${hook}"
    fi
done

# --- Docs ---
section "  Docs"

if [ -f "$CLAUDE_DIR/docs/orchestrate-file-formats.md" ]; then
    pass "orchestrate-file-formats.md"
else
    fail "orchestrate-file-formats.md missing"
fi

# --- Validators ---
section "  Validators"

if [ -f "$CLAUDE_DIR/validators/validate-orchestrate-files.py" ]; then
    pass "validate-orchestrate-files.py"
else
    warn "validate-orchestrate-files.py missing (optional)"
fi

# --- Settings hooks ---
section "  Settings Hooks"

if [ -f "$HOME/.claude/settings.json" ]; then
    settings="$HOME/.claude/settings.json"
    for hook_type in PreToolUse PostToolUse SessionStart ConfigChange; do
        if grep -q "$hook_type" "$settings" 2>/dev/null; then
            pass "settings.json has $hook_type hook"
        else
            warn "settings.json missing $hook_type hook (run merge-settings.py)"
        fi
    done
else
    warn "~/.claude/settings.json not found"
fi

# --- .gitignore ---
section "  Git Config"

if [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/.gitignore" ]; then
    gitignore="$(git rev-parse --show-toplevel)/.gitignore"
    for pattern in ".claude/worktrees" ".claude/agent-memory-local"; do
        if grep -q "$pattern" "$gitignore" 2>/dev/null; then
            pass ".gitignore has $pattern"
        else
            warn ".gitignore missing $pattern"
        fi
    done
fi

fi # end claude dir check

# ─────────────────────────────────────────────────────────────
# OPENCODE VALIDATION
# ─────────────────────────────────────────────────────────────

section "OpenCode Configuration ($OPENCODE_DIR)"

if [ ! -d "$OPENCODE_DIR" ]; then
    warn "Directory $OPENCODE_DIR not found (OpenCode not configured)"
else

# --- Agents ---
section "  Agents"

OPENCODE_AGENTS=("architect" "codebase-analyzer" "codebase-locator"
    "codebase-pattern-finder" "debugger" "devil-advocate" "documenter"
    "implementer" "performance-critic" "plan-simulator" "research"
    "research-prompt" "reviewer" "second-opinion" "security-critic"
    "security-reviewer" "strategy-generator" "stuck" "teacher" "tester"
    "web-academic" "web-community" "web-issues" "web-official-docs"
    "web-search-researcher" "web-similar-systems")

for agent in "${OPENCODE_AGENTS[@]}"; do
    f="$OPENCODE_DIR/agents/${agent}.md"
    if [ -f "$f" ]; then
        # Check OpenCode frontmatter
        if head -5 "$f" | grep -q "^description:"; then
            pass "$agent"
        else
            warn "$agent exists but missing frontmatter"
        fi
    else
        fail "$agent missing" "Copy from repo: .opencode/agents/${agent}.md"
    fi
done

# Orchestrators
for orch in orchestrator orchestrator-codex; do
    f="$OPENCODE_DIR/agents/${orch}.md"
    if [ -f "$f" ]; then
        pass "$orch"
    else
        warn "$orch missing (orchestrator agent)"
    fi
done

# --- Commands ---
section "  Commands"

for cmd in "${COMMANDS[@]}"; do
    f="$OPENCODE_DIR/commands/${cmd}.md"
    if [ -f "$f" ]; then
        # Check has OpenCode frontmatter
        if head -3 "$f" | grep -q "^agent:"; then
            pass "$cmd"
        else
            warn "$cmd missing 'agent:' frontmatter"
        fi
    else
        fail "$cmd missing" "Copy from repo: .opencode/commands/${cmd}.md"
    fi
done

# --- Sync check ---
section "  Claude ↔ OpenCode Sync"

for cmd in orchestrate-architecture orchestrate-plan orchestrate-execute; do
    claude_f="$CLAUDE_DIR/commands/${cmd}.md"
    opencode_f="$OPENCODE_DIR/commands/${cmd}.md"
    if [ -f "$claude_f" ] && [ -f "$opencode_f" ]; then
        # Strip frontmatter (first 5 lines) from OpenCode, compare
        claude_content=$(cat "$claude_f")
        opencode_content=$(tail -n +6 "$opencode_f" | sed 's|~/.config/opencode/|~/.claude/|g')
        if [ "$claude_content" = "$opencode_content" ]; then
            pass "$cmd in sync"
        else
            fail "$cmd OUT OF SYNC between Claude and OpenCode" \
                "Re-sync: copy Claude version, add frontmatter, fix paths"
        fi
    else
        warn "$cmd sync check skipped (file missing)"
    fi
done

# --- Rules sync ---
for rule in security coding-style performance; do
    claude_f="$CLAUDE_DIR/rules/${rule}.md"
    opencode_f="$OPENCODE_DIR/rules/${rule}.md"
    if [ -f "$claude_f" ] && [ -f "$opencode_f" ]; then
        if diff -q "$claude_f" "$opencode_f" > /dev/null 2>&1; then
            pass "rules/$rule in sync"
        else
            fail "rules/$rule OUT OF SYNC" "Copy Claude version to OpenCode"
        fi
    fi
done

# --- Plugin ---
section "  Plugin & Config"

if [ -f "$OPENCODE_DIR/plugins/workflow-plugin.ts" ]; then
    pass "workflow-plugin.ts"
else
    warn "workflow-plugin.ts missing"
fi

if [ -f "$OPENCODE_DIR/AGENTS.md" ]; then
    pass "AGENTS.md"
else
    warn "AGENTS.md missing"
fi

if [ -f "$OPENCODE_DIR/orchestrator-rules.md" ]; then
    pass "orchestrator-rules.md"
else
    fail "orchestrator-rules.md missing"
fi

fi # end opencode dir check

# ─────────────────────────────────────────────────────────────
# EXTERNAL TOOLS
# ─────────────────────────────────────────────────────────────

section "External Tools"

for tool in claude git python3; do
    if command -v "$tool" &> /dev/null; then
        pass "$tool available"
    else
        fail "$tool not found"
    fi
done

if command -v opencode &> /dev/null; then
    pass "opencode available"
else
    warn "opencode not installed (OpenCode features unavailable)"
fi

if command -v leann &> /dev/null; then
    pass "leann available"
else
    warn "leann not installed (semantic search unavailable)"
fi

if command -v ruff &> /dev/null; then
    pass "ruff available (Python formatter)"
else
    warn "ruff not installed (format-on-write won't format Python)"
fi

# ─────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────

echo
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Validation Summary${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Checks:   $CHECKS"
echo -e "  ${GREEN}Passed:${NC}   $((CHECKS - ERRORS - WARNINGS))"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "  ${RED}Errors:${NC}   $ERRORS"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "\n  ${GREEN}All checks passed!${NC}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "\n  ${YELLOW}Config valid with warnings.${NC}"
else
    echo -e "\n  ${RED}Config has errors. Run with --fix for suggestions.${NC}"
fi

exit "$ERRORS"
