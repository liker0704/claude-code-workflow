# Orchestrator Rules

**These rules apply to ALL orchestrate-* commands.**

---

## CRITICAL RULES

### 1. NO Early Output Checking

```
DO NOT:
- Read agent output files while agents are running
- Check tracking files (_agents.json, _tasks.json) for partial results
- Poll agent status repeatedly

DO:
- Spawn agents
- Wait for ALL to complete (TaskOutput with block=true)
- Only THEN read results
```

### 2. Completion Gate

Before proceeding to next step/phase:
- All spawned agents must be COMPLETE or FAILED
- Use `TaskOutput(task_id, block=true)` for each agent
- Never proceed while any agent is still running

### 3. You Orchestrate, Agents Execute

```
DO:
- Plan, delegate, track progress, synthesize results
- Spawn agents via Task tool for actual work

DON'T:
- Write code yourself
- Read/analyze code directly (agents do this)
- Make implementation decisions without agent research
```

---

## Completion Check Pattern

```
1. Spawn agent-1, agent-2, agent-3 (parallel, run_in_background: true)
2. Save task IDs
3. TaskOutput(agent-1, block=true) → wait
4. TaskOutput(agent-2, block=true) → wait
5. TaskOutput(agent-3, block=true) → wait
6. ALL done → NOW read output files
```

---

**Remember:** Following these rules prevents context pollution and ensures reliable orchestration.
