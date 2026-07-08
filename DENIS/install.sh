#!/usr/bin/env bash
# ASRP — Claude Code (native) + reviewer agent + global CLAUDE.md + course skill.
# One command:
#   curl -fsSL https://raw.githubusercontent.com/liker0704/claude-code-workflow/main/DENIS/install.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/liker0704/claude-code-workflow/main/DENIS"
ok(){ printf '\033[0;32m✔\033[0m %s\n' "$1"; }

fetch(){ # url dest
  curl -fsSL --retry 3 "$1" -o "$2" \
    || { echo "Network failed while downloading $(basename "$2"). Just run the install command again."; exit 1; }
}

echo "== ASRP setup: Claude Code + reviewer =="

# 1) Claude Code (native installer)
if command -v claude >/dev/null 2>&1; then
  ok "Claude Code already installed ($(claude --version 2>/dev/null || echo '?'))"
else
  curl -fsSL https://claude.ai/install.sh | bash
  ok "Claude Code installed"
fi

# ~/.local/bin on PATH (persist to .profile so it survives even on a bare machine)
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *)
    LINE='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
      # .profile is created if missing; the others only if they already exist
      if [ "$rc" = "$HOME/.profile" ] || [ -f "$rc" ]; then
        grep -qF '.local/bin' "$rc" 2>/dev/null || echo "$LINE" >> "$rc"
      fi
    done
    export PATH="$HOME/.local/bin:$PATH"
    ;;
esac

# 2) fetch files
mkdir -p "$HOME/.claude/agents" "$HOME/.claude/skills/course-writing"

fetch "$BASE/reviewer.md" "$HOME/.claude/agents/reviewer.md"
ok "reviewer agent -> ~/.claude/agents/reviewer.md"

if [ -f "$HOME/.claude/CLAUDE.md" ]; then
  cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.bak-$(date +%Y%m%d-%H%M%S)"
fi
fetch "$BASE/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ok "global CLAUDE.md -> ~/.claude/CLAUDE.md"

fetch "$BASE/course-writing.SKILL.md" "$HOME/.claude/skills/course-writing/SKILL.md"
ok "course-writing skill -> ~/.claude/skills/course-writing/SKILL.md"

echo
ok "Done. Run:  claude   (open a new terminal if 'command not found')"
