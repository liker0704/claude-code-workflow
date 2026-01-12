# Claude Code Workflow

Полный набор агентов, команд и хуков для многофазной оркестрации задач в Claude Code.

## Что внутри

```
.claude/
├── commands/                    # Slash-команды
│   ├── orchestrate.md          # /orchestrate - точка входа
│   ├── orchestrate-research.md # /orchestrate-research - фаза исследования
│   ├── orchestrate-plan.md     # /orchestrate-plan - фаза планирования
│   └── orchestrate-execute.md  # /orchestrate-execute - фаза выполнения
│
├── agents/                      # Кастомные агенты
│   ├── codebase-locator.md     # Поиск файлов по описанию
│   ├── codebase-analyzer.md    # Анализ реализации
│   ├── codebase-pattern-finder.md # Поиск паттернов и примеров
│   ├── web-search-researcher.md   # Веб-исследования
│   ├── devil-advocate.md       # Критический ревью планов
│   ├── second-opinion.md       # Независимая валидация
│   └── core/                   # Базовые агенты
│       ├── implementer.md      # Написание кода
│       ├── reviewer.md         # Код-ревью
│       ├── tester.md           # Тестирование
│       ├── architect.md        # Архитектура
│       ├── debugger.md         # Отладка
│       ├── documenter.md       # Документация
│       ├── research.md         # Исследования
│       ├── research-prompt.md  # Промпты для внешних LLM
│       ├── stuck.md            # Эскалация при проблемах
│       └── teacher.md          # Обучение и объяснения
│
├── validators/
│   └── validate-orchestrate-files.py  # Валидация файлов оркестратора
│
└── hooks.json                  # Конфигурация хуков
```

## Установка

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-workflow.git
cd claude-code-workflow
./install.sh
```

Скрипт:
- Копирует только недостающие файлы (не перезаписывает существующие)
- Создаёт бэкапы при обновлении валидаторов
- Настраивает хуки в settings.json (или показывает инструкцию)

### Удаление

```bash
./uninstall.sh
```

## Использование

### Workflow: Research → Plan → Execute

```bash
# 1. Инициализация задачи
/orchestrate "Добавить аутентификацию пользователей"

# 2. Исследование кодовой базы (4 агента параллельно)
/orchestrate-research add-user-auth

# 3. Создание плана и декомпозиция на задачи
/orchestrate-plan add-user-auth

# 4. Выполнение плана через специализированных агентов
/orchestrate-execute add-user-auth
```

### Просто статус

```bash
/orchestrate  # Показывает активные задачи
```

## Фазы

### Phase 1: Research
- **codebase-locator** → находит релевантные файлы
- **codebase-analyzer** → анализирует реализацию
- **codebase-pattern-finder** → ищет похожие паттерны
- **web-search-researcher** → исследует внешние ресурсы
- Результат: `research/_summary.md`

### Phase 2: Plan
- **architect** → проектирует решение
- **devil-advocate** → критикует план
- **second-opinion** → независимая валидация
- Результат: `plan/plan.md` + `plan/tasks.md`

### Phase 3: Execute
- **implementer** → пишет код
- **tester** → создаёт тесты
- **reviewer** → проверяет качество
- Результат: работающий код

## Структура задачи

```
tmp/.orchestrate/{task-slug}/
├── task.md                  # Метаданные и статус
├── research/
│   ├── codebase-locator.md
│   ├── codebase-analyzer.md
│   ├── codebase-pattern-finder.md
│   ├── web-search-researcher.md
│   └── _summary.md
├── plan/
│   ├── plan.md              # Детальный план
│   └── tasks.md             # Декомпозиция задач
└── execution/
    ├── _progress.md
    └── task-XX-*.md
```

## Статусы

```
initialized → researching → research-complete → planning → plan-complete → executing → complete
                                                                              ↓
                                                                          blocked
```

## License

MIT
