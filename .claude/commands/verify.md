# Verify Command

Pre-commit verification command that runs comprehensive quality checks and produces a unified PASS/FAIL report.

---

You are now in **VERIFICATION MODE**.

## Your Role

Run automated quality checks across the project to ensure code quality before commit. Report results in a clear, actionable format.

---

## Workflow

### Step 1: Auto-detect Project Type

Detect the project type by checking for configuration files in the working directory:

1. **Node.js/JavaScript/TypeScript**: Look for `package.json`
   - Package manager: Check for `package-lock.json` (npm), `yarn.lock` (yarn), `pnpm-lock.yaml` (pnpm)
   - Build tool: Check scripts in package.json for build commands
   - Type checking: Check for `tsconfig.json` or TypeScript in dependencies
   - Linting: Check for ESLint config (`.eslintrc*`, `eslint.config.js`)
   - Testing: Check for Jest, Vitest, Mocha in dependencies

2. **Python**: Look for `pyproject.toml`, `setup.py`, `requirements.txt`, or `Pipfile`
   - Type checking: Check for mypy config or mypy in dependencies
   - Linting: Check for ruff, pylint, flake8 in dependencies/config
   - Testing: Check for pytest, unittest

3. **Rust**: Look for `Cargo.toml`
   - Build: `cargo build`
   - Linting: `cargo clippy`
   - Testing: `cargo test`

4. **Go**: Look for `go.mod`
   - Build: `go build ./...`
   - Linting: Check for golangci-lint, or use `go vet`
   - Testing: `go test ./...`

5. **Java/Kotlin**: Look for `pom.xml` (Maven) or `build.gradle` (Gradle)
   - Build: `mvn compile` or `gradle build`
   - Testing: `mvn test` or `gradle test`

6. **Ruby**: Look for `Gemfile`
   - Testing: `bundle exec rspec` or `rake test`

7. **PHP**: Look for `composer.json`
   - Linting: PHPStan, Psalm
   - Testing: PHPUnit

8. **Shell/Bash**: If project is primarily shell scripts (*.sh)
   - Linting: `shellcheck *.sh`

9. **Generic/Unknown**: If no specific project type detected
   - Run only universal checks (secrets, console.log audit)

### Step 2: Identify Staged/Modified Files

Run git command to get list of files to check:

```bash
git diff --name-only --cached HEAD
```

If no staged files, check modified files:

```bash
git diff --name-only HEAD
```

If no modified files either, check all tracked files in current directory:

```bash
git ls-files
```

Store this file list for secrets scan and console.log audit.

### Step 3: Run Checks

Run checks based on detected project type. Each check should:
- Run the appropriate command
- Capture stdout and stderr
- Determine PASS/FAIL/WARN/SKIP status
- Store output for error reporting

#### Check 1: Build

**Node.js**:
```bash
# Check if build script exists
npm run build --if-present
# Or check package.json for build script first
```

**Python**:
```bash
# Check if project has build configuration
python -m build --check  # or skip if not applicable
```

**Rust**:
```bash
cargo build --all-features
```

**Go**:
```bash
go build ./...
```

**Java (Maven)**:
```bash
mvn compile -q
```

**Java (Gradle)**:
```bash
gradle build -q
```

**Status**:
- PASS: exit code 0
- FAIL: exit code non-zero
- SKIP: no build command found

#### Check 2: Type Check

**TypeScript**:
```bash
npx tsc --noEmit
```

**Python**:
```bash
mypy src/ --strict
# Or check pyproject.toml for mypy config and use that
```

**Go**: Built into `go build`

**Status**:
- PASS: exit code 0
- FAIL: exit code non-zero
- SKIP: no type checker configured

#### Check 3: Lint

**Node.js**:
```bash
npx eslint . --max-warnings 0
# Or check for specific lint script in package.json
npm run lint --if-present
```

**Python**:
```bash
# Prefer ruff (fast)
ruff check .
# Fallback to flake8 or pylint
```

**Rust**:
```bash
cargo clippy -- -D warnings
```

**Go**:
```bash
golangci-lint run
# Fallback to go vet
go vet ./...
```

**Shell**:
```bash
shellcheck **/*.sh
```

**Status**:
- PASS: exit code 0, no warnings
- FAIL: errors found
- WARN: warnings found but no errors
- SKIP: no linter configured

#### Check 4: Tests

**Node.js**:
```bash
npm test
# Or detect test framework: jest, vitest, mocha
```

**Python**:
```bash
pytest --maxfail=1 --tb=short
# Or unittest discovery
python -m pytest
```

**Rust**:
```bash
cargo test --all-features
```

**Go**:
```bash
go test ./... -v
```

**Java (Maven)**:
```bash
mvn test -q
```

**Status**:
- PASS: all tests pass
- FAIL: any test fails
- SKIP: no tests found

#### Check 5: Secrets Scan

Scan staged/modified files for potential secrets using regex patterns.

**Patterns to detect**:
1. **OpenAI API Keys**: `sk-[a-zA-Z0-9]{20,}`
2. **AWS Access Keys**: `AKIA[A-Z0-9]{16}`
3. **Generic API Keys**: `api[_-]?key['":\s=]+[a-zA-Z0-9]{16,}`
4. **Passwords in code**: `password\s*[=:]\s*['"][^'"]{3,}['"]`
5. **Private keys**: `-----BEGIN (RSA |DSA )?PRIVATE KEY-----`
6. **GitHub tokens**: `gh[pousr]_[A-Za-z0-9_]{36,}`
7. **Slack tokens**: `xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[A-Za-z0-9]{24,}`
8. **Generic secrets**: `secret['":\s=]+[a-zA-Z0-9]{16,}`

**Implementation**:
```bash
# For each file in staged/modified list
grep -nE "sk-[a-zA-Z0-9]{20,}|AKIA[A-Z0-9]{16}|password\s*[=:]\s*['\"][^'\"]{3,}['\"]|-----BEGIN.*PRIVATE KEY-----|api[_-]?key['\"]?\s*[:=]\s*['\"]?[a-zA-Z0-9]{16,}" <file>
```

**Exclusions**:
- Skip `.env.example`, `.env.template`, `*.example.*` files
- Skip test fixtures with obvious dummy data
- Skip documentation files with example patterns

**Status**:
- PASS: no secrets detected
- FAIL: potential secrets found (show file:line)
- SKIP: no files to scan

#### Check 6: Console.log / Debug Statements Audit

Find debugging statements that should be removed before commit.

**Patterns by language**:

**JavaScript/TypeScript**:
- `console.log(`, `console.debug(`, `console.warn(` (but allow `console.error(`)
- `debugger;`

**Python**:
- `print(` (in non-test, non-CLI files)
- `pprint(`, `pp(`
- `import pdb` or `breakpoint()`

**Go**:
- `fmt.Println(`, `log.Println(` (but allow in main.go or *_test.go)

**Rust**:
- `println!(`, `dbg!(` (but allow in tests)

**Implementation**:
```bash
# JavaScript/TypeScript (exclude test files)
grep -rn --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
     --exclude="*.test.*" --exclude="*.spec.*" \
     "console\.(log|debug|warn)" .

# Python (exclude test files and scripts with if __name__ == "__main__")
grep -rn --include="*.py" --exclude="*test*.py" "print(" . | grep -v "__main__"
```

**Status**:
- PASS: no debug statements found
- WARN: debug statements found (show file:line, but don't fail)
- SKIP: not applicable to project type

### Step 4: Generate Report

After all checks complete, generate a summary table:

```markdown
## Verification Report

| Check | Status | Details |
|-------|--------|---------|
| Build | {PASS/FAIL/SKIP} | {summary or error} |
| Types | {PASS/FAIL/SKIP} | {summary or error} |
| Lint | {PASS/FAIL/WARN/SKIP} | {summary or error} |
| Tests | {PASS/FAIL/SKIP} | {summary or error} |
| Secrets | {PASS/FAIL/SKIP} | {summary or error} |
| Debug Statements | {PASS/WARN/SKIP} | {summary or error} |

---

## Overall: {PASS/FAIL}

{If FAIL, list what needs to be fixed}
{If WARN, list warnings but note that commit can proceed}
```

### Step 5: Show Error Details

For any check that failed, show the relevant error output:

```markdown
### Build Errors

{First 50 lines of build output}
```

```markdown
### Lint Errors

{Formatted lint errors with file:line:message}
```

```markdown
### Secrets Detected

⚠️ CRITICAL: Potential secrets found in:

- `src/config.ts:42`: Potential API key: `api_key = "sk-abc123..."`
- `lib/auth.py:15`: Potential password: `password = "secret123"`

REMOVE THESE BEFORE COMMITTING!
```

```markdown
### Debug Statements Found

⚠️ Debug statements found (consider removing):

- `src/utils.js:28`: console.log("debug info")
- `lib/helper.py:102`: print("temporary debug")

These are warnings only and won't block commit.
```

### Step 6: Exit Status

After displaying report:

- If overall status is **FAIL**: Exit (don't offer to commit)
- If overall status is **PASS** or **WARN**: Show summary

For **PASS**:
```
✅ All checks passed! Safe to commit.
```

For **WARN**:
```
⚠️ Warnings found but no critical issues. Review warnings above.
```

---

## Special Handling for Project Types

### For Shell Script Projects (like this one)

If project has no package.json/pyproject.toml/etc, but has .sh files:

1. **Build**: SKIP
2. **Types**: SKIP
3. **Lint**: Run `shellcheck` on all .sh files
4. **Tests**: Look for test scripts (test_*.sh, *_test.sh) and run them
5. **Secrets**: Scan all .sh and .md files
6. **Debug**: Look for `set -x` (debug mode) in scripts

### For Mixed Projects

If multiple project types detected (e.g., Node.js + Python):
- Run checks for ALL detected types
- Combine results in single report

---

## Error Handling

If any check command fails to run (command not found):
- Mark as SKIP
- Add note in Details: "Tool not found: {command}"

If git commands fail:
- Fall back to checking all files in working directory
- Add note: "Git not available, checking all files"

---

## Examples

### Example 1: Node.js Project (All Pass)

```
## Verification Report

| Check | Status | Details |
|-------|--------|---------|
| Build | PASS | npm run build completed in 2.3s |
| Types | PASS | tsc --noEmit completed, no errors |
| Lint | PASS | eslint checked 42 files, 0 errors |
| Tests | PASS | 127 passed, 0 failed (3.2s) |
| Secrets | PASS | Scanned 42 files, no secrets detected |
| Debug Statements | PASS | No console.log found in source files |

---

## Overall: PASS

✅ All checks passed! Safe to commit.
```

### Example 2: Python Project (Lint Fail)

```
## Verification Report

| Check | Status | Details |
|-------|--------|---------|
| Build | SKIP | No build step configured |
| Types | PASS | mypy found 0 errors |
| Lint | FAIL | ruff found 3 errors |
| Tests | PASS | pytest: 89 passed, 0 failed |
| Secrets | PASS | No secrets detected |
| Debug Statements | WARN | 2 print() statements found |

---

## Overall: FAIL

Fix the following before committing:

### Lint Errors

src/main.py:15:1: F401 [*] `os` imported but unused
src/utils.py:42:80: E501 Line too long (93 > 79 characters)
src/config.py:7:1: F821 Undefined name `ConfigParser`

Run: ruff check --fix . (to auto-fix F401)

### Debug Statements (warnings only)

src/main.py:28: print("Debug: processing item")
src/utils.py:102: print(f"Temporary: {data}")
```

### Example 3: Shell Script Project

```
## Verification Report

| Check | Status | Details |
|-------|--------|---------|
| Build | SKIP | Not applicable for shell project |
| Types | SKIP | Not applicable for shell project |
| Lint | PASS | shellcheck: 3 scripts checked, 0 issues |
| Tests | SKIP | No test scripts found |
| Secrets | PASS | No secrets detected in 3 .sh files |
| Debug Statements | WARN | 1 script has 'set -x' enabled |

---

## Overall: WARN

⚠️ Warnings found but no critical issues.

### Debug Statements

install.sh:3: set -x (debug mode enabled)

Consider removing debug flags before production release.
```

---

## Performance Optimization

Run checks in parallel where possible:

1. **Independent checks** (can run in parallel):
   - Secrets scan
   - Debug statements audit
   - Lint
   - Type check

2. **Sequential checks**:
   - Build must complete before tests (tests may need build artifacts)

Use bash background jobs:
```bash
# Start parallel jobs
run_lint &
run_typecheck &
run_secrets_scan &
run_debug_audit &

# Wait for all to complete
wait

# Then run sequential
run_build
run_tests
```

---

## Implementation Notes

1. **Use bash commands** via Bash tool for all checks
2. **Capture output** to variables for error reporting
3. **Parse exit codes** to determine PASS/FAIL
4. **Count errors/warnings** from tool output
5. **Format output** in markdown table
6. **Keep it fast**: timeout long-running checks (e.g., 5 min max)

---

## Common Pitfall Avoidance

- **Don't run tests that require database/network** unless explicitly configured
- **Don't fail on warnings** from linters (WARN status instead)
- **Don't scan binary files** for secrets (only text files)
- **Don't block on missing tools** (SKIP instead)
- **Don't show full output** for passing checks (keep report concise)

---

Begin verification by detecting project type and running appropriate checks.
