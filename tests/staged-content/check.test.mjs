import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { checkStaged } from "../../scripts/check-staged.mjs";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

function git(directory, ...args) {
  return execFileSync("git", args, {
    cwd: directory,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
}

async function fixture(action) {
  const directory = mkdtempSync(path.join(os.tmpdir(), "ogb-staged-"));
  const write = (file, content) => {
    const target = path.join(directory, file);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, content);
  };
  try {
    git(directory, "init", "-q");
    git(directory, "config", "core.autocrlf", "false");
    git(directory, "config", "user.name", "Staged check test");
    git(directory, "config", "user.email", "staged@example.invalid");
    for (const file of [".prettierrc.json", ".prettierignore"])
      copyFileSync(path.join(root, file), path.join(directory, file));
    await action(directory, write);
  } finally {
    const target = path.resolve(directory);
    if (
      !target.startsWith(path.resolve(os.tmpdir()) + path.sep + "ogb-staged-")
    )
      throw new Error("Unexpected fixture cleanup path");
    rmSync(target, { recursive: true, force: true });
  }
}

test("staged content passes despite unrelated and partially unstaged formatting errors", () =>
  fixture(async (directory, write) => {
    write("chosen file.json", '{ "ready": true }\n');
    git(directory, "add", "chosen file.json");
    write("chosen file.json", '{"ready":false}\n');
    write("unrelated.json", '{"unrelated":true}\n');
    const index = git(directory, "diff", "--cached", "--binary");
    const result = await checkStaged(directory);
    assert.deepEqual(result, { checked: 1, failures: [] });
    assert.equal(git(directory, "diff", "--cached", "--binary"), index);
    assert.equal(
      readFileSync(path.join(directory, "chosen file.json"), "utf8"),
      '{"ready":false}\n',
    );
  }));

test("unstaged repairs cannot hide badly formatted content in the index", () =>
  fixture(async (directory, write) => {
    write("chosen.json", '{"ready":true}\n');
    git(directory, "add", "chosen.json");
    write("chosen.json", '{ "ready": true }\n');
    assert.deepEqual(await checkStaged(directory), {
      checked: 1,
      failures: ["chosen.json"],
    });
    assert.equal(git(directory, "show", ":chosen.json"), '{"ready":true}\n');
  }));

test("deleted files, vendor assets, lockfiles and C# are left to their owning checks", () =>
  fixture(async (directory, write) => {
    write("deleted.md", "# Delete me\n");
    git(directory, "add", "deleted.md");
    git(directory, "commit", "-qm", "fixture base");
    git(directory, "rm", "deleted.md");
    for (const file of [
      ".agents/skills/example/SKILL.md",
      "package-lock.json",
      "Example.cs",
    ]) {
      write(file, "not formatted\n");
      git(directory, "add", file);
    }
    assert.deepEqual(await checkStaged(directory), {
      checked: 0,
      failures: [],
    });
  }));

test("a renamed file is checked at its new path even when absent from the working tree", () =>
  fixture(async (directory, write) => {
    write("old.json", '{"ready":true}\n');
    git(directory, "add", "old.json");
    git(directory, "commit", "-qm", "fixture base");
    git(directory, "mv", "old.json", "new name.json");
    // A worktree deletion is uncommitted; the staged blob must still be checked.
    rmSync(path.join(directory, "new name.json"));
    assert.deepEqual(await checkStaged(directory), {
      checked: 1,
      failures: ["new name.json"],
    });
  }));

test("CLI reports one actionable formatting failure without a stack or file mutations", () =>
  fixture(async (directory, write) => {
    write("bad.json", '{"a":1}\n');
    git(directory, "add", "bad.json");
    const result = spawnSync(
      process.execPath,
      [path.join(root, "scripts/check-staged.mjs")],
      { cwd: directory, encoding: "utf8" },
    );
    assert.equal(result.status, 1);
    assert.match(
      result.stderr,
      /Staged formatting needs attention:\s+bad.json/,
    );
    assert.match(result.stderr, /stage the intended hunks again/);
    assert.doesNotMatch(result.stderr, /\n\s+at |Exception:/);
    assert.equal(
      readFileSync(path.join(directory, "bad.json"), "utf8"),
      '{"a":1}\n',
    );
  }));

test("missing npm tools give a setup command rather than a module-loading stack", () =>
  fixture(async (directory, write) => {
    mkdirSync(path.join(directory, "scripts"), { recursive: true });
    for (const file of [
      "package.json",
      ".node-version",
      "scripts/check-node.mjs",
      "scripts/check-staged.mjs",
    ])
      copyFileSync(path.join(root, file), path.join(directory, file));
    write("example.md", "# Ready\n");
    git(directory, "add", "example.md");
    const result = spawnSync(
      process.execPath,
      [path.join(directory, "scripts/check-staged.mjs")],
      { cwd: directory, encoding: "utf8" },
    );
    assert.equal(result.status, 1);
    assert.match(result.stderr, /npm ci --ignore-scripts/);
    assert.doesNotMatch(
      result.stderr,
      /ERR_MODULE_NOT_FOUND|\n\s+at |Exception:/,
    );
  }));
