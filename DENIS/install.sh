#!/usr/bin/env bash
# ASRP — Claude Code (native) + reviewer agent + global CLAUDE.md + course skill.
# One command:
#   curl -fsSL https://raw.githubusercontent.com/liker0704/claude-code-workflow/main/DENIS/install.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/liker0704/claude-code-workflow/main/DENIS"
ok(){ printf '\033[0;32m✔\033[0m %s\n' "$1"; }

echo "== ASRP setup: Claude Code + reviewer =="

# 1) Claude Code (native installer)
if command -v claude >/dev/null 2>&1; then
  ok "Claude Code already installed ($(claude --version 2>/dev/null || echo '?'))"
else
  curl -fsSL https://claude.ai/install.sh | bash
  ok "Claude Code installed"
fi

# ~/.local/bin on PATH
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
       [ -f "$rc" ] && ! grep -q '.local/bin' "$rc" && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
     done; export PATH="$HOME/.local/bin:$PATH" ;;
esac

# 2) fetch files
mkdir -p "$HOME/.claude/agents" "$HOME/.claude/skills/course-writing"
curl -fsSL "$BASE/reviewer.md"            -o "$HOME/.claude/agents/reviewer.md"
ok "reviewer agent -> ~/.claude/agents/reviewer.md"

[ -f "$HOME/.claude/CLAUDE.md" ] && cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.bak-$(date +%Y%m%d-%H%M%S)"
curl -fsSL "$BASE/CLAUDE.md"              -o "$HOME/.claude/CLAUDE.md"
ok "global CLAUDE.md -> ~/.claude/CLAUDE.md"

curl -fsSL "$BASE/course-writing.SKILL.md" -o "$HOME/.claude/skills/course-writing/SKILL.md"
ok "course-writing skill -> ~/.claude/skills/course-writing/SKILL.md"

echo
ok "Done. Run:  claude   (open a new terminal if 'command not found')"
