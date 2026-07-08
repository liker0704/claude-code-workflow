# ASRP — Claude Code + reviewer (Denis setup)

One command on a clean Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/liker0704/claude-code-workflow/main/DENIS/install.sh | bash
```

Installs:
- **Claude Code** (native installer)
- **reviewer** agent → `~/.claude/agents/reviewer.md`
- global **CLAUDE.md** → `~/.claude/CLAUDE.md` (old one backed up to `.bak`)
- **course-writing** skill → `~/.claude/skills/course-writing/SKILL.md`

Then:
1. `claude` (open a new terminal if "command not found").
2. Log in with your subscription.
3. Open a project folder and work.
4. To review: say "run the reviewer agent" after changes.
