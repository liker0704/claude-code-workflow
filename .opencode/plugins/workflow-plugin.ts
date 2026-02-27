/**
 * Workflow Plugin for OpenCode
 *
 * Ports Claude Code hooks to OpenCode plugin system:
 * - validate-orchestrate-files.py → tool.execute.before (PreToolUse)
 * - format-on-write.py → tool.execute.after (PostToolUse)
 * - stats-collector.py → tool.execute.after (PostToolUse)
 * - session-start.py → session.created
 * - session-end.py → session.idle
 */

import type { Plugin } from "@opencode-ai/plugin";
import { existsSync, mkdirSync, readFileSync, writeFileSync, appendFileSync } from "fs";
import { basename, extname, join } from "path";
import { createHash, randomUUID } from "crypto";
import { homedir } from "os";
import { globSync } from "glob";

// ─── Constants ───────────────────────────────────────────────────────────────

const ORCHESTRATE_MARKER = "tmp/.orchestrate/";

const SESSION_DIR = join(homedir(), ".cache", "opencode-workflow", "sessions");
const SESSION_FILE = join(SESSION_DIR, "last-session.json");

const STATS_DIR = join(homedir(), ".local", "share", "opencode-workflow", "stats");
const INDEX_FILE = join(STATS_DIR, "index.jsonl");
const FILES_DIR = join(STATS_DIR, "files");

const SKIP_EXTENSIONS = new Set([
  ".md", ".json", ".yaml", ".yml", ".toml", ".sh", ".txt", ".csv", ".html", ".css",
]);

const VALID_TASK_STATUSES = [
  "initialized", "researching", "research-complete",
  "architecting", "arch-review", "arch-iteration", "arch-escalated",
  "planning", "plan-complete", "executing", "complete",
  "blocked", "abandoned", "cancelled",
];

const VALID_PLAN_STATUSES = ["draft", "approved", "superseded"];
const VALID_RESEARCH_STATUSES = ["draft", "approved", "executing", "complete"];

// ─── Error Hints ─────────────────────────────────────────────────────────────

const ERROR_HINTS: Record<string, [string, string]> = {
  missing_status: [
    "Missing required field: Status:",
    "Add 'Status: initialized' at the top of task.md",
  ],
  missing_created: [
    "Missing required field: Created:",
    "Add 'Created: YYYY-MM-DD' field after Status in task.md",
  ],
  missing_last_updated: [
    "Missing required field: Last-updated:",
    "Add 'Last-updated: YYYY-MM-DD' field after Created in task.md",
  ],
  invalid_status: [
    "Invalid status",
    "Change status to one of the valid values",
  ],
  missing_phases: [
    "Missing '## Phases' section",
    "Add '## Phases' section with checkboxes: Research, Architecture, Plan, Execute",
  ],
  missing_tasks_header: [
    "Missing tasks header",
    "Add '# Tasks' or '# Task Breakdown' header at the top of tasks.md",
  ],
  no_task_definitions: [
    "No task definitions found",
    "Add at least one task: '## task-01' with description",
  ],
  missing_plan_status: [
    "Missing Status field",
    "Add 'Status: draft' at the top of plan.md",
  ],
  invalid_plan_status: [
    "Invalid plan status",
    "Change plan status to one of: draft, approved, superseded",
  ],
  missing_research_status: [
    "Missing Status field",
    "Add 'Status: draft' at the top of _plan.md",
  ],
  invalid_research_status: [
    "Invalid research plan status",
    "Change research status to one of: draft, approved, executing, complete",
  ],
  missing_research_questions: [
    "Missing section: ## 2. Research Questions",
    "Add '## 2. Research Questions' section with questions to answer",
  ],
  missing_concerns_matrix: [
    "Missing section: ## 4. Concerns Matrix",
    "Add '## 4. Concerns Matrix' table with Concern | Priority | Resolution columns",
  ],
  missing_gaps_found: [
    "Missing section: ## 7. Gaps Found",
    "Add '## 7. Gaps Found' section to track knowledge gaps",
  ],
  gap_iterations_exceeded: [
    "Gap iterations exceeded",
    "Reduce gap iterations or escalate to user for decision",
  ],
  missing_complexity_assessment: [
    "Missing required section: ## 8. Complexity Assessment",
    "Add '## 8. Complexity Assessment' section with Score and factors table",
  ],
  missing_complexity_score: [
    "Missing complexity score",
    "Add '**Score:** N (threshold: 5)' in Complexity Assessment section",
  ],
  invalid_complexity_score: [
    "Complexity score must be a number",
    "Fix '**Score:**' to contain a valid number (e.g., '**Score:** 7 (threshold: 5)')",
  ],
  missing_key_findings: [
    "Missing required section: ## Key Findings",
    "Add '## Key Findings' section with research discoveries",
  ],
  missing_recommendations: [
    "Missing required section: ## Recommendations",
    "Add '## Recommendations' section with actionable suggestions",
  ],
  missing_sources: [
    "Missing required section: ## Sources",
    "Add '## Sources' section listing all research sources",
  ],
  no_findings_listed: [
    "No findings in Key Findings section",
    "Add at least one finding: '- **Finding:** \"quote\" (Source: file.md)'",
  ],
  missing_context: [
    "Missing required section: ## Context",
    "Add '## Context' section explaining the problem and constraints",
  ],
  missing_alternatives: [
    "Missing required section: ## Alternatives Considered",
    "Add '## Alternatives Considered' with at least 1 rejected alternative",
  ],
  missing_decision: [
    "Missing required section: ## Decision",
    "Add '## Decision' section with **Approach:** and **Rationale:**",
  ],
  missing_components: [
    "Missing required section: ## Components",
    "Add '## Components' table: | Action | Path | Purpose |",
  ],
  missing_data_flow: [
    "Missing required section: ## Data Flow",
    "Add '## Data Flow' section describing data movement between components",
  ],
  no_alternatives_listed: [
    "Must list at least 1 alternative",
    "Add alternatives: '1. **[Name]** — rejected: reason why not chosen'",
  ],
  components_empty: [
    "Components table must have at least 1 row",
    "Add component rows: '| CREATE | `path/file.ts` | purpose |'",
  ],
  decision_no_approach: [
    "Decision section missing 'Approach:'",
    "Add '**Approach:** description of chosen solution' to Decision section",
  ],
  decision_no_rationale: [
    "Decision section missing 'Rationale:'",
    "Add '**Rationale:** why this approach was chosen' to Decision section",
  ],
  missing_risk_table: [
    "Missing required risk table headers",
    "Add markdown table with headers: | Risk | Likelihood | Impact | Mitigation |",
  ],
  missing_checklist_items: [
    "Missing checklist items (Definition of Done)",
    "Add at least one checklist item: '- [ ] requirement description'",
  ],
  missing_dod_header: [
    "Missing Definition of Done header",
    "Add section header: '## Definition of Done' or '## Acceptance Criteria'",
  ],
};

function fmtError(key: string, extra = ""): string {
  const hint = ERROR_HINTS[key];
  if (!hint) return `Validation error: ${key}`;
  return `${hint[0]}${extra ? ` (${extra})` : ""}\n   → FIX: ${hint[1]}`;
}

// ─── Secrets Scanner ─────────────────────────────────────────────────────────

function checkSecrets(content: string): string[] {
  const findings: string[] = [];

  const apiKeys = content.match(/sk-[a-zA-Z0-9]{20,}/g);
  if (apiKeys) findings.push(`API key detected: ${apiKeys[0].slice(0, 15)}... (potential leak)`);

  const awsKeys = content.match(/AKIA[A-Z0-9]{16}/g);
  if (awsKeys) findings.push(`AWS access key detected: ${awsKeys[0]} (potential leak)`);

  const passwords = content.match(/password\s*=\s*["']([^"']+)["']/gi);
  if (passwords) findings.push(`Hardcoded password detected (security risk)`);

  const privateKeys = content.match(/-----BEGIN.*PRIVATE KEY-----/g);
  if (privateKeys) findings.push(`Private key detected (critical security risk)`);

  return findings;
}

// ─── File Validators ─────────────────────────────────────────────────────────

function validateTaskMd(content: string): string[] {
  const errors: string[] = [];

  if (!content.includes("Status:")) {
    errors.push(fmtError("missing_status"));
  } else {
    const m = content.match(/Status:\s*(\S+)/);
    if (m && !VALID_TASK_STATUSES.includes(m[1])) {
      errors.push(fmtError("invalid_status", `'${m[1]}' — valid: ${VALID_TASK_STATUSES.join(", ")}`));
    }
  }

  if (!content.includes("Created:")) errors.push(fmtError("missing_created"));
  if (!content.includes("Last-updated:")) errors.push(fmtError("missing_last_updated"));
  if (!content.includes("## Phases")) errors.push(fmtError("missing_phases"));

  return errors;
}

function validateTasksMd(content: string): string[] {
  const errors: string[] = [];
  if (!content.includes("# Tasks") && !content.includes("# Task Breakdown")) {
    errors.push(fmtError("missing_tasks_header"));
  }
  if (!/##\s+task-\d+/i.test(content)) {
    errors.push(fmtError("no_task_definitions"));
  }
  return errors;
}

function validatePlanMd(content: string): string[] {
  const errors: string[] = [];
  if (!content.includes("Status:")) {
    errors.push(fmtError("missing_plan_status"));
  } else {
    const m = content.match(/Status:\s*(\S+)/);
    if (m && !VALID_PLAN_STATUSES.includes(m[1])) {
      errors.push(fmtError("invalid_plan_status", `'${m[1]}'`));
    }
  }
  return errors;
}

function validateResearchPlanMd(content: string): string[] {
  const errors: string[] = [];

  if (!content.includes("Status:")) {
    errors.push(fmtError("missing_research_status"));
  } else {
    const m = content.match(/Status:\s*(\S+)/);
    if (m && !VALID_RESEARCH_STATUSES.includes(m[1])) {
      errors.push(fmtError("invalid_research_status", `'${m[1]}'`));
    }
  }

  const sections: [string, string][] = [
    ["## 2. Research Questions", "missing_research_questions"],
    ["## 4. Concerns Matrix", "missing_concerns_matrix"],
    ["## 7. Gaps Found", "missing_gaps_found"],
  ];
  for (const [section, key] of sections) {
    if (!content.includes(section)) errors.push(fmtError(key));
  }

  // Gap iterations
  const gapMatch = content.match(/\*\*Gap iterations:\*\*\s*(\d+)\/(\d+)/);
  if (gapMatch) {
    const [, current, max] = gapMatch;
    if (parseInt(current) > parseInt(max)) {
      errors.push(fmtError("gap_iterations_exceeded", `${current}/${max}`));
    }
  }

  // Complexity Assessment
  if (!content.includes("## 8. Complexity Assessment")) {
    errors.push(fmtError("missing_complexity_assessment"));
  } else {
    const scoreMatch = content.match(/\*\*Score:\*\*\s*(\S+)/);
    if (!scoreMatch) {
      errors.push(fmtError("missing_complexity_score"));
    } else if (!/^\d+\.?\d*$/.test(scoreMatch[1])) {
      errors.push(fmtError("invalid_complexity_score", `got '${scoreMatch[1]}'`));
    }
  }

  return errors;
}

function validateSummaryMd(content: string): string[] {
  const errors: string[] = [];

  const sections: [string, string][] = [
    ["## Key Findings", "missing_key_findings"],
    ["## Recommendations", "missing_recommendations"],
    ["## Sources", "missing_sources"],
  ];
  for (const [section, key] of sections) {
    if (!content.includes(section)) errors.push(fmtError(key));
  }

  // Check Key Findings has at least one finding
  const findingsMatch = content.match(/## Key Findings\s*([\s\S]*?)(?=\n## |\Z)/);
  if (findingsMatch) {
    const findingsSection = findingsMatch[1].trim();
    if (!/[-*\d.]\s+\*\*/.test(findingsSection)) {
      errors.push(fmtError("no_findings_listed"));
    }
  }

  return errors;
}

function validateArchitectureMd(content: string): string[] {
  const errors: string[] = [];

  const sections: [string, string][] = [
    ["## Context", "missing_context"],
    ["## Alternatives Considered", "missing_alternatives"],
    ["## Decision", "missing_decision"],
    ["## Components", "missing_components"],
    ["## Data Flow", "missing_data_flow"],
  ];
  for (const [section, key] of sections) {
    if (!content.includes(section)) errors.push(fmtError(key));
  }

  // Alternatives section
  const altMatch = content.match(/## Alternatives Considered\s*([\s\S]*?)(?=\n## |$)/);
  if (altMatch) {
    const alts = altMatch[1].match(/\d+\.\s+\*\*\[[^\]]+\]\*\*/g);
    if (!alts || alts.length < 1) {
      errors.push(fmtError("no_alternatives_listed"));
    }
  }

  // Components table
  const compMatch = content.match(/## Components\s*([\s\S]*?)(?=\n## |$)/);
  if (compMatch) {
    if (!/\|\s*(CREATE|MODIFY|DELETE)\s*\|/i.test(compMatch[1])) {
      errors.push(fmtError("components_empty"));
    }
  }

  // Decision section
  const decMatch = content.match(/## Decision\s*([\s\S]*?)(?=\n## |$)/);
  if (decMatch) {
    const dec = decMatch[1];
    if (!dec.includes("**Approach:**") && !dec.includes("Approach:")) {
      errors.push(fmtError("decision_no_approach"));
    }
    if (!dec.includes("**Rationale:**") && !dec.includes("Rationale:")) {
      errors.push(fmtError("decision_no_rationale"));
    }
  }

  return errors;
}

function validateRisksMd(content: string): string[] {
  const errors: string[] = [];
  const lower = content.toLowerCase();
  const required = ["risk", "likelihood", "impact", "mitigation"];
  if (required.some((h) => !lower.includes(h))) {
    errors.push(fmtError("missing_risk_table"));
  }
  return errors;
}

function validateAcceptanceMd(content: string): string[] {
  const errors: string[] = [];
  if (!/- \[[ xX]\]/.test(content)) {
    errors.push(fmtError("missing_checklist_items"));
  }
  const lower = content.toLowerCase();
  if (!["definition of done", "acceptance criteria", "dod"].some((k) => lower.includes(k))) {
    errors.push(fmtError("missing_dod_header"));
  }
  return errors;
}

// ─── Stats Collector ─────────────────────────────────────────────────────────

function extractPathInfo(filePath: string): { taskSlug: string | null; phase: string | null; filename: string | null } {
  const idx = filePath.indexOf(ORCHESTRATE_MARKER);
  if (idx === -1) return { taskSlug: null, phase: null, filename: null };

  const relative = filePath.slice(idx + ORCHESTRATE_MARKER.length);
  const parts = relative.split("/");
  if (parts.length < 2) return { taskSlug: null, phase: null, filename: null };

  const taskSlug = parts[0];
  if (parts.length >= 3 && ["research", "plan", "execution"].includes(parts[1])) {
    return { taskSlug, phase: parts[1], filename: parts[parts.length - 1] };
  }
  return { taskSlug, phase: null, filename: parts[parts.length - 1] };
}

function extractAgentName(content: string, filename: string): string {
  const returnMatch = content.match(/^## Return:\s*(.+)$/m);
  if (returnMatch) return returnMatch[1].trim();
  if (filename.startsWith("_")) return "orchestrator";
  if (filename === "architecture.md") return "architect";
  if (/batch-\d+-review\.md/.test(filename)) return "reviewer";

  const taskMatch = filename.match(/task-\d+-(.+)\.md/);
  if (taskMatch) return taskMatch[1];

  let stem = basename(filename, extname(filename));
  for (const suffix of ["-report", "-review", "-critique"]) {
    if (stem.endsWith(suffix)) return stem.slice(0, -suffix.length);
  }
  return stem;
}

function extractConfidence(content: string): number | null {
  const structured = content.match(/###\s*Confidence\s*\n\s*Score:\s*([\d.]+)/);
  if (structured) {
    const val = parseFloat(structured[1]);
    if (val >= 0 && val <= 1) return val;
  }

  const yaml = content.match(/^confidence:\s*([\d.]+)\s*$/m);
  if (yaml) {
    const val = parseFloat(yaml[1]);
    if (val >= 0 && val <= 1) return val;
  }

  const legacy = content.match(/^confidence:\s*(high|medium|low)\s*$/im);
  if (legacy) {
    const map: Record<string, number> = { high: 0.85, medium: 0.6, low: 0.3 };
    return map[legacy[1].toLowerCase()] ?? null;
  }

  return null;
}

function extractStatus(content: string): string | null {
  const m1 = content.match(/###\s*Status:\s*(SUCCESS|PARTIAL|FAILED|BLOCKED)/);
  if (m1) return m1[1];
  const m2 = content.match(/^status:\s*(SUCCESS|PARTIAL|FAILED)\s*$/m);
  if (m2) return m2[1];
  return null;
}

function collectStats(filePath: string, content: string, sessionId: string): void {
  try {
    const { taskSlug, phase, filename } = extractPathInfo(filePath);
    if (!taskSlug || !filename) return;

    const now = new Date();
    const datePath = `${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, "0")}/${String(now.getUTCDate()).padStart(2, "0")}`;

    const archiveRel = phase
      ? `${datePath}/${taskSlug}/${phase}/${filename}`
      : `${datePath}/${taskSlug}/${filename}`;

    const archivePath = join(FILES_DIR, archiveRel);
    mkdirSync(join(archivePath, ".."), { recursive: true });
    mkdirSync(STATS_DIR, { recursive: true });
    writeFileSync(archivePath, content, "utf-8");

    const fileHash = createHash("sha256").update(content, "utf-8").digest("hex");

    const record = {
      id: randomUUID(),
      timestamp: now.toISOString(),
      session_id: sessionId,
      task_slug: taskSlug,
      phase,
      agent_name: extractAgentName(content, filename),
      file_name: filename,
      file_path: filePath,
      file_size: Buffer.byteLength(content, "utf-8"),
      file_hash: `sha256:${fileHash}`,
      archive_path: archivePath,
      confidence: extractConfidence(content),
      status: extractStatus(content),
    };

    appendFileSync(INDEX_FILE, JSON.stringify(record) + "\n", "utf-8");
  } catch {
    // Never block writes
  }
}

// ─── Session Hooks ───────────────────────────────────────────────────────────

function loadSession(): Record<string, unknown> | null {
  try {
    if (!existsSync(SESSION_FILE)) return null;
    return JSON.parse(readFileSync(SESSION_FILE, "utf-8"));
  } catch {
    return null;
  }
}

function findActiveTasks(cwd: string): Array<{ slug: string; status: string; lastUpdated: string }> {
  const tasks: Array<{ slug: string; status: string; lastUpdated: string }> = [];
  const orchestrateDir = join(cwd, "tmp", ".orchestrate");

  try {
    const taskFiles = globSync("*/task.md", { cwd: orchestrateDir, absolute: true });
    for (const taskFile of taskFiles) {
      try {
        const content = readFileSync(taskFile, "utf-8");
        const slug = basename(join(taskFile, ".."));

        let status = "";
        let lastUpdated = "";
        for (const line of content.split("\n")) {
          if (line.startsWith("Status:")) status = line.split(":").slice(1).join(":").trim();
          else if (line.startsWith("Last-updated:")) lastUpdated = line.split(":").slice(1).join(":").trim();
        }

        if (status) tasks.push({ slug, status, lastUpdated });
      } catch {
        continue;
      }
    }
  } catch {
    // No orchestrate dir
  }

  return tasks;
}

function findActiveTask(cwd: string): Record<string, string> | null {
  const tasks = findActiveTasks(cwd);
  const active = tasks.find((t) => t.status === "executing" || t.status === "planning");
  if (!active) return null;
  return { task_slug: active.slug, phase: active.status, cwd };
}

function saveSession(data: Record<string, string>): void {
  try {
    mkdirSync(SESSION_DIR, { recursive: true });
    const payload = { ...data, timestamp: new Date().toISOString() };
    writeFileSync(SESSION_FILE, JSON.stringify(payload, null, 2), "utf-8");
  } catch {
    // Fail silently
  }
}

// ─── Plugin Export ───────────────────────────────────────────────────────────

export const WorkflowPlugin: Plugin = async ({ $, directory }) => {
  return {
    // ── Validator (PreToolUse equivalent) ──────────────────────────────────
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "write") return;

      const filePath: string = output.args?.filePath || output.args?.file_path || "";
      const content: string = output.args?.content || "";

      if (!filePath.includes(ORCHESTRATE_MARKER)) return;

      // Step 1: Secrets scan
      const secretFindings = checkSecrets(content);
      if (secretFindings.length > 0) {
        throw new Error(
          `BLOCKED: Secrets detected in ${basename(filePath)}\n\n` +
          secretFindings.map((f) => `• ${f}`).join("\n") +
          "\n\nNever write secrets to orchestrate files. Use environment variables instead."
        );
      }

      // Step 2: Structure validation
      const filename = basename(filePath);
      let errors: string[] = [];

      switch (filename) {
        case "task.md": errors = validateTaskMd(content); break;
        case "tasks.md": errors = validateTasksMd(content); break;
        case "plan.md": errors = validatePlanMd(content); break;
        case "_plan.md": errors = validateResearchPlanMd(content); break;
        case "_summary.md": errors = validateSummaryMd(content); break;
        case "architecture.md": errors = validateArchitectureMd(content); break;
        case "risks.md": errors = validateRisksMd(content); break;
        case "acceptance.md": errors = validateAcceptanceMd(content); break;
        default: return; // Unknown file type, allow
      }

      if (errors.length > 0) {
        throw new Error(
          `BLOCKED: Validation failed for ${filename}\n\n` +
          errors.map((e) => `• ${e}`).join("\n") +
          "\n\nFix the errors above and retry. See docs/orchestrate-file-formats.md for correct format."
        );
      }
    },

    // ── Format-on-write + Stats collector (PostToolUse equivalent) ─────────
    "tool.execute.after": async (input) => {
      const tool = input.tool;
      if (tool !== "write" && tool !== "edit") return;

      const filePath: string = input.args?.filePath || input.args?.file_path || "";
      if (!filePath) return;

      // Format-on-write
      const ext = extname(filePath);
      if (!SKIP_EXTENSIONS.has(ext)) {
        const formatters: Record<string, string[]> = {
          ".py": ["ruff", "format", filePath],
          ".js": ["npx", "prettier", "--write", filePath],
          ".ts": ["npx", "prettier", "--write", filePath],
          ".jsx": ["npx", "prettier", "--write", filePath],
          ".tsx": ["npx", "prettier", "--write", filePath],
          ".go": ["gofmt", "-w", filePath],
          ".rs": ["rustfmt", filePath],
        };

        const cmd = formatters[ext];
        if (cmd) {
          try {
            const which = await $`which ${cmd[0]}`.text().catch(() => "");
            if (which.trim()) {
              await $`${cmd.join(" ")}`.quiet().catch(() => {});
            }
          } catch {
            // Never block
          }
        }
      }

      // Stats collector
      if (filePath.includes(ORCHESTRATE_MARKER)) {
        try {
          const content = existsSync(filePath) ? readFileSync(filePath, "utf-8") : (input.args?.content || "");
          collectStats(filePath, content, "");
        } catch {
          // Never block
        }
      }
    },

    // ── Session restore (SessionStart equivalent) ──────────────────────────
    "session.created": async () => {
      const session = loadSession();
      if (!session) return;

      console.log("=== Session Restored ===");
      console.log(`Last task: ${session.task_slug || "unknown"}`);
      console.log(`Phase: ${session.phase || "unknown"}`);
      console.log(`Saved: ${session.timestamp || "unknown"}`);

      const cwd = (session.cwd as string) || directory;
      const tasks = findActiveTasks(cwd);

      if (tasks.length > 0) {
        console.log("\nActive orchestrate tasks:");
        for (const task of tasks) {
          console.log(`  - ${task.slug}: ${task.status} (Last: ${task.lastUpdated || "unknown"})`);
        }
      }
      console.log("========================");
    },

    // ── Session save (SessionEnd equivalent) ───────────────────────────────
    "session.idle": async () => {
      const task = findActiveTask(directory);
      if (task) saveSession(task);
    },
  };
};

export default WorkflowPlugin;
