import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  assertSupportedNode,
  runNodeCheck,
} from "../../scripts/check-node.mjs";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const policy = { minimumMajor: 22, recommendedMajor: 24 };

function removePolicyTemp(directory) {
  const resolved = path.resolve(directory);
  const expectedPrefix = path.join(path.resolve(tmpdir()), "ogb-node-policy-");
  assert.ok(resolved.startsWith(expectedPrefix));
  rmSync(resolved, { force: true, recursive: true });
}

test("supported and future Node releases satisfy the minimum policy", () => {
  for (const major of [22, 24, 26, 99]) {
    assert.doesNotThrow(() =>
      assertSupportedNode({
        executable: `/node-${major}`,
        policy,
        version: `v${major}.1.0`,
      }),
    );
  }
});

test("old, missing, and malformed runtime versions fail concisely", () => {
  for (const version of ["v21.9.0", "", "not-a-version"]) {
    assert.throws(
      () =>
        assertSupportedNode({
          executable: "C:/tools/node.exe",
          policy,
          version,
        }),
      (error) => {
        assert.match(error.message, /Node\.js .*C:\/tools\/node\.exe/);
        assert.match(error.message, /need Node\.js 22\+ \(24 recommended\)/);
        assert.match(error.message, /restart the terminal and editor/);
        assert.doesNotMatch(error.message, /\n\s+at /);
        return true;
      },
    );
  }
});

test("the repository policy comes from package.json and .node-version", () => {
  const packageJson = JSON.parse(
    readFileSync(path.join(root, "package.json"), "utf8"),
  );
  const lockJson = JSON.parse(
    readFileSync(path.join(root, "package-lock.json"), "utf8"),
  );
  assert.equal(packageJson.engines.node, ">=22");
  assert.equal(lockJson.packages[""].engines.node, packageJson.engines.node);
  assert.equal(
    readFileSync(path.join(root, ".node-version"), "utf8").trim(),
    "24",
  );

  const result = assertSupportedNode({ version: "v26.0.0" });
  assert.equal(result.minimumMajor, 22);
  assert.equal(result.recommendedMajor, 24);
});

test("the CLI boundary reports malformed policy without a stack", () => {
  const directory = mkdtempSync(path.join(tmpdir(), "ogb-node-policy-"));
  try {
    writeFileSync(
      path.join(directory, "package.json"),
      JSON.stringify({ engines: { node: "22.x" } }),
    );
    writeFileSync(path.join(directory, ".node-version"), "24\n");

    const messages = [];
    const status = runNodeCheck(
      {
        packagePath: path.join(directory, "package.json"),
        recommendationPath: path.join(directory, ".node-version"),
      },
      { error: (message) => messages.push(message), log: () => assert.fail() },
    );
    assert.equal(status, 1);
    assert.equal(messages.length, 1);
    assert.match(messages[0], /engines\.node must use the simple >=N form/);
    assert.doesNotMatch(messages[0], /\n\s+at |Error:/);
  } finally {
    removePolicyTemp(directory);
  }
});

test("doctor and setup keep Node validation ahead of content dependencies", () => {
  const quick = spawnSync(
    "pwsh",
    ["-NoProfile", "-File", "scripts/doctor.ps1", "-Scope", "quick"],
    { cwd: root, encoding: "utf8" },
  );
  assert.equal(quick.status, 0, quick.stdout + quick.stderr);
  assert.doesNotMatch(
    quick.stdout,
    /Node\.js|npm|content-tool|Playwright/,
    "quick doctor must remain .NET-only",
  );

  const browser = spawnSync(
    "pwsh",
    ["-NoProfile", "-File", "scripts/doctor.ps1", "-Scope", "browser"],
    { cwd: root, encoding: "utf8" },
  );
  assert.equal(browser.status, 0, browser.stdout + browser.stderr);
  assert.match(
    browser.stdout,
    /Node\.js v\d+.*satisfies >=22 \(24 recommended\)/,
  );
  assert.match(browser.stdout, /Playwright manifest pin/);

  const setup = readFileSync(
    path.join(root, "scripts/setup-content.ps1"),
    "utf8",
  );
  const ordered = [
    "scripts/check-node.mjs",
    "npm' 'Install npm",
    "ci', '--ignore-scripts",
    "scripts/install-content-tools.ps1",
    "scripts/check-content.mjs', 'all",
  ].map((text) => setup.indexOf(text));
  assert.ok(ordered.every((index) => index >= 0));
  assert.deepEqual(
    ordered,
    ordered.toSorted((left, right) => left - right),
  );
  assert.doesNotMatch(setup, /winget|choco|scoop|husky|credential/i);
});
