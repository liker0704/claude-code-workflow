# Build Fix Command

Incremental build error fixing loop.

---

You are now in **BUILD-FIX MODE**.

## Your Role

You are a **build error fixer** that:
- **DO**: Auto-detect build command
- **DO**: Run build, parse FIRST error, fix it, retry
- **DO**: Loop until clean or max attempts (5)
- **DO**: Use Read/Edit tools for precise fixes
- **DON'T**: Try to fix multiple errors at once
- **DON'T**: Make changes to code you haven't analyzed
- **DON'T**: Exceed max attempts

---

## Your Task

Fix build errors incrementally until the build succeeds or max attempts reached.

## Step 1: Detect Build Command

Check for project files in current directory and auto-detect build command:

```python
detection_order = [
    ("package.json", "npm run build"),
    ("Cargo.toml", "cargo build"),
    ("go.mod", "go build ./..."),
    ("Makefile", "make"),
    ("pyproject.toml", "python -m py_compile **/*.py"),
    ("build.gradle", "./gradlew build"),
    ("pom.xml", "mvn compile"),
    ("CMakeLists.txt", "cmake --build ."),
]

for (file, command) in detection_order:
    if exists(file):
        build_command = command
        break
else:
    # No recognized project file
    error("Could not detect build system. Supported: npm, cargo, go, make, python, gradle, maven, cmake")
```

**Special cases:**
- **package.json**: Check if "build" script exists, if not use "npm run compile" or "npx tsc"
- **Makefile**: Check if "build" target exists, if not use "make all"
- **Python**: Only compile if no pyproject.toml, otherwise use "python -m build"

Show detected command:
```
## Build Command Detected

Project type: {type}
Command: {build_command}

Starting incremental fix loop (max 5 attempts)...
```

## Step 2: Initialize Loop State

```python
max_attempts = 5
current_attempt = 0
last_error = None
errors_fixed = []
```

## Step 3: Build Error Fix Loop

For each attempt (1 to 5):

### 3.1 Run Build Command

```bash
{build_command} 2>&1
```

Capture full output and exit code.

### 3.2 Check Build Result

**If exit code == 0 (success):**
```
✅ BUILD SUCCESS

Attempts: {current_attempt}
Errors fixed: {len(errors_fixed)}

### Fixes Applied
{for each error in errors_fixed:
  - Attempt {N}: {error.description}
    File: {error.file}:{error.line}
    Fix: {error.fix_description}
}

Build is now clean.
```
STOP. Done.

**If exit code != 0 (failure):**
Continue to 3.3

### 3.3 Parse First Error

Extract FIRST error from build output using language-specific patterns:

**JavaScript/TypeScript (npm, tsc):**
```regex
Pattern: ^(.+?)\((\d+),(\d+)\): error TS\d+: (.+)$
or: ^(.+?):(\d+):(\d+) - error: (.+)$

Extract: file_path, line_number, column, error_message
```

**Rust (cargo):**
```regex
Pattern: ^error(\[E\d+\])?: (.+)$
followed by: ^\s+-->\s+(.+?):(\d+):(\d+)$

Extract: error_code, error_message, file_path, line_number, column
```

**Go:**
```regex
Pattern: ^(.+?):(\d+):(\d+): (.+)$

Extract: file_path, line_number, column, error_message
```

**Python:**
```regex
Pattern: File "(.+?)", line (\d+)
followed by error message

Extract: file_path, line_number, error_message
```

**C/C++ (make, cmake):**
```regex
Pattern: ^(.+?):(\d+):(\d+): error: (.+)$

Extract: file_path, line_number, column, error_message
```

**Java (maven, gradle):**
```regex
Pattern: ^\[ERROR\] (.+?):\[(\d+),(\d+)\] (.+)$
or: ^(.+?):(\d+): error: (.+)$

Extract: file_path, line_number, column, error_message
```

If no pattern matches:
```
⚠️ Could not parse error from build output.

Raw output (first 50 lines):
{build_output[:50]}

Manual intervention needed.
```
STOP.

### 3.4 Check for Duplicate Error

Compare current error with last_error:

```python
if current_error.file == last_error.file and
   current_error.line == last_error.line and
   current_error.message == last_error.message:
    # Same error again
    show_stuck()
    STOP
```

**Stuck message:**
```
⚠️ STUCK: Same error after fix

Attempt: {current_attempt}
Error: {error_message}
File: {file_path}:{line_number}

The fix did not resolve the error.

### Build Output
{relevant_section}

### Last Fix Applied
{last_fix_description}

Manual intervention needed.
```

### 3.5 Read Error Context

Read the file around the error line:

```python
context_lines = 10
start_line = max(1, error.line - context_lines)
end_line = error.line + context_lines

file_content = read_file(error.file, start_line, end_line)
```

### 3.6 Analyze and Fix Error

Analyze error message and context to determine fix:

**Common error patterns:**
- **Undefined variable/function**: Check imports, check typos, check scope
- **Type mismatch**: Add type cast, fix declaration, import type
- **Syntax error**: Fix syntax (missing semicolon, bracket, etc.)
- **Missing dependency**: Check if import is correct, if package is installed
- **Path error**: Check relative/absolute paths, check file exists

Apply fix using Edit tool on the specific file.

Show what you're doing:
```
## Attempt {current_attempt}/5

Error: {error_message}
File: {file_path}:{line_number}

### Analysis
{brief analysis of what's wrong}

### Fix Applied
{description of the fix}

Retrying build...
```

### 3.7 Update Loop State

```python
errors_fixed.append({
    "attempt": current_attempt,
    "file": error.file,
    "line": error.line,
    "message": error.message,
    "fix": fix_description
})

last_error = current_error
current_attempt += 1
```

### 3.8 Check Attempt Limit

If current_attempt >= max_attempts:
```
⚠️ MAX ATTEMPTS REACHED

Fixed {len(errors_fixed)} errors but build still failing.

### Errors Fixed
{for each error in errors_fixed:
  - Attempt {N}: {error.description}
}

### Current Error
File: {error.file}:{line_number}
Error: {error.message}

### Build Output
{relevant_section}

Manual intervention needed. The build may have deeper issues.
```
STOP.

**Otherwise:** Go back to 3.1 (run build again)

## Step 4: Summary

When loop completes (success or failure), show summary:

```
## Build Fix Summary

Duration: {time_elapsed}
Attempts: {current_attempt}
Status: {SUCCESS | MAX_ATTEMPTS | STUCK | PARSE_ERROR}

### Errors Fixed
{list with file:line, description, fix}

### Files Modified
{list of unique files changed}

{if success:
  Next steps:
  - Run tests: {test_command}
  - Review changes: git diff
}

{if failure:
  Next steps:
  - Review build output above
  - Check for dependency issues
  - Verify environment setup
}
```

## Error Detection Strategies

### TypeScript/JavaScript
- Look for "error TS" or "error:" in output
- Check for "Build failed" or "Compilation failed"
- Parse from `tsc --noEmit` output if available

### Rust
- Look for "error:" or "error[E" in output
- Check "could not compile" message
- Parse from `cargo check` output format

### Go
- Look for ".go:" followed by line number and error
- Check "build failed" or "compile error"

### Python
- Look for "SyntaxError", "IndentationError", "NameError"
- Parse traceback format

### C/C++
- Look for ": error:" in gcc/clang output
- Check "make: *** [target] Error N"

### Java
- Look for "[ERROR]" in maven output
- Check "compilation failed" in gradle output

## Circuit Breakers

Stop immediately if:
- Same error appears twice in a row (stuck)
- Max attempts (5) reached
- Cannot parse error from output
- Build command not found
- File mentioned in error does not exist

## Important Notes

- **One error at a time**: Always fix FIRST error only
- **Precise fixes**: Use Edit tool for surgical changes
- **Context matters**: Read surrounding code before fixing
- **Don't guess**: If error is unclear, stop and ask for help
- **Test after**: Suggest running tests after successful build

---

Begin by detecting the build command for the current project.
