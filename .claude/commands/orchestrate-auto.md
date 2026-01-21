# Orchestrate Auto Command

Autonomous orchestration mode (Ralph Wiggums Mode).
Runs full cycle WITHOUT human intervention after initial interview.

**IMPORTANT:** First read `.claude/orchestrator-rules.md` for critical orchestration rules.

---

You are in **ORCHESTRATOR MODE - AUTONOMOUS**.

## Your Role

You are a **coordinator** that:
- **Phase 1**: Conducts interview to gather requirements (interactive)
- **Phase 2**: Launches autonomous agent that works without human (non-interactive)
- **ALWAYS**: Wait for agents to complete before reading their output

---

## Arguments

```
$ARGUMENTS can be:
- Empty: Show active auto tasks
- Task description: Start new autonomous task
- {slug}: Show status of existing task
- {slug} --continue: Resume after escalation
- {slug} --abort: Cancel and rollback
- {slug} --skip-task N: Skip blocked task N and continue
```

## Phase 0: Parse Arguments and Check State

### Check for existing auto tasks

Search `tmp/.orchestrate-auto/*/task.md` for active tasks.

**If $ARGUMENTS is empty:**
```
## Orchestrate Auto - Active Tasks

| Task | Status | Started | Progress |
|------|--------|---------|----------|
| {slug} | {status} | {date} | {X/Y tasks} |

Commands:
- /orchestrate-auto "task" — start new
- /orchestrate-auto {slug} — view status
- /orchestrate-auto {slug} --continue — resume after escalation
```

**If $ARGUMENTS is existing slug:**
Read task.md and show status, then offer appropriate actions.

**If $ARGUMENTS is existing slug with flag:**
Handle --continue, --abort, --skip-task (see Phase 4).

**If $ARGUMENTS is new task description:**
Continue to Phase 1.

---

## Phase 1: Interview

### 1.1 Complexity Detection

Analyze task description to determine question count:

```python
def detect_complexity(description):
    keywords_simple = ["add", "fix", "button", "typo", "rename", "remove"]
    keywords_complex = ["integrate", "architecture", "refactor", "migrate", "auth", "api"]

    desc_lower = description.lower()

    if any(k in desc_lower for k in keywords_complex):
        return "complex", 15
    elif any(k in desc_lower for k in keywords_simple):
        return "simple", 5
    else:
        return "medium", 10
```

### 1.2 Core Questions (always ask)

```
1. Что конкретно должно измениться? Опиши детально.

2. Какие файлы/директории МОЖНО менять?
   (или "не знаю" — определю по контексту)

3. Какие файлы НЕЛЬЗЯ трогать?
   (default: core/, config/prod*, *.env, *.secret*)

4. Как проверить что готово? (тест, команда, поведение)

5. Что НИКОГДА не делать? (red lines)
```

### 1.3 Extended Questions (medium/complex)

```
6. Можно добавлять новые зависимости? Какие ограничения?

7. Какие паттерны/conventions использовать?
   (или "как в проекте" — изучу существующие)

8. Какие edge cases учитывать?

9. При каких ошибках останавливаться и звать на помощь?

10. Есть ли deadline или ограничение по времени?
```

### 1.4 Complex Questions (only complex)

```
11. Как задача связана с другими частями системы?

12. Какие компромиссы приемлемы? (performance vs readability, etc.)

13. Нужна ли обратная совместимость?

14. Как обрабатывать миграции данных (если есть)?

15. Кто будет код-ревьюить? Какие требования?
```

### 1.5 Handle "Не знаю" Answers

Use defaults:

```yaml
defaults:
  files_can_modify: "определю по контексту задачи"
  files_cannot_modify: "core/, config/prod*, *.env, *.secret*, migrations/"
  dependencies: "только если необходимо, предпочитаю существующие"
  patterns: "как в проекте, изучу существующий код"
  red_lines: "не удалять данные, не менять prod config, не ломать существующие тесты"
  verification: "npm test / pytest / cargo test (определю по проекту)"
```

### 1.6 Generate Requirements Summary

After interview, show summary for confirmation:

```markdown
## Summary

**Задача:** {task description}

**Scope:**
- Можно менять: {files/dirs}
- Нельзя трогать: {files/dirs}

**Проверка готовности:**
- {verification criteria}

**Red lines:**
- {constraints}

**Дополнительно:**
- Dependencies: {policy}
- Patterns: {approach}

---

Всё правильно? [да / нет / уточнить]
```

### 1.7 Handle Confirmation

**On "да":** Proceed to Phase 2
**On "нет":** Ask what to change, update, re-confirm
**On "уточнить":** Ask for specific clarification

---

## Phase 2: Initialize Task

### 2.1 Generate Slug

Create URL-safe slug from task description (same rules as orchestrate.md).

### 2.2 Create Directory Structure

```bash
mkdir -p tmp/.orchestrate-auto/{task-slug}/research
mkdir -p tmp/.orchestrate-auto/{task-slug}/plan
mkdir -p tmp/.orchestrate-auto/{task-slug}/execution
```

### 2.3 Write task.md

```markdown
# Auto Task: {task-slug}

Created: {YYYY-MM-DD HH:MM:SS}
Status: confirmed
Initial-commit: {git rev-parse HEAD}

## Description

{Original task description}

## Requirements

{Full requirements from interview}
```

### 2.4 Write requirements.md

Full requirements document from interview for the autonomous agent.

---

## Phase 3: Launch Autonomous Agent

### 3.1 Pre-launch Message

```
## Запуск автономного выполнения

Задача: {task-slug}
Directory: tmp/.orchestrate-auto/{task-slug}/

Агент будет работать автономно:
- Research → Plan → Execute → Validate

Прогресс сохраняется в файлы.
Git commits после каждого успешного шага.

Можешь свернуть терминал и вернуться позже.
Или жди здесь — увидишь результат.

Запускаю...
```

### 3.2 Launch Agent

```yaml
Tool: Task
Parameters:
  subagent_type: "implementer"
  prompt: |
    # Autonomous Task Execution

    You are an autonomous agent. Work WITHOUT asking questions.
    All information you need is in requirements below.

    ## Requirements

    {content of requirements.md}

    ## Working Directory

    tmp/.orchestrate-auto/{task-slug}/

    ## Your Workflow

    ### Step 1: Research
    - Explore codebase relevant to the task
    - Find existing patterns and conventions
    - Identify files to modify
    - Write findings to research/summary.md

    ### Step 2: Plan
    - Create implementation plan
    - Break into atomic tasks (max 15)
    - Define verification for each task
    - Write to plan/plan.md and plan/tasks.md

    ### Step 3: Execute
    For each task:
    - Implement the change
    - Run verification
    - If fails: fix and retry (max 3 attempts)
    - If same error 3 times: ESCALATE
    - If success: git commit
    - Update execution/progress.md

    ### Step 4: Validate
    - Run full verification (tests, lint, build)
    - Check all requirements met
    - Write final report

    ## Self-Correction Rules

    When you encounter an error:
    1. Analyze the error
    2. Attempt fix
    3. Retry
    4. If same error 3 times → ESCALATE
    5. If different error → reset counter, try again

    Max attempts per task: 3
    Max total escalations: 1 (then stop)

    ## Scope Guard

    NEVER modify files in cannot_modify list.
    If task requires modifying forbidden file → ESCALATE

    Cannot modify:
    {from requirements}

    ## Git Checkpoints

    After each successful task:
    ```
    git add -A
    git commit -m "feat({task-slug}): {task-name}"
    ```

    ## On Success

    Write to _result.md:
    ```markdown
    # Result: SUCCESS

    ## Completed
    - {list of completed tasks with commits}

    ## Verification
    - Tests: PASS
    - Lint: PASS
    - Build: PASS

    ## Summary
    {what was done}

    ## Files Changed
    | File | Action | Description |
    |------|--------|-------------|
    ```

    ## On Escalation

    Write to _escalation.md:
    ```markdown
    # Escalation: {task-slug}

    ## TL;DR
    {one line: why stopped}

    ## Reason
    {detailed explanation}

    ## What's Done
    - [x] {completed tasks}
    - [ ] {current task} — BLOCKED: {reason}
    - [ ] {pending tasks}

    ## Git Commits
    {list of commits made}

    ## To Continue
    1. {what user needs to do}
    2. Run: /orchestrate-auto {task-slug} --continue

    ## Or
    - /orchestrate-auto {task-slug} --skip-task {N}
    - /orchestrate-auto {task-slug} --abort
    ```

    Then STOP. Do not continue after escalation.

    ## Escalation Triggers

    MUST escalate when:
    - Same error 3 times
    - Need to modify forbidden file
    - Need external resource (API key, DB, etc.)
    - Requirement is ambiguous (can't determine what to do)
    - Tests fail and can't understand why after 3 attempts

    ## Progress Tracking

    Update execution/progress.md after each step:
    ```markdown
    # Progress

    Started: {timestamp}
    Current: {task-name}

    ## Tasks
    - [x] task-01: {name} (commit: {hash})
    - [~] task-02: {name} (attempt 2/3)
    - [ ] task-03: {name}

    ## Errors Fixed
    - {error description} (attempt N)
    ```

  description: "Auto execute: {task-slug}"
  timeout: 600000
```

### 3.3 Wait for Completion

Monitor agent. When done, read result:

- If `_result.md` exists with SUCCESS → show success summary
- If `_escalation.md` exists → show escalation and options

---

## Phase 4: Handle Completion

### 4.1 On Success

```
## Автономное выполнение завершено: SUCCESS

Задача: {task-slug}

### Выполнено
{from _result.md}

### Commits
{git log --oneline for task commits}

### Проверка
- Tests: PASS
- Lint: PASS
- Build: PASS

---

Что дальше?
- git push — отправить изменения
- git diff HEAD~{N} — посмотреть все изменения
- /orchestrate-auto {slug} --abort — откатить всё
```

### 4.2 On Escalation

```
## Автономное выполнение остановлено: NEEDS HELP

Задача: {task-slug}

### Причина
{from _escalation.md TL;DR}

### Прогресс
{from _escalation.md What's Done}

### Что нужно
{from _escalation.md To Continue}

---

Действия:
- [c] Continue — после исправления, продолжить
- [s] Skip — пропустить проблемный таск
- [a] Abort — откатить все изменения
- [v] View — показать полный _escalation.md

Выбор:
```

---

## Phase 5: Resume Commands

### --continue

```python
def handle_continue(slug):
    state = read_state(slug)

    if state.status != "escalated":
        error("Task is not in escalated state")
        return

    # Find where we stopped
    current_task = find_blocked_task(state)

    # Re-launch agent from that point
    launch_agent(
        start_from=current_task,
        completed_tasks=state.completed_tasks
    )
```

### --skip-task N

```python
def handle_skip(slug, task_number):
    state = read_state(slug)

    # Mark task as skipped
    state.tasks[task_number].status = "skipped"
    save_state(state)

    # Continue from next task
    launch_agent(
        start_from=task_number + 1,
        completed_tasks=state.completed_tasks,
        skipped_tasks=[task_number]
    )
```

### --abort

```python
def handle_abort(slug):
    state = read_state(slug)

    # Confirm
    if not confirm("Откатить ВСЕ изменения до начального состояния?"):
        return

    # Reset to initial commit
    initial = state.initial_commit
    run(f"git reset --hard {initial}")

    # Update state
    state.status = "aborted"
    save_state(state)

    print(f"Откачено до {initial}")
```

---

## Circuit Breakers

```yaml
limits:
  max_attempts_per_task: 3
  max_same_error: 3
  max_files_modified: 30
  max_tasks: 20
```

If limits exceeded → automatic escalation.

---

## State Values

```
confirmed → running → (complete | escalated | aborted)
```

That's it. Simple.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Agent crashes | Check _escalation.md, offer --continue |
| No requirements.md | Error: run interview first |
| Git dirty state | Warn, offer to stash or abort |
| Task already running | Show progress, offer to wait |

---

Begin by parsing $ARGUMENTS and determining the appropriate phase.
