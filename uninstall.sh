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

# Helper function
remove_if_exists() {
    local file="$1"
    local name=$(basename "$file")
    if [ -f "$file" ]; then
        rm "$file"
        echo -e "  ${RED}✗${NC} $name"
    fi
}

# 1. Orchestrator Rules
echo -e "${BLUE}[1/8] Orchestrator Rules${NC}"
remove_if_exists "$CLAUDE_DIR/orchestrator-rules.md"

# 2. Commands
COMMANDS=(
    "orchestrate.md"
    "orchestrate-research.md"
    "orchestrate-architecture.md"
    "orchestrate-plan.md"
    "orchestrate-execute.md"
    "orchestrate-auto.md"
    "verify.md"
    "build-fix.md"
)

echo -e "\n${BLUE}[2/8] Commands${NC}"
for cmd in "${COMMANDS[@]}"; do
    remove_if_exists "$CLAUDE_DIR/commands/$cmd"
done

# 3. Agents
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
    "security-reviewer.md"
    "strategy-generator.md"
    "plan-simulator.md"
    "performance-critic.md"
    "security-critic.md"
)

echo -e "\n${BLUE}[3/8] Agents${NC}"
for agent in "${AGENTS[@]}"; do
    remove_if_exists "$CLAUDE_DIR/agents/$agent"
done

# 4. Rules
RULES=(
    "security.md"
    "coding-style.md"
    "performance.md"
)

echo -e "\n${BLUE}[4/8] Rules${NC}"
for rule in "${RULES[@]}"; do
    remove_if_exists "$CLAUDE_DIR/rules/$rule"
done

# 5. Docs
DOCS=(
    "orchestrate-file-formats.md"
)

echo -e "\n${BLUE}[5/8] Docs${NC}"
for doc in "${DOCS[@]}"; do
    remove_if_exists "$CLAUDE_DIR/docs/$doc"
done

# 6. Validators
echo -e "\n${BLUE}[6/8] Validators${NC}"
remove_if_exists "$CLAUDE_DIR/validators/validate-orchestrate-files.py"

# 7. Hooks (Python files)
echo -e "\n${BLUE}[7/8] Hook scripts${NC}"
remove_if_exists "$CLAUDE_DIR/hooks/session-start.py"
remove_if_exists "$CLAUDE_DIR/hooks/session-end.py"

# 8. Remove hooks from settings.json
echo -e "\n${BLUE}[8/8] Settings.json hooks${NC}"
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    python3 -c "
import json, sys
settings_path = '$CLAUDE_DIR/settings.json'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
changed = False

# Remove PreToolUse validator hook
pre = hooks.get('PreToolUse', [])
new_pre = [h for h in pre if not (isinstance(h, dict) and 'validate-orchestrate-files.py' in str(h.get('hooks', [{}])[0].get('command', '')) if h.get('hooks') else False)]
if len(new_pre) != len(pre):
    hooks['PreToolUse'] = new_pre
    changed = True

# Remove SessionStart hook
ss = hooks.get('SessionStart', [])
new_ss = [h for h in ss if not any('session-start.py' in sub.get('command', '') for sub in h.get('hooks', []))]
if len(new_ss) != len(ss):
    hooks['SessionStart'] = new_ss
    changed = True

# Remove SessionEnd hook
se = hooks.get('SessionEnd', [])
new_se = [h for h in se if not any('session-end.py' in sub.get('command', '') for sub in h.get('hooks', []))]
if len(new_se) != len(se):
    hooks['SessionEnd'] = new_se
    changed = True

# Clean up empty hook arrays
for key in list(hooks.keys()):
    if not hooks[key]:
        del hooks[key]

if not hooks:
    del settings['hooks']

if changed:
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    print('  Hooks removed from settings.json')
else:
    print('  No hooks to remove')
" 2>/dev/null && echo -e "  ${GREEN}✓${NC} Cleaned" || echo -e "  ${YELLOW}⊘${NC} Manual cleanup may be needed"
fi

# 9. Remove LEANN MCP
echo -e "\n${BLUE}[9/9] LEANN MCP${NC}"
if command -v claude &> /dev/null; then
    claude mcp remove leann-server 2>/dev/null && echo -e "  ${GREEN}✓${NC} LEANN MCP removed" || echo -e "  ${YELLOW}⊘${NC} LEANN MCP not registered"
else
    echo -e "  ${YELLOW}⊘${NC} claude CLI not found, skipping"
fi

echo
echo -e "${GREEN}Uninstall complete.${NC}"
echo -e "Restart Claude Code to apply changes."
