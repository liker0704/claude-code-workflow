#!/bin/bash

# Claude Code Workflow Uninstaller

set -e

CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
echo -e "${RED}║  Claude Code Workflow Uninstaller     ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
echo

# Confirmation
read -p "Remove all workflow components? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo -e "\n${BLUE}Removing...${NC}\n"

# Commands
COMMANDS=(
    "orchestrate.md"
    "orchestrate-research.md"
    "orchestrate-architecture.md"
    "orchestrate-plan.md"
    "orchestrate-execute.md"
    "orchestrate-auto.md"
)

echo -e "${BLUE}[1/4] Orchestrator Rules${NC}"
if [ -f "$CLAUDE_DIR/orchestrator-rules.md" ]; then
    rm "$CLAUDE_DIR/orchestrator-rules.md"
    echo -e "  ${RED}✗${NC} orchestrator-rules.md"
fi

echo -e "\n${BLUE}[2/4] Commands${NC}"
for cmd in "${COMMANDS[@]}"; do
    if [ -f "$CLAUDE_DIR/commands/$cmd" ]; then
        rm "$CLAUDE_DIR/commands/$cmd"
        echo -e "  ${RED}✗${NC} $cmd"
    fi
done

# Agents (only custom ones, don't touch core/)
AGENTS=(
    "codebase-locator.md"
    "codebase-analyzer.md"
    "codebase-pattern-finder.md"
    "web-search-researcher.md"
    "web-official-docs.md"
    "web-community.md"
    "web-issues.md"
    "web-academic.md"
    "web-similar-systems.md"
    "devil-advocate.md"
    "second-opinion.md"
)

echo -e "\n${BLUE}[3/4] Agents (custom)${NC}"
for agent in "${AGENTS[@]}"; do
    if [ -f "$CLAUDE_DIR/agents/$agent" ]; then
        rm "$CLAUDE_DIR/agents/$agent"
        echo -e "  ${RED}✗${NC} $agent"
    fi
done

# Validators
echo -e "\n${BLUE}[4/4] Validators${NC}"
if [ -f "$CLAUDE_DIR/validators/validate-orchestrate-files.py" ]; then
    rm "$CLAUDE_DIR/validators/validate-orchestrate-files.py"
    echo -e "  ${RED}✗${NC} validate-orchestrate-files.py"
fi

echo
echo -e "${YELLOW}Note:${NC}"
echo -e "  - Agents in core/ were not removed (may be used by others)"
echo -e "  - Hook in settings.json must be removed manually"
echo -e "  - Restart Claude Code"
echo
echo -e "${GREEN}Uninstall complete.${NC}"
