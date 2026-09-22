import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import parseYaml from "markdownlint-cli2/parsers/yaml";

import {
  changedPathsForPullRequest,
  validateGate,
  validateSha,
  isDocumentationPath,
  selectModeForPaths,
} from "../../scripts/ci-policy.mjs";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const policyScript = path.join(root, "scripts/ci-policy.mjs");

test("documentation selection uses the conservative Markdown allowlist", () => {
  for (const file of [
    "README.md",
    "SECURITY.md",
    "docs/setup/development.md",
    "docs/nested/deeper/topic.md",
  ]) {
    assert.equal(isDocumentationPath(file), true, file);
  }

  for (const file of [
    ".github/pull_request_template.md",
    ".github/workflows/ci.yml",
    "docs/config.json",
    "docs/README.MD",
    "src/README.md",
    "README",
    "tool.unknown",
  ]) {
    assert.equal(isDocumentationPath(file), false, file);
  }

  assert.equal(selectModeForPaths(["README.md", "docs/topic.md"]), "docs");
  assert.equal(selectModeForPaths([]), "full");
  assert.equal(selectModeForPaths(["README.md", "src/app.cs"]), "full");
});

function run(command, arguments_, options = {}) {
  const result = spawnSync(command, arguments_, {
    encoding: "utf8",
    shell: false,
    ...options,
  });
  if (result.error) throw result.error;
  return result;
}

function git(directory, ...arguments_) {
  const result = run("git", arguments_, { cwd: directory });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result.stdout.trim();
}

function write(directory, name, content = `${name}\n`) {
  const file = path.join(directory, name);
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, content);
}

function filesUnder(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(file) : [file];
  });
}

function findSetupNodeSteps(value, result = []) {
  if (Array.isArray(value)) {
    for (const item of value) findSetupNodeSteps(item, result);
  } else if (value && typeof value === "object") {
    if (value.uses?.startsWith("actions/setup-node@")) result.push(value);
    for (const item of Object.values(value)) findSetupNodeSteps(item, result);
  }
  return result;
}

function withGitRange(baseFiles, change, assertion) {
  const directory = mkdtempSync(path.join(tmpdir(), "ogb-ci-policy-"));
  try {
    git(directory, "init", "--initial-branch=main");
    git(directory, "config", "user.name", "CI Policy Test");
    git(directory, "config", "user.email", "ci-policy@example.invalid");
    for (const file of baseFiles) write(directory, file);
    git(directory, "add", "--all");
    git(directory, "commit", "-m", "base");
    const base = git(directory, "rev-parse", "HEAD");
    change(directory);
    git(directory, "add", "--all");
    git(directory, "commit", "-m", "head");
    const head = git(directory, "rev-parse", "HEAD");
    assertion({ base, directory, head });
  } finally {
    rmSync(directory, { force: true, recursive: true });
  }
}

test("PR selection reads the complete Git range and keeps both rename paths", () => {
  withGitRange(
    ["README.md", "docs/delete.md", "docs/rename-old.md"],
    (directory) => {
      write(directory, "docs/added.md");
      unlinkSync(path.join(directory, "docs/delete.md"));
      renameSync(
        path.join(directory, "docs/rename-old.md"),
        path.join(directory, "docs/rename-new.md"),
      );
    },
    ({ base, directory, head }) => {
      const paths = changedPathsForPullRequest(base, head, directory);
      assert.deepEqual(paths.toSorted(), [
        "docs/added.md",
        "docs/delete.md",
        "docs/rename-new.md",
        "docs/rename-old.md",
      ]);
      assert.equal(selectModeForPaths(paths), "docs");
    },
  );
});

test("PR selection fails closed for application and unknown-extension changes", () => {
  for (const file of ["src/App.cs", "docs/generated.unknown"]) {
    withGitRange(
      ["README.md"],
      (directory) => write(directory, file),
      ({ base, directory, head }) => {
        assert.equal(
          selectModeForPaths(changedPathsForPullRequest(base, head, directory)),
          "full",
          file,
        );
      },
    );
  }

  withGitRange(
    ["src/Delete.cs"],
    (directory) => {
      unlinkSync(path.join(directory, "src/Delete.cs"));
    },
    ({ base, directory, head }) => {
      assert.equal(
        selectModeForPaths(changedPathsForPullRequest(base, head, directory)),
        "full",
      );
    },
  );
});

test("an empty PR range selects full validation", () => {
  withGitRange(
    ["README.md"],
    (directory) => write(directory, "README.md", "changed\n"),
    ({ base, directory }) => {
      assert.deepEqual(changedPathsForPullRequest(base, base, directory), []);
      assert.equal(
        selectModeForPaths(changedPathsForPullRequest(base, base, directory)),
        "full",
      );
    },
  );
});

test("SHA validation rejects ambiguous revisions before Git runs", () => {
  for (const invalid of [
    undefined,
    "",
    "HEAD",
    "abc123",
    "a".repeat(39),
    "a".repeat(41),
    `${"a".repeat(39)}g`,
    `--output=${"a".repeat(40)}`,
  ]) {
    assert.throws(() => validateSha(invalid, "base"), /base SHA/);
  }
  assert.equal(validateSha("A".repeat(40), "head"), "A".repeat(40));
  assert.equal(validateSha("b".repeat(64), "head"), "b".repeat(64));
});

function runPolicy(command, environment, cwd = root) {
  return run(process.execPath, [policyScript, command], {
    cwd,
    env: { ...process.env, ...environment },
  });
}

test("select CLI writes docs mode and logs every changed path", () =>
  withGitRange(
    ["README.md"],
    (directory) => {
      write(directory, "docs/added.md");
    },
    ({ base, directory, head }) => {
      const output = path.join(directory, "github-output.txt");
      const result = runPolicy(
        "select",
        {
          CI_BASE_SHA: base,
          CI_EVENT_NAME: "pull_request",
          CI_HEAD_SHA: head,
          GITHUB_OUTPUT: output,
        },
        directory,
      );
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.equal(readFileSync(output, "utf8"), "mode=docs\n");
      assert.match(result.stdout, /Selected CI mode: docs/);
      assert.match(result.stdout, /"docs\/added\.md"/);
    },
  ));

test("non-PR events select full without requiring SHAs", () => {
  for (const event of ["push", "workflow_dispatch"]) {
    const directory = mkdtempSync(path.join(tmpdir(), "ogb-ci-output-"));
    try {
      const output = path.join(directory, "github-output.txt");
      const result = runPolicy("select", {
        CI_BASE_SHA: "",
        CI_EVENT_NAME: event,
        CI_HEAD_SHA: "",
        GITHUB_OUTPUT: output,
      });
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.equal(readFileSync(output, "utf8"), "mode=full\n");
      assert.match(result.stdout, /Changed paths: not evaluated/);
    } finally {
      rmSync(directory, { force: true, recursive: true });
    }
  }
});

test("Git comparison failures cannot emit docs mode", () => {
  const directory = mkdtempSync(path.join(tmpdir(), "ogb-ci-failure-"));
  try {
    git(directory, "init", "--initial-branch=main");
    const output = path.join(directory, "github-output.txt");
    const result = runPolicy(
      "select",
      {
        CI_BASE_SHA: "a".repeat(40),
        CI_EVENT_NAME: "pull_request",
        CI_HEAD_SHA: "b".repeat(40),
        GITHUB_OUTPUT: output,
      },
      directory,
    );
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /git diff failed/);
    assert.throws(() => readFileSync(output, "utf8"));
  } finally {
    rmSync(directory, { force: true, recursive: true });
  }
});

function expectedNeeds(mode) {
  return {
    "select-checks": { result: "success" },
    documentation: { result: mode === "docs" ? "success" : "skipped" },
    linux: { result: mode === "full" ? "success" : "skipped" },
    windows: { result: mode === "full" ? "success" : "skipped" },
  };
}

test("aggregate gate accepts exactly the successful selected lane", () => {
  assert.doesNotThrow(() => validateGate("docs", expectedNeeds("docs")));
  assert.doesNotThrow(() => validateGate("full", expectedNeeds("full")));
});

test("aggregate gate names every failed, cancelled, skipped, or active wrong lane", () => {
  for (const mode of ["docs", "full"]) {
    const expected = expectedNeeds(mode);
    for (const [job, definition] of Object.entries(expected)) {
      for (const result of ["success", "failure", "cancelled", "skipped"]) {
        if (result === definition.result) continue;
        const needs = structuredClone(expected);
        needs[job].result = result;
        assert.throws(
          () => validateGate(mode, needs),
          new RegExp(`${job}.*expected ${definition.result}.*${result}`),
          `${mode}: ${job}=${result}`,
        );
      }
    }
  }
});

test("aggregate gate rejects malformed modes, jobs, and results", () => {
  for (const mode of [undefined, "", "content", "DOCS", 1]) {
    assert.throws(() => validateGate(mode, expectedNeeds("docs")), /CI_MODE/);
  }
  for (const needs of [undefined, null, [], "{}", 1]) {
    assert.throws(() => validateGate("docs", needs), /CI_NEEDS/);
  }
  for (const job of ["select-checks", "documentation", "linux", "windows"]) {
    const needs = expectedNeeds("docs");
    delete needs[job];
    assert.throws(() => validateGate("docs", needs), new RegExp(job));
  }
  const unexpected = expectedNeeds("docs");
  unexpected.packaging = { result: "skipped" };
  assert.throws(() => validateGate("docs", unexpected), /packaging/);

  for (const result of [undefined, null, "", "unknown", 1]) {
    const needs = expectedNeeds("full");
    needs.linux.result = result;
    assert.throws(() => validateGate("full", needs), /linux.*result/);
  }
});

test("gate CLI reports malformed JSON and names a cancelled requirement", () => {
  const malformed = runPolicy("gate", {
    CI_MODE: "docs",
    CI_NEEDS: "{not JSON",
  });
  assert.notEqual(malformed.status, 0);
  assert.match(malformed.stderr, /CI_NEEDS is not valid JSON/);

  const needs = expectedNeeds("full");
  needs.windows.result = "cancelled";
  const cancelled = runPolicy("gate", {
    CI_MODE: "full",
    CI_NEEDS: JSON.stringify(needs),
  });
  assert.notEqual(cancelled.status, 0);
  assert.match(cancelled.stderr, /windows.*cancelled/);

  const passed = runPolicy("gate", {
    CI_MODE: "docs",
    CI_NEEDS: JSON.stringify(expectedNeeds("docs")),
  });
  assert.equal(passed.status, 0, passed.stdout + passed.stderr);
  assert.match(passed.stdout, /Aggregate CI gate passed for docs mode/);
});

test("CI workflow keeps selection, lanes, and aggregate gate wired to the policy", () => {
  const workflow = parseYaml(
    readFileSync(path.join(root, ".github/workflows/ci.yml"), "utf8"),
  );
  assert.equal(workflow.on.pull_request, null);
  assert.equal("paths" in workflow.on.push, false);
  assert.equal("paths-ignore" in workflow.on.push, false);

  const jobs = workflow.jobs;
  const selection = jobs["select-checks"];
  const checkout = selection.steps.find((step) =>
    step.uses?.startsWith("actions/checkout@"),
  );
  assert.equal(checkout.with["fetch-depth"], 0);
  const select = selection.steps.find(
    (step) => step.run === "node scripts/ci-policy.mjs select",
  );
  assert.equal(select.env.CI_EVENT_NAME, "${{ github.event_name }}");
  assert.equal(
    select.env.CI_BASE_SHA,
    "${{ github.event.pull_request.base.sha }}",
  );
  assert.equal(
    select.env.CI_HEAD_SHA,
    "${{ github.event.pull_request.head.sha }}",
  );

  assert.equal(
    jobs.documentation.if,
    "${{ needs.select-checks.outputs.mode == 'docs' }}",
  );
  assert.equal(jobs.documentation.needs, "select-checks");
  assert.equal(
    jobs.documentation.steps.find(
      (step) => step.uses === "./.github/actions/validate",
    ).with.mode,
    "content",
  );
  for (const job of ["linux", "windows"]) {
    assert.equal(
      jobs[job].if,
      "${{ needs.select-checks.outputs.mode == 'full' }}",
    );
    assert.equal(jobs[job].needs, "select-checks");
  }
  assert.equal(
    jobs.windows.steps.find(
      (step) => step.uses === "./.github/actions/validate",
    ).with.mode,
    "quick",
  );
  assert.equal(
    jobs.linux.steps.find((step) => step.uses === "./.github/actions/validate")
      .with.mode ?? "full",
    "full",
  );

  const gate = jobs["build-test"];
  assert.deepEqual(gate.needs, [
    "select-checks",
    "documentation",
    "linux",
    "windows",
  ]);
  assert.equal(gate.if, "${{ always() }}");
  const gateStep = gate.steps.find(
    (step) => step.run === "node scripts/ci-policy.mjs gate",
  );
  assert.equal(gateStep.env.CI_MODE, "${{ needs.select-checks.outputs.mode }}");
  assert.equal(gateStep.env.CI_NEEDS, "${{ toJSON(needs) }}");

  const action = parseYaml(
    readFileSync(
      path.join(root, ".github/actions/validate/action.yml"),
      "utf8",
    ),
  );
  const dotnet = action.runs.steps.find((step) =>
    step.uses?.startsWith("actions/setup-dotnet@"),
  );
  assert.equal(dotnet.env.DOTNET_INSTALL_DIR, "${{ runner.temp }}/ogb-dotnet");
  assert.equal(action.inputs.mode.default, "full");
});

test("published browser failures block the Linux lane and retain diagnostics", () => {
  const workflow = parseYaml(
    readFileSync(path.join(root, ".github/workflows/ci.yml"), "utf8"),
  );
  const lane = workflow.jobs.linux;
  const steps = lane.steps;
  const validation = steps.findIndex(
    (step) => step.uses === "./.github/actions/validate",
  );
  const publish = steps.findIndex((step) =>
    step.run?.includes("artifacts/browser-api"),
  );
  const install = steps.findIndex((step) =>
    step.run?.includes("install --with-deps chromium firefox webkit"),
  );
  const browser = steps.findIndex((step) =>
    step.run?.includes("npm run test:pr --prefix tests/deploy-smoke"),
  );
  assert.ok(
    validation >= 0 &&
      publish > validation &&
      install > publish &&
      browser > install,
  );
  assert.notEqual(lane["continue-on-error"], true);
  for (const index of [publish, install, browser]) {
    assert.equal(
      steps[index].if,
      undefined,
      "browser prerequisites and tests cannot be conditional",
    );
    assert.equal(steps[index]["continue-on-error"], undefined);
    assert.equal(
      steps[index].shell,
      "bash",
      "explicit Bash enables pipefail for retained logs",
    );
  }
  const upload = steps
    .slice(browser + 1)
    .find(
      (step) =>
        step.uses?.startsWith("actions/upload-artifact@") &&
        step.with.path.includes("artifacts/browser/"),
    );
  assert.ok(upload);
  assert.equal(upload.if, "${{ always() && !cancelled() }}");
  assert.equal(upload.with["retention-days"], 7);
  assert.ok(workflow.jobs["build-test"].needs.includes("linux"));
  assert.deepEqual(workflow.permissions, { contents: "read" });
  assert.equal(lane.permissions, undefined);
  assert.equal(lane.environment, undefined);
});

test("rendered documentation blocks both selected lanes and retains evidence", () => {
  const workflow = parseYaml(
    readFileSync(path.join(root, ".github/workflows/ci.yml"), "utf8"),
  );
  for (const job of ["documentation", "linux"]) {
    const lane = workflow.jobs[job];
    const validation = lane.steps.findIndex(
      (step) => step.uses === "./.github/actions/validate",
    );
    const docs = lane.steps.findIndex(
      (step) => step.uses === "./.github/actions/docs",
    );
    assert.ok(validation >= 0 && docs > validation, job);
    assert.equal(lane.steps[docs]["continue-on-error"], undefined, job);
  }
  const docsLane = workflow.jobs.documentation.steps.find(
    (step) => step.uses === "./.github/actions/docs",
  );
  assert.equal(docsLane.with, undefined);
  const linuxLane = workflow.jobs.linux.steps.find(
    (step) => step.uses === "./.github/actions/docs",
  );
  assert.equal(linuxLane.with["install-dotnet"], "false");

  const action = parseYaml(
    readFileSync(path.join(root, ".github/actions/docs/action.yml"), "utf8"),
  );
  assert.equal(action.inputs["install-dotnet"].default, "true");
  const dotnet = action.runs.steps.find((step) =>
    step.uses?.startsWith("actions/setup-dotnet@"),
  );
  assert.equal(dotnet.if, "${{ inputs.install-dotnet == 'true' }}");
  assert.equal(dotnet.env.DOTNET_INSTALL_DIR, "${{ runner.temp }}/ogb-dotnet");
  assert.equal(dotnet.with["global-json-file"], "global.json");
  const node = action.runs.steps.find((step) =>
    step.uses?.startsWith("actions/setup-node@"),
  );
  assert.equal(node.with["node-version-file"], ".node-version");
  assert.equal(
    action.runs.steps.some(
      (step) =>
        step.run?.includes("npm ci") ||
        step.run?.includes("install-content-tools.ps1"),
    ),
    false,
  );
  const check = action.runs.steps.find(
    (step) => step.run === "./scripts/check-docs.ps1",
  );
  assert.equal(check.shell, "pwsh");
  assert.equal(check["continue-on-error"], undefined);
  const upload = action.runs.steps.find((step) =>
    step.uses?.startsWith("actions/upload-artifact@"),
  );
  assert.equal(upload.if, "${{ always() && !cancelled() }}");
  assert.match(upload.with.path, /artifacts\/docs\/site\//);
  assert.match(upload.with.path, /artifacts\/docs\/\*\.log/);
  assert.equal(upload.with["retention-days"], 7);
  assert.deepEqual(workflow.jobs["build-test"].needs, [
    "select-checks",
    "documentation",
    "linux",
    "windows",
  ]);
});

test("setup-node references use the repository Node baseline", () => {
  assert.equal(
    readFileSync(path.join(root, ".node-version"), "utf8").trim(),
    "24",
  );

  const yamlFiles = [
    ...filesUnder(path.join(root, ".github/actions")),
    ...filesUnder(path.join(root, ".github/workflows")),
  ].filter((file) => /\.ya?ml$/u.test(file));
  const references = yamlFiles.flatMap((file) =>
    findSetupNodeSteps(parseYaml(readFileSync(file, "utf8"))).map((step) => ({
      file,
      step,
    })),
  );

  assert.ok(references.length > 0);
  for (const { file, step } of references) {
    const relative = path.relative(root, file).replaceAll(path.sep, "/");
    const expected =
      relative === ".github/actions/validate/action.yml"
        ? "${{ inputs.working-directory }}/.node-version"
        : ".node-version";
    assert.equal(step.with?.["node-version-file"], expected, relative);
    assert.equal(step.with?.["node-version"], undefined, relative);
  }
});
