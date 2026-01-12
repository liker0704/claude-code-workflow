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

# Подтверждение
read -p "Удалить все компоненты воркфлоу? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Отменено."
    exit 0
fi

echo -e "\n${BLUE}Удаление...${NC}\n"

# Команды
COMMANDS=(
    "orchestrate.md"
    "orchestrate-research.md"
    "orchestrate-plan.md"
    "orchestrate-execute.md"
)

echo -e "${BLUE}[1/3] Команды${NC}"
for cmd in "${COMMANDS[@]}"; do
    if [ -f "$CLAUDE_DIR/commands/$cmd" ]; then
        rm "$CLAUDE_DIR/commands/$cmd"
        echo -e "  ${RED}✗${NC} $cmd"
    fi
done

# Агенты (только кастомные, не трогаем core/)
AGENTS=(
    "codebase-locator.md"
    "codebase-analyzer.md"
    "codebase-pattern-finder.md"
    "web-search-researcher.md"
    "devil-advocate.md"
    "second-opinion.md"
)

echo -e "\n${BLUE}[2/3] Агенты (кастомные)${NC}"
for agent in "${AGENTS[@]}"; do
    if [ -f "$CLAUDE_DIR/agents/$agent" ]; then
        rm "$CLAUDE_DIR/agents/$agent"
        echo -e "  ${RED}✗${NC} $agent"
    fi
done

# Валидаторы
echo -e "\n${BLUE}[3/3] Валидаторы${NC}"
if [ -f "$CLAUDE_DIR/validators/validate-orchestrate-files.py" ]; then
    rm "$CLAUDE_DIR/validators/validate-orchestrate-files.py"
    echo -e "  ${RED}✗${NC} validate-orchestrate-files.py"
fi

echo
echo -e "${YELLOW}Примечание:${NC}"
echo -e "  - Агенты в core/ не удалены (могут использоваться другими)"
echo -e "  - Хук в settings.json нужно удалить вручную"
echo -e "  - Перезапусти Claude Code"
echo
echo -e "${GREEN}Удаление завершено.${NC}"
