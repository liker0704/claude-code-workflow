---
description: Empirical validation of Agent Teams capabilities for super-orchestrator
---

# Agent Teams Canary Test

Empirical validation of Agent Teams capabilities for super-orchestrator.

---

You are now in **CANARY TEST MODE**.

## Your Role

You are running **empirical tests** to validate Agent Teams capabilities. This determines whether the super-orchestrator can use parallel delegation or must fall back to sequential execution.

**CRITICAL:** These are LIVE tests. You will actually create teammates and observe their behavior.

---

## Test Execution

Run the following 3 tests sequentially. Each test must complete before moving to the next.

### Test 1: Teammate + Task Tool (BLOCKING)

**Objective:** Verify teammates can use the Task tool to spawn subagents.

**Procedure:**
1. Create a team with 1 teammate using natural language:
   - Use in-process mode (NOT tmux mode)
   - Give the teammate a clear name like "TaskToolTester"
2. Instruct the teammate: "Use the Task tool with subagent_type 'Explore' to find all .md files in .claude/commands/ directory. Count them and report the exact number."
3. Wait for the teammate to complete the task
4. Observe: Did the teammate successfully use the Task tool? Did you receive a file count?

**Pass Criteria:**
- ✅ PASS: Teammate used Task tool successfully AND reported a numeric file count
- ❌ FAIL: Task tool not available, error occurred, or no count reported

**Evidence to Collect:**
- Teammate's output/response
- Any error messages
- File count (if successful)

---

### Test 2: Delegate Mode (BLOCKING)

**Objective:** Verify teammates can access tools while lead is in delegate mode.

**Context:** Bug #24073 requires spawning teammates BEFORE entering delegate mode.

**Procedure:**
1. If you still have a teammate from Test 1, use it. Otherwise, spawn a new teammate FIRST.
2. Enter delegate mode using natural language instruction
3. Message the teammate: "Read the file .claude/orchestrator-rules.md and report the first markdown heading you find."
4. Wait for response
5. Observe: Did the teammate successfully read the file and report the heading?

**Pass Criteria:**
- ✅ PASS: Teammate reported the correct first heading from the file
- ❌ FAIL: Teammate could not access Read tool, error occurred, or wrong/no heading reported

**Evidence to Collect:**
- Teammate's response with the heading
- Any error messages about tool access
- Whether delegate mode affected teammate's capabilities

---

### Test 3: Hook Events (INFORMATIONAL)

**Objective:** Check if hook events are available for coordination.

**Procedure:**
1. Check if hooks directory exists: `.claude/hooks/`
2. Attempt to read hook documentation if available
3. Observe during Tests 1-2: Were any hooks triggered or mentioned in output?

**Pass Criteria:**
- ✅ PASS: Hooks directory exists AND hooks appear functional
- ❌ FAIL: No hooks directory OR hooks not functional
- ℹ️ INFO: This test does not block super-orchestrator implementation

**Evidence to Collect:**
- Hooks directory existence
- Any hook-related output during tests
- Available hook types

---

## Output Format

After completing all tests, produce this EXACT format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Agent Teams Canary Test Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| Test | Result | Evidence |
|------|--------|----------|
| 1. Teammate + Task Tool | {PASS/FAIL} | {file count or error message} |
| 2. Delegate Mode | {PASS/FAIL} | {heading or error message} |
| 3. Hook Events | {PASS/FAIL} (info) | {hooks available or not found} |

## Decision

{IF Test 1 == PASS AND Test 2 == PASS}:
  ✅ CANARY PASSED — proceed with super-orchestrator implementation
  Capabilities: Full parallel delegation with Task tool support
  Hook mode: {WITH_HOOKS if Test 3 PASS, else POLLING_ONLY}

  Next steps:
  - Implement super-orchestrator with parallel work distribution
  - Use in-process teammate mode (NOT tmux)
  - Spawn teammates BEFORE entering delegate mode (Bug #24073 workaround)
  - {Use hooks for coordination if Test 3 PASS, else use polling/messaging}

{IF Test 1 == FAIL}:
  ❌ CANARY FAILED — teammates cannot use Task tool
  Limitation: Agent Teams exist but teammates cannot spawn subagents

  Fallback strategy:
  - Super-orchestrator LIMITED to SEQUENTIAL MODE ONLY (Layer 1)
  - Each phase runs one agent at a time
  - No parallel task distribution
  - Agent Teams still useful for delegation but no recursion

  Next steps:
  - Implement super-orchestrator Layer 1 only (sequential)
  - Skip Layer 2 (parallel) and Layer 3 (recursive) implementation
  - Document limitation in architecture

{IF Test 1 == PASS AND Test 2 == FAIL}:
  ⚠️ PARTIAL — delegate mode broken
  Limitation: Task tool works but delegate mode restricts teammates

  Workaround:
  - Proceed WITHOUT formal delegate mode
  - Use explicit coordinator prompt pattern instead
  - Lead remains active but focuses on coordination tasks
  - Teammates have full tool access

  Next steps:
  - Implement super-orchestrator with parallel delegation
  - Use coordinator prompt pattern instead of delegate mode
  - Document delegate mode limitation

{IF Agent Teams feature not available at all}:
  🚫 FEATURE NOT AVAILABLE

  Agent Teams feature is not present in this Claude Code version.
  Cannot proceed with super-orchestrator implementation.

  Alternative:
  - Use existing Task tool for single-agent workflows
  - Wait for Agent Teams feature to become available

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Error Handling

If at any point you cannot proceed:

1. **Agent Teams not available:** Report immediately with FEATURE NOT AVAILABLE decision
2. **Test fails unexpectedly:** Document the exact error, mark test as FAIL, continue to next test
3. **Teammate unresponsive:** Wait up to 60 seconds, then mark as FAIL with timeout evidence
4. **Cannot create teammates:** Report FEATURE NOT AVAILABLE

---

## Important Notes

- These tests use REAL Agent Teams functionality, not simulations
- Natural language API: Instruct Claude Code using normal conversation
- In-process mode: Specify this explicitly to avoid tmux bugs
- Timeout: Each test should complete within 2 minutes maximum
- Evidence: Save exact outputs for decision-making

---

## After Completion

1. Display the formatted results table
2. State the clear decision (PASSED/FAILED/PARTIAL)
3. List specific next steps
4. Save results to: `tmp/.orchestrate/super-orchestrator-agent-teams/canary-results.md`

Do NOT proceed with any implementation. This command only runs tests and reports results.
