import { spawnSync } from "node:child_process";
import { appendFileSync } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

export function isDocumentationPath(file) {
  if (typeof file !== "string" || file.length === 0) return false;
  return /^[^/\\]+\.md$/.test(file) || /^docs\/.+\.md$/.test(file);
}

export function selectModeForPaths(paths) {
  if (!Array.isArray(paths)) throw new Error("Changed paths must be an array.");
  return paths.length > 0 && paths.every(isDocumentationPath) ? "docs" : "full";
}

export function validateSha(value, name) {
  if (
    typeof value !== "string" ||
    !(/^[0-9a-f]{40}$/i.test(value) || /^[0-9a-f]{64}$/i.test(value))
  ) {
    throw new Error(
      `${name} SHA must be a complete 40- or 64-digit hexadecimal object ID.`,
    );
  }
  return value;
}

export function changedPathsForPullRequest(
  baseSha,
  headSha,
  cwd = process.cwd(),
) {
  const base = validateSha(baseSha, "base");
  const head = validateSha(headSha, "head");
  const result = spawnSync(
    "git",
    ["diff", "--name-only", "-z", "--no-renames", `${base}...${head}`, "--"],
    { cwd, encoding: "buffer", shell: false },
  );
  if (result.error) throw new Error(`git diff failed: ${result.error.message}`);
  if (result.status !== 0) {
    const diagnostic = result.stderr.toString("utf8").trim();
    throw new Error(`git diff failed (exit ${result.status}): ${diagnostic}`);
  }
  return result.stdout.toString("utf8").split("\0").filter(Boolean);
}

const jobIds = ["select-checks", "documentation", "linux", "windows"];
const resultValues = new Set(["success", "failure", "cancelled", "skipped"]);

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function validateGate(mode, needs) {
  if (mode !== "docs" && mode !== "full") {
    throw new Error(
      `CI_MODE must be docs or full; received ${JSON.stringify(mode)}.`,
    );
  }
  if (!isObject(needs)) throw new Error("CI_NEEDS must be a JSON object.");

  for (const job of jobIds) {
    if (!Object.hasOwn(needs, job))
      throw new Error(`CI_NEEDS is missing job ${job}.`);
    if (!isObject(needs[job]))
      throw new Error(`CI_NEEDS job ${job} must be an object.`);
    if (!resultValues.has(needs[job].result)) {
      throw new Error(
        `CI_NEEDS job ${job} has invalid result ${JSON.stringify(needs[job].result)}.`,
      );
    }
  }
  const unexpected = Object.keys(needs).filter((job) => !jobIds.includes(job));
  if (unexpected.length) {
    throw new Error(
      `CI_NEEDS contains unexpected job(s): ${unexpected.join(", ")}.`,
    );
  }

  const expected = {
    "select-checks": "success",
    documentation: mode === "docs" ? "success" : "skipped",
    linux: mode === "full" ? "success" : "skipped",
    windows: mode === "full" ? "success" : "skipped",
  };
  for (const job of jobIds) {
    if (needs[job].result !== expected[job]) {
      throw new Error(
        `CI job ${job} expected ${expected[job]} in ${mode} mode, received ${needs[job].result}.`,
      );
    }
  }
}

function requireOutputPath(environment) {
  if (!environment.GITHUB_OUTPUT) throw new Error("GITHUB_OUTPUT is required.");
  return environment.GITHUB_OUTPUT;
}

function select(environment) {
  const event = environment.CI_EVENT_NAME;
  let paths = [];
  let mode = "full";
  if (event === "pull_request") {
    paths = changedPathsForPullRequest(
      environment.CI_BASE_SHA,
      environment.CI_HEAD_SHA,
    );
    mode = selectModeForPaths(paths);
  }
  console.log(`Selected CI mode: ${mode} (event: ${event || "missing"})`);
  if (event === "pull_request") {
    console.log(`Changed paths (${paths.length}):`);
    for (const file of paths) console.log(`  ${JSON.stringify(file)}`);
    if (paths.length === 0) console.log("  <none>");
  } else {
    console.log("Changed paths: not evaluated for non-PR events");
  }
  appendFileSync(requireOutputPath(environment), `mode=${mode}\n`);
}

function gate(environment) {
  let needs;
  try {
    needs = JSON.parse(environment.CI_NEEDS);
  } catch (error) {
    throw new Error(`CI_NEEDS is not valid JSON: ${error.message}`);
  }
  validateGate(environment.CI_MODE, needs);
  console.log(`Aggregate CI gate passed for ${environment.CI_MODE} mode.`);
}

function main() {
  const command = process.argv[2];
  if (command === "select") select(process.env);
  else if (command === "gate") gate(process.env);
  else throw new Error("Usage: node scripts/ci-policy.mjs select|gate");
}

const invokedPath = process.argv[1]
  ? pathToFileURL(path.resolve(process.argv[1])).href
  : undefined;
if (invokedPath === import.meta.url) {
  try {
    main();
  } catch (error) {
    console.error(`CI policy failed: ${error.message}`);
    process.exitCode = 1;
  }
}
