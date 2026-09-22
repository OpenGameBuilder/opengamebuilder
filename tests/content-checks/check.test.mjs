import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { getFileInfo } from "prettier";
import { checkDeploymentCachePolicy } from "../../scripts/workflow-cache-policy.mjs";

test("Prettier respects formatter ownership and generated/vendor boundaries", async () => {
  const ignored = [
    "scripts/apply-edge.sh",
    "scripts/check.ps1",
    "src/OpenGameBuilder.Web.Client/wwwroot/index.html",
    "src/OpenGameBuilder.Api/OpenGameBuilder.Api.csproj",
    ".agents/skills/aspire/SKILL.md",
    "src/OpenGameBuilder.Api/packages.lock.json",
    "node_modules/prettier/README.md",
  ];
  const included = [
    "README.md",
    ".github/workflows/ci.yml",
    "scripts/check-content.mjs",
    "src/OpenGameBuilder.Web.Client/wwwroot/css/app.css",
  ];
  for (const file of [...ignored, ...included]) {
    const info = await getFileInfo(path.join(root, file), {
      ignorePath: path.join(root, ".prettierignore"),
    });
    assert.equal(info.ignored, ignored.includes(file), file);
  }
});

test("deployment cache exception still rejects missing, writable, and overridden cache modes", () => {
  for (const file of ["_deploy", "cd-production", "cd-staging", "docs-pages"]) {
    const name = `.github/workflows/${file}.yml`;
    for (const mode of [undefined, "full", "read-only", true, "None"]) {
      assert.throws(
        () => checkDeploymentCachePolicy(name, { "cache-mode": mode }),
        /requires root cache-mode: none/,
      );
    }
    assert.throws(
      () =>
        checkDeploymentCachePolicy(name, {
          "cache-mode": "none",
          jobs: { build: { "cache-mode": "full" } },
        }),
      /must not override/,
    );
    checkDeploymentCachePolicy(name, {
      "cache-mode": "none",
      jobs: { build: {} },
    });
  }
});

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

// Each fixture is an ordinary, untracked first-party input. The runner must see
// new work before staging; keep these outside its generated-output exclusions.
function fixture(action) {
  const directory = mkdtempSync(path.join(root, ".content-fixture-"));
  const write = (name, content) => {
    const file = path.join(directory, name);
    writeFileSync(file, content);
    return file;
  };
  try {
    action(write);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function check(mode, files, expected, diagnostic, fix = false) {
  const result = spawnSync(
    process.execPath,
    [
      path.join(root, "scripts/check-content.mjs"),
      mode,
      ...(fix ? ["--fix"] : []),
      "--files",
      ...files,
    ],
    { cwd: root, encoding: "utf8" },
  );
  if (result.error) throw result.error;
  const output = result.stdout + result.stderr;
  assert.equal(result.status, expected, output);
  if (diagnostic) assert.match(output, diagnostic);
}

test("formatting failure has a fix that passes the same check", () =>
  fixture((write) => {
    const file = write("style.json", '{"hello":1}\n');
    check("prettier", [file], 1, /Code style issues/);
    check("prettier", [file], 0, undefined, true);
    check("prettier", [file], 0);
    assert.equal(readFileSync(file, "utf8"), '{ "hello": 1 }\n');
  }));

test("Markdown structure rejects a skipped heading level", () =>
  fixture((write) => {
    const bad = write("structure.md", "# Title\n\n### Skipped level\n");
    check("markdown", [bad], 1, /MD001/);
    const good = write("structure.md", "# Title\n\n## Next level\n");
    check("markdown", [good], 0);
  }));

test("offline links check files, images, anchors and valid cross-document links", () =>
  fixture((write) => {
    write("target.md", "# Target\n\n## Useful heading\n");
    const good = write(
      "links.md",
      "# Links\n\n[Target](target.md#useful-heading)\n\n[Remote ignored](https://unreachable.invalid/)\n",
    );
    check("links", [good], 0);
    for (const link of [
      "[Missing](missing.md)",
      "![Missing image](missing.png)",
      "[Bad anchor](target.md#not-a-heading)",
    ]) {
      const bad = write("links.md", `# Links\n\n${link}\n`);
      check("links", [bad], 1, /local links and anchors failed/);
    }
  }));

test("actionlint rejects invalid workflow keys and checks Bash run blocks", () =>
  fixture((write) => {
    const workflow = (run) =>
      `name: Fixture\non: push\njobs:\n  check:\n    runs-on: ubuntu-latest\n    steps:\n      - run: ${run}\n`;
    const bad = write(
      "workflow.yml",
      workflow("echo ok").replace("runs-on:", "runs-onn:"),
    );
    check("workflows", [bad], 1, /runs-onn/);
    const shell = write("workflow.yml", workflow("echo $GITHUB_WORKSPACE"));
    check("workflows", [shell], 1, /SC2086/);
    const good = write("workflow.yml", workflow('echo "$GITHUB_WORKSPACE"'));
    check("workflows", [good], 0);
  }));

test("ShellCheck rejects word splitting and shfmt supplies a stable fix", () =>
  fixture((write) => {
    const bad = write("script.sh", "#!/usr/bin/env bash\necho $1\n");
    check("shellcheck", [bad], 1, /SC2086/);
    const good = write("script.sh", '#!/usr/bin/env bash\necho "$1"\n');
    check("shellcheck", [good], 0);
    const ugly = write(
      "script.sh",
      '#!/usr/bin/env bash\nif true; then\necho "hello"; fi\n',
    );
    check("shell-format", [ugly], 1, /shfmt.*failed/);
    check("shell-format", [ugly], 0, undefined, true);
    check("shell-format", [ugly], 0);
  }));
