#!/bin/bash

# Claude Code Workflow Installer
# Умная установка с мержем существующих настроек

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/.backup-$(date +%Y%m%d-%H%M%S)"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Claude Code Workflow Installer       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo

# Проверка ~/.claude
if [ ! -d "$CLAUDE_DIR" ]; then
    echo -e "${YELLOW}~/.claude не существует, создаём...${NC}"
    mkdir -p "$CLAUDE_DIR"
fi

# Функция копирования с проверкой
copy_if_not_exists() {
    local src="$1"
    local dst="$2"
    local name=$(basename "$src")

    if [ -e "$dst" ]; then
        echo -e "  ${YELLOW}⊘${NC} $name (уже существует, пропущен)"
        return 1
    else
        cp "$src" "$dst"
        echo -e "  ${GREEN}✓${NC} $name"
        return 0
    fi
}

# Функция копирования с бэкапом
copy_with_backup() {
    local src="$1"
    local dst="$2"
    local name=$(basename "$src")

    if [ -e "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$dst" "$BACKUP_DIR/$name"
        cp "$src" "$dst"
        echo -e "  ${YELLOW}↻${NC} $name (бэкап в .backup-*)"
    else
        cp "$src" "$dst"
        echo -e "  ${GREEN}✓${NC} $name"
    fi
}

# 1. Установка команд
echo -e "${BLUE}[1/4] Команды${NC}"
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "$SCRIPT_DIR/.claude/commands"/*.md; do
    [ -f "$cmd" ] && copy_if_not_exists "$cmd" "$CLAUDE_DIR/commands/$(basename "$cmd")"
done

# 2. Установка агентов
echo -e "\n${BLUE}[2/4] Агенты${NC}"
mkdir -p "$CLAUDE_DIR/agents/core"

for agent in "$SCRIPT_DIR/.claude/agents"/*.md; do
    [ -f "$agent" ] && copy_if_not_exists "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
done

for agent in "$SCRIPT_DIR/.claude/agents/core"/*.md; do
    [ -f "$agent" ] && copy_if_not_exists "$agent" "$CLAUDE_DIR/agents/core/$(basename "$agent")"
done

# 3. Установка валидаторов
echo -e "\n${BLUE}[3/4] Валидаторы${NC}"
mkdir -p "$CLAUDE_DIR/validators"
for val in "$SCRIPT_DIR/.claude/validators"/*.py; do
    [ -f "$val" ] && copy_with_backup "$val" "$CLAUDE_DIR/validators/$(basename "$val")"
done

# 4. Настройка хуков в settings.json
echo -e "\n${BLUE}[4/4] Хуки${NC}"

MERGE_RESULT=$(python3 "$SCRIPT_DIR/merge-settings.py" 2>&1)

if [[ "$MERGE_RESULT" == "SKIP:"* ]]; then
    echo -e "  ${YELLOW}⊘${NC} Хук уже настроен"
elif [[ "$MERGE_RESULT" == "OK:"* ]]; then
    echo -e "  ${GREEN}✓${NC} Хук добавлен в settings.json"
else
    echo -e "  ${RED}✗${NC} Ошибка: $MERGE_RESULT"
fi

# Итоги
echo
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Установка завершена!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo
echo -e "Доступные команды:"
echo -e "  ${BLUE}/orchestrate${NC} <описание>     - начать задачу"
echo -e "  ${BLUE}/orchestrate-research${NC} <slug> - исследование"
echo -e "  ${BLUE}/orchestrate-plan${NC} <slug>     - планирование"
echo -e "  ${BLUE}/orchestrate-execute${NC} <slug>  - выполнение"
echo
echo -e "Перезапусти Claude Code для применения изменений."

if [ -d "$BACKUP_DIR" ]; then
    echo
    echo -e "${YELLOW}Бэкапы сохранены в: $BACKUP_DIR${NC}"
fi
