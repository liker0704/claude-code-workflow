#!/bin/bash

# Claude Code Workflow Installer
# Smart installation with existing settings merge

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/.backup-$(date +%Y%m%d-%H%M%S)"
UPGRADE_MODE=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --upgrade|-u) UPGRADE_MODE=true ;;
        --help|-h)
            echo "Usage: ./install.sh [--upgrade]"
            echo "  --upgrade, -u  Force update all files (backup existing)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
if [ "$UPGRADE_MODE" = true ]; then
    echo -e "${BLUE}║  Claude Code Workflow Upgrader        ║${NC}"
else
    echo -e "${BLUE}║  Claude Code Workflow Installer       ║${NC}"
fi
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo

# Check ~/.claude
if [ ! -d "$CLAUDE_DIR" ]; then
    echo -e "${YELLOW}~/.claude doesn't exist, creating...${NC}"
    mkdir -p "$CLAUDE_DIR"
fi

# Copy function with existence check
copy_if_not_exists() {
    local src="$1"
    local dst="$2"
    local name=$(basename "$src")

    if [ -e "$dst" ]; then
        echo -e "  ${YELLOW}⊘${NC} $name (already exists, skipped)"
        return 1
    else
        cp "$src" "$dst"
        echo -e "  ${GREEN}✓${NC} $name"
        return 0
    fi
}

# Copy function with backup
copy_with_backup() {
    local src="$1"
    local dst="$2"
    local name=$(basename "$src")

    if [ -e "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$dst" "$BACKUP_DIR/$name"
        cp "$src" "$dst"
        echo -e "  ${YELLOW}↻${NC} $name (backup in .backup-*)"
    else
        cp "$src" "$dst"
        echo -e "  ${GREEN}✓${NC} $name"
    fi
}

# 1. Install orchestrator rules (root level)
echo -e "${BLUE}[1/5] Orchestrator Rules${NC}"
if [ -f "$SCRIPT_DIR/.claude/orchestrator-rules.md" ]; then
    if [ "$UPGRADE_MODE" = true ]; then
        copy_with_backup "$SCRIPT_DIR/.claude/orchestrator-rules.md" "$CLAUDE_DIR/orchestrator-rules.md"
    else
        copy_if_not_exists "$SCRIPT_DIR/.claude/orchestrator-rules.md" "$CLAUDE_DIR/orchestrator-rules.md"
    fi
fi

# 2. Install commands
echo -e "\n${BLUE}[2/5] Commands${NC}"
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "$SCRIPT_DIR/.claude/commands"/*.md; do
    if [ -f "$cmd" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$cmd" "$CLAUDE_DIR/commands/$(basename "$cmd")"
        else
            copy_if_not_exists "$cmd" "$CLAUDE_DIR/commands/$(basename "$cmd")"
        fi
    fi
done

# 3. Install agents
echo -e "\n${BLUE}[3/5] Agents${NC}"
mkdir -p "$CLAUDE_DIR/agents/core"

for agent in "$SCRIPT_DIR/.claude/agents"/*.md; do
    if [ -f "$agent" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
        else
            copy_if_not_exists "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
        fi
    fi
done

for agent in "$SCRIPT_DIR/.claude/agents/core"/*.md; do
    if [ -f "$agent" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$agent" "$CLAUDE_DIR/agents/core/$(basename "$agent")"
        else
            copy_if_not_exists "$agent" "$CLAUDE_DIR/agents/core/$(basename "$agent")"
        fi
    fi
done

# 4. Install validators
echo -e "\n${BLUE}[4/5] Validators${NC}"
mkdir -p "$CLAUDE_DIR/validators"
for val in "$SCRIPT_DIR/.claude/validators"/*.py; do
    [ -f "$val" ] && copy_with_backup "$val" "$CLAUDE_DIR/validators/$(basename "$val")"
done

# 5. Configure hooks in settings.json
echo -e "\n${BLUE}[5/5] Hooks${NC}"

MERGE_RESULT=$(python3 "$SCRIPT_DIR/merge-settings.py" 2>&1)

if [[ "$MERGE_RESULT" == "SKIP:"* ]]; then
    echo -e "  ${YELLOW}⊘${NC} Hook already configured"
elif [[ "$MERGE_RESULT" == "OK:"* ]]; then
    echo -e "  ${GREEN}✓${NC} Hook added to settings.json"
else
    echo -e "  ${RED}✗${NC} Error: $MERGE_RESULT"
fi

# Summary
echo
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation complete!               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo
echo -e "Available commands:"
echo -e "  ${BLUE}/orchestrate${NC} <description>   - start a task"
echo -e "  ${BLUE}/orchestrate-research${NC} <slug> - research phase"
echo -e "  ${BLUE}/orchestrate-plan${NC} <slug>     - planning phase"
echo -e "  ${BLUE}/orchestrate-execute${NC} <slug>  - execution phase"
echo
echo -e "Restart Claude Code to apply changes."

if [ -d "$BACKUP_DIR" ]; then
    echo
    echo -e "${YELLOW}Backups saved in: $BACKUP_DIR${NC}"
fi
