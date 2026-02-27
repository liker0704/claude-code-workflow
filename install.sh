#!/bin/bash

# Claude Code Workflow Installer
# Smart installation with existing settings merge

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/.backup-$(date +%Y%m%d-%H%M%S)"
UPGRADE_MODE=false
SKIP_LEANN=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --upgrade|-u) UPGRADE_MODE=true ;;
        --no-leann) SKIP_LEANN=true ;;
        --help|-h)
            echo "Usage: ./install.sh [--upgrade] [--no-leann]"
            echo "  --upgrade, -u  Force update all files (backup existing)"
            echo "  --no-leann     Skip LEANN semantic search installation"
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
echo -e "${BLUE}[1/8] Orchestrator Rules${NC}"
if [ -f "$SCRIPT_DIR/.claude/orchestrator-rules.md" ]; then
    if [ "$UPGRADE_MODE" = true ]; then
        copy_with_backup "$SCRIPT_DIR/.claude/orchestrator-rules.md" "$CLAUDE_DIR/orchestrator-rules.md"
    else
        copy_if_not_exists "$SCRIPT_DIR/.claude/orchestrator-rules.md" "$CLAUDE_DIR/orchestrator-rules.md" || true
    fi
fi

# 2. Install commands
echo -e "\n${BLUE}[2/8] Commands${NC}"
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "$SCRIPT_DIR/.claude/commands"/*.md; do
    if [ -f "$cmd" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$cmd" "$CLAUDE_DIR/commands/$(basename "$cmd")"
        else
            copy_if_not_exists "$cmd" "$CLAUDE_DIR/commands/$(basename "$cmd")" || true
        fi
    fi
done

# 3. Install agents
echo -e "\n${BLUE}[3/8] Agents${NC}"
mkdir -p "$CLAUDE_DIR/agents/core"

for agent in "$SCRIPT_DIR/.claude/agents"/*.md; do
    if [ -f "$agent" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
        else
            copy_if_not_exists "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")" || true
        fi
    fi
done

for agent in "$SCRIPT_DIR/.claude/agents/core"/*.md; do
    if [ -f "$agent" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$agent" "$CLAUDE_DIR/agents/core/$(basename "$agent")"
        else
            copy_if_not_exists "$agent" "$CLAUDE_DIR/agents/core/$(basename "$agent")" || true
        fi
    fi
done

# 4. Install rules
echo -e "\n${BLUE}[4/8] Rules${NC}"
mkdir -p "$CLAUDE_DIR/rules"
for rule in "$SCRIPT_DIR/.claude/rules"/*.md; do
    if [ -f "$rule" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$rule" "$CLAUDE_DIR/rules/$(basename "$rule")"
        else
            copy_if_not_exists "$rule" "$CLAUDE_DIR/rules/$(basename "$rule")" || true
        fi
    fi
done

# 5. Install docs
echo -e "\n${BLUE}[5/8] Docs${NC}"
mkdir -p "$CLAUDE_DIR/docs"
for doc in "$SCRIPT_DIR/.claude/docs"/*.md; do
    if [ -f "$doc" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$doc" "$CLAUDE_DIR/docs/$(basename "$doc")"
        else
            copy_if_not_exists "$doc" "$CLAUDE_DIR/docs/$(basename "$doc")" || true
        fi
    fi
done

# 6. Install validators
echo -e "\n${BLUE}[6/8] Validators${NC}"
mkdir -p "$CLAUDE_DIR/validators"
for val in "$SCRIPT_DIR/.claude/validators"/*.py; do
    [ -f "$val" ] && copy_with_backup "$val" "$CLAUDE_DIR/validators/$(basename "$val")"
done

# 7. Install hooks
echo -e "\n${BLUE}[7/8] Hooks${NC}"
mkdir -p "$CLAUDE_DIR/hooks"
for hook in "$SCRIPT_DIR/.claude/hooks"/*.py; do
    [ -f "$hook" ] && copy_with_backup "$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")"
done

# Configure hooks in settings.json
MERGE_RESULT=$(python3 "$SCRIPT_DIR/merge-settings.py" 2>&1)

if [[ "$MERGE_RESULT" == "SKIP:"* ]]; then
    echo -e "  ${YELLOW}⊘${NC} Hook already configured"
elif [[ "$MERGE_RESULT" == "OK:"* ]]; then
    echo -e "  ${GREEN}✓${NC} Hook added to settings.json"
else
    echo -e "  ${RED}✗${NC} Error: $MERGE_RESULT"
fi

# 8. LEANN MCP installation
echo -e "\n${BLUE}[8/8] LEANN MCP${NC}"
if [ "$SKIP_LEANN" = true ]; then
    echo -e "  ${YELLOW}⊘${NC} Skipped (--no-leann)"
else
    # Check if already registered
    if claude mcp list 2>/dev/null | grep -q "leann-server"; then
        echo -e "  ${YELLOW}⊘${NC} Already registered"
    else
        # Check if uv is installed
        if ! command -v uv &> /dev/null; then
            echo -e "  ${YELLOW}⚠${NC} uv not found. Install it first: curl -LsSf https://astral.sh/uv/install.sh | sh"
            echo -e "  ${YELLOW}⊘${NC} Skipping LEANN (use --no-leann to suppress this warning)"
        else
            echo -e "  ${BLUE}Installing LEANN...${NC}"
            if uv tool install leann-core --with leann --with "astchunk-extended[all]" --python 3.13 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} LEANN installed"

                # Patch leann CODE_EXTENSIONS for additional AST languages
                ~/.local/share/uv/tools/leann-core/bin/python -c "from astchunk.patch_leann import apply; apply(verbose=False)" 2>/dev/null \
                    && echo -e "  ${GREEN}✓${NC} AST chunking: 15 languages enabled" \
                    || echo -e "  ${YELLOW}⚠${NC} AST chunking patch skipped"

                # Verify binary is callable
                if command -v leann_mcp &> /dev/null; then
                    echo -e "  ${BLUE}Registering MCP server...${NC}"
                    if claude mcp add --scope user leann-server -- leann_mcp 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} LEANN MCP server registered"
                    else
                        echo -e "  ${YELLOW}⚠${NC} Failed to register MCP server (you can do it manually later)"
                    fi
                else
                    echo -e "  ${YELLOW}⚠${NC} leann_mcp not on PATH. Add ~/.local/bin to PATH and re-run install"
                fi
            else
                echo -e "  ${YELLOW}⚠${NC} LEANN installation failed (continuing anyway)"
            fi
        fi
    fi
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

# Post-install validation
if command -v claude &> /dev/null; then
    AGENT_COUNT=$(claude agents 2>/dev/null | grep -c "^\s*-" 2>/dev/null || true)
    AGENT_COUNT="${AGENT_COUNT##*$'\n'}"  # take last line only
    if [ -n "$AGENT_COUNT" ] && [ "$AGENT_COUNT" -gt 0 ] 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Found $AGENT_COUNT registered agents"
    fi
fi

if [ -d "$BACKUP_DIR" ]; then
    echo
    echo -e "${YELLOW}Backups saved in: $BACKUP_DIR${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# OpenCode Installation
# ═══════════════════════════════════════════════════════════════════════════════

if command -v opencode &> /dev/null; then
    echo
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  OpenCode Workflow Installation       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo

    OPENCODE_DIR="$HOME/.config/opencode"
    OPENCODE_BACKUP="$OPENCODE_DIR/.backup-$(date +%Y%m%d-%H%M%S)"

    mkdir -p "$OPENCODE_DIR"

    # 1. Orchestrator rules
    echo -e "${BLUE}[1/8] Orchestrator Rules${NC}"
    if [ "$UPGRADE_MODE" = true ]; then
        copy_with_backup "$SCRIPT_DIR/.opencode/orchestrator-rules.md" "$OPENCODE_DIR/orchestrator-rules.md"
    else
        copy_if_not_exists "$SCRIPT_DIR/.opencode/orchestrator-rules.md" "$OPENCODE_DIR/orchestrator-rules.md" || true
    fi

    # 2. Commands
    echo -e "\n${BLUE}[2/8] Commands${NC}"
    mkdir -p "$OPENCODE_DIR/commands"
    for cmd in "$SCRIPT_DIR/.opencode/commands"/*.md; do
        if [ -f "$cmd" ]; then
            if [ "$UPGRADE_MODE" = true ]; then
                copy_with_backup "$cmd" "$OPENCODE_DIR/commands/$(basename "$cmd")"
            else
                copy_if_not_exists "$cmd" "$OPENCODE_DIR/commands/$(basename "$cmd")" || true
            fi
        fi
    done

    # 3. Agents (flat directory)
    echo -e "\n${BLUE}[3/8] Agents${NC}"
    mkdir -p "$OPENCODE_DIR/agents"
    for agent in "$SCRIPT_DIR/.opencode/agents"/*.md; do
        if [ -f "$agent" ]; then
            if [ "$UPGRADE_MODE" = true ]; then
                copy_with_backup "$agent" "$OPENCODE_DIR/agents/$(basename "$agent")"
            else
                copy_if_not_exists "$agent" "$OPENCODE_DIR/agents/$(basename "$agent")" || true
            fi
        fi
    done

    # 4. Rules
    echo -e "\n${BLUE}[4/8] Rules${NC}"
    mkdir -p "$OPENCODE_DIR/rules"
    for rule in "$SCRIPT_DIR/.opencode/rules"/*.md; do
        if [ -f "$rule" ]; then
            if [ "$UPGRADE_MODE" = true ]; then
                copy_with_backup "$rule" "$OPENCODE_DIR/rules/$(basename "$rule")"
            else
                copy_if_not_exists "$rule" "$OPENCODE_DIR/rules/$(basename "$rule")" || true
            fi
        fi
    done

    # 5. Docs
    echo -e "\n${BLUE}[5/8] Docs${NC}"
    mkdir -p "$OPENCODE_DIR/docs"
    for doc in "$SCRIPT_DIR/.opencode/docs"/*.md; do
        if [ -f "$doc" ]; then
            if [ "$UPGRADE_MODE" = true ]; then
                copy_with_backup "$doc" "$OPENCODE_DIR/docs/$(basename "$doc")"
            else
                copy_if_not_exists "$doc" "$OPENCODE_DIR/docs/$(basename "$doc")" || true
            fi
        fi
    done

    # 6. AGENTS.md (global instructions)
    echo -e "\n${BLUE}[6/8] AGENTS.md${NC}"
    if [ -f "$SCRIPT_DIR/.opencode/AGENTS.md" ]; then
        if [ "$UPGRADE_MODE" = true ]; then
            copy_with_backup "$SCRIPT_DIR/.opencode/AGENTS.md" "$OPENCODE_DIR/AGENTS.md"
        else
            copy_if_not_exists "$SCRIPT_DIR/.opencode/AGENTS.md" "$OPENCODE_DIR/AGENTS.md" || true
        fi
    fi

    # 7. Plugin
    echo -e "\n${BLUE}[7/8] Workflow Plugin${NC}"
    mkdir -p "$OPENCODE_DIR/plugins"
    copy_with_backup "$SCRIPT_DIR/.opencode/plugins/workflow-plugin.ts" "$OPENCODE_DIR/plugins/workflow-plugin.ts"

    # Install plugin dependencies
    if [ -f "$SCRIPT_DIR/.opencode/package.json" ]; then
        cp "$SCRIPT_DIR/.opencode/package.json" "$OPENCODE_DIR/package.json"
        if command -v bun &> /dev/null; then
            (cd "$OPENCODE_DIR" && bun install --silent 2>/dev/null) \
                && echo -e "  ${GREEN}✓${NC} Dependencies installed" \
                || echo -e "  ${YELLOW}⚠${NC} bun install failed (run manually: cd ~/.config/opencode && bun install)"
        else
            echo -e "  ${YELLOW}⚠${NC} bun not found. Install dependencies manually: cd ~/.config/opencode && npm install"
        fi
    fi

    # 8. Update opencode.json (add instructions + mcp)
    echo -e "\n${BLUE}[8/8] Config (opencode.json)${NC}"
    python3 -c "
import json, sys
from pathlib import Path

config_path = Path.home() / '.config' / 'opencode' / 'opencode.json'

if config_path.exists():
    with open(config_path) as f:
        config = json.load(f)
else:
    config = {}

changed = False

# Add instructions
instructions = config.get('instructions', [])
rule_files = [
    '~/.config/opencode/rules/security.md',
    '~/.config/opencode/rules/coding-style.md',
    '~/.config/opencode/rules/performance.md',
    '~/.config/opencode/orchestrator-rules.md',
]
for rule in rule_files:
    if rule not in instructions:
        instructions.append(rule)
        changed = True

if instructions:
    config['instructions'] = instructions

# Add plugin path to 'plugin' array (not 'plugins')
plugin_list = config.get('plugin', [])
if './plugins/workflow-plugin.ts' not in plugin_list and 'plugins/workflow-plugin.ts' not in plugin_list:
    plugin_list.append('./plugins/workflow-plugin.ts')
    changed = True
if plugin_list:
    config['plugin'] = plugin_list

# Add MCP servers
import shutil
mcp = config.get('mcp', {})

if shutil.which('leann_mcp') and 'leann-server' not in mcp:
    mcp['leann-server'] = {
        'type': 'local',
        'command': ['leann_mcp'],
        'enabled': True
    }
    changed = True

if 'context7' not in mcp:
    mcp['context7'] = {
        'type': 'local',
        'command': ['npx', '-y', '@upstash/context7-mcp'],
        'enabled': True
    }
    changed = True

if 'playwright' not in mcp:
    mcp['playwright'] = {
        'type': 'local',
        'command': ['npx', '-y', '@playwright/mcp@latest'],
        'enabled': True
    }
    changed = True

if mcp:
    config['mcp'] = mcp

if changed:
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    print('OK: Config updated')
else:
    print('SKIP: Config already up to date')
" 2>&1 | while read line; do
        if [[ "$line" == "OK:"* ]]; then
            echo -e "  ${GREEN}✓${NC} ${line#OK: }"
        elif [[ "$line" == "SKIP:"* ]]; then
            echo -e "  ${YELLOW}⊘${NC} ${line#SKIP: }"
        else
            echo -e "  ${RED}✗${NC} $line"
        fi
    done

    echo
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  OpenCode installation complete!      ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo
    echo -e "Run ${BLUE}opencode${NC} and try ${BLUE}/orchestrate${NC} to start."
else
    echo
    echo -e "${YELLOW}OpenCode not found. Skipping OpenCode installation.${NC}"
    echo -e "Install OpenCode (https://opencode.ai) and re-run to add OpenCode support."
fi
