import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  checkAiTooling,
  runVersionCommand,
} from "../../scripts/check-ai-tooling.mjs";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const skills = [
  "aspire",
  "aspire-deployment",
  "aspire-init",
  "aspire-monitoring",
  "aspire-orchestration",
  "aspireify",
  "dotnet-inspect",
];
const mcpArguments = ["tool", "run", "aspire", "--", "agent", "mcp"];

function write(directory, relative, content) {
  const file = path.join(directory, relative);
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, content);
}

function writeJson(directory, relative, value) {
  write(directory, relative, `${JSON.stringify(value, null, 2)}\n`);
}

function hash(content) {
  return createHash("sha256")
    .update(content.replace(/\r\n?/gu, "\n"), "utf8")
    .digest("hex");
}

function source(repository, version, commit, sourcePath) {
  return {
    repository,
    version,
    commit,
    source: `${repository}/blob/${commit}/${sourcePath}`,
    license: `${repository}/blob/${commit}/LICENSE`,
  };
}

function createFixture() {
  const directory = mkdtempSync(path.join(tmpdir(), "ogb-ai-tooling-"));
  const recorded = {};
  for (const [index, name] of skills.entries()) {
    const relative = `.agents/skills/${name}/SKILL.md`;
    const content = index === 0 ? `# ${name}\r\n` : `# ${name}\n`;
    write(directory, relative, content);
    recorded[relative] = hash(content);
  }
  for (const relative of [
    "docs/licenses/aspire-MIT.txt",
    "docs/licenses/aspire-skills-MIT.txt",
  ]) {
    const content = `${relative}\n`;
    write(directory, relative, content);
    recorded[relative] = hash(content);
  }

  const manifest = {
    schemaVersion: 1,
    sources: {
      "aspire-skills": source(
        "https://github.com/microsoft/aspire-skills",
        "0.0.2",
        "a".repeat(40),
        "skills",
      ),
      "aspire-cli": {
        ...source(
          "https://github.com/microsoft/aspire",
          "13.5.4",
          "b".repeat(40),
          "src/Aspire.Cli",
        ),
        artifact: {
          url: "https://github.com/microsoft/aspire/releases/download/v13.5.4/aspire-cli.tgz",
          sha256: "d".repeat(64),
        },
      },
      "dotnet-inspect": source(
        "https://github.com/richlander/dotnet-inspect",
        "0.25.0",
        "c".repeat(40),
        "skills/dotnet-inspect/SKILL.md",
      ),
    },
    tools: {
      aspire: { version: "13.5.4" },
      "dotnet-inspect": { version: "0.25.0" },
    },
    files: recorded,
  };
  writeJson(directory, ".config/ai-tooling-provenance.json", manifest);
  writeJson(directory, ".config/dotnet-tools.json", {
    version: 1,
    isRoot: true,
    tools: {
      "aspire.cli": {
        version: "13.5.4",
        commands: ["aspire"],
        rollForward: false,
      },
    },
  });
  writeJson(directory, ".mcp.json", {
    servers: {
      aspire: { type: "stdio", command: "dotnet", args: mcpArguments },
    },
  });
  writeJson(directory, ".vscode/mcp.json", {
    servers: {
      aspire: { type: "stdio", command: "dotnet", args: mcpArguments },
    },
  });
  write(
    directory,
    ".codex/config.toml",
    `[mcp_servers.aspire]\ncommand = "dotnet"\nargs = ["tool", "run", "aspire", "--", "agent", "mcp"]\nstartup_timeout_sec = 60\n`,
  );
  write(
    directory,
    "src/OpenGameBuilder.AppHost/OpenGameBuilder.AppHost.csproj",
    `<Project Sdk="Microsoft.NET.Sdk">\n  <Sdk Name="Aspire.AppHost.Sdk" Version="13.5.4" />\n</Project>\n`,
  );
  write(
    directory,
    "Directory.Packages.props",
    `<Project>\n  <ItemGroup>\n    <PackageVersion Include="Aspire.Hosting.AppHost" Version="13.5.4" />\n  </ItemGroup>\n</Project>\n`,
  );
  return directory;
}

function withFixture(action) {
  const directory = createFixture();
  try {
    action(directory);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test("fixture proves the closed provenance contract and newline normalization", () =>
  withFixture((directory) => {
    const result = checkAiTooling(directory);
    assert.equal(result.checkedFileCount, 9);
    assert.deepEqual(result.warnings, []);
  }));

test("modified, missing, and unrecorded skill files are rejected", () => {
  for (const [mutate, diagnostic] of [
    [
      (directory) =>
        write(directory, ".agents/skills/aspire/SKILL.md", "modified\n"),
      /aspire\/SKILL\.md checksum mismatch/u,
    ],
    [
      (directory) =>
        unlinkSync(path.join(directory, ".agents/skills/aspire-init/SKILL.md")),
      /aspire-init\/SKILL\.md is recorded but is not an installed skill/u,
    ],
    [
      (directory) =>
        write(
          directory,
          ".agents/skills/aspire/references/new.md",
          "unrecorded\n",
        ),
      /references\/new\.md is not recorded/u,
    ],
  ]) {
    withFixture((directory) => {
      mutate(directory);
      assert.throws(() => checkAiTooling(directory), diagnostic);
    });
  }
});

test("every Aspire version declaration must match the selected tool", () => {
  const cases = [
    [
      ".config/ai-tooling-provenance.json",
      (content) => {
        const manifest = JSON.parse(content);
        manifest.sources["aspire-cli"].version = "13.5.3";
        return `${JSON.stringify(manifest, null, 2)}\n`;
      },
      /tools\.aspire\.version does not match sources\.aspire-cli\.version/u,
    ],
    [
      ".config/dotnet-tools.json",
      (content) =>
        content.replace('"version": "13.5.4"', '"version": "13.5.3"'),
      /dotnet-tools\.json aspire\.cli version 13\.5\.3/u,
    ],
    [
      "src/OpenGameBuilder.AppHost/OpenGameBuilder.AppHost.csproj",
      (content) => content.replace("13.5.4", "13.5.3"),
      /Aspire\.AppHost\.Sdk version 13\.5\.3/u,
    ],
    [
      "Directory.Packages.props",
      (content) => content.replace("13.5.4", "13.5.3"),
      /Aspire\.Hosting\.AppHost version 13\.5\.3/u,
    ],
  ];
  for (const [relative, mutate, diagnostic] of cases) {
    withFixture((directory) => {
      const file = path.join(directory, relative);
      writeFileSync(file, mutate(readFileSync(file, "utf8")));
      assert.throws(() => checkAiTooling(directory), diagnostic);
    });
  }
});

test("all supported MCP adapters must use the repository-local Aspire tool", () => {
  const cases = [
    [
      ".mcp.json",
      (content) => content.replace('"--",', ""),
      /\.mcp\.json Aspire MCP adapter must run/u,
    ],
    [
      ".vscode/mcp.json",
      (content) =>
        content.replace('"command": "dotnet"', '"command": "aspire"'),
      /\.vscode\/mcp\.json Aspire MCP adapter must run/u,
    ],
    [
      ".codex/config.toml",
      (content) => content.replace('"tool", "run", ', ""),
      /\.codex\/config\.toml Aspire MCP adapter must run/u,
    ],
  ];
  for (const [relative, mutate, diagnostic] of cases) {
    withFixture((directory) => {
      const file = path.join(directory, relative);
      writeFileSync(file, mutate(readFileSync(file, "utf8")));
      assert.throws(() => checkAiTooling(directory), diagnostic);
    });
  }
});

test("source URLs require full immutable commits", () =>
  withFixture((directory) => {
    const relative = ".config/ai-tooling-provenance.json";
    const manifest = JSON.parse(
      readFileSync(path.join(directory, relative), "utf8"),
    );
    manifest.sources["dotnet-inspect"].source =
      "https://github.com/richlander/dotnet-inspect/blob/main/SKILL.md";
    writeJson(directory, relative, manifest);
    assert.throws(
      () => checkAiTooling(directory),
      /dotnet-inspect\.source is invalid/u,
    );
  }));

test("installed checks tolerate only a missing optional dotnet-inspect", () =>
  withFixture((directory) => {
    const commandRunner = (command) =>
      command === "dotnet"
        ? { status: 0, stdout: "13.5.4+build\n", stderr: "" }
        : {
            status: null,
            stdout: "",
            stderr: "",
            error: Object.assign(new Error("not found"), { code: "ENOENT" }),
          };
    const result = checkAiTooling(directory, {
      installed: true,
      commandRunner,
    });
    assert.deepEqual(result.warnings, [
      "Optional dotnet-inspect executable is not installed",
    ]);
    assert.throws(
      () =>
        checkAiTooling(directory, {
          requireInspect: true,
          commandRunner,
        }),
      /Optional dotnet-inspect executable is not installed/u,
    );
  }));

test("Windows checks the dotnet-inspect command shim through a static shell command", () => {
  const calls = [];
  const result = runVersionCommand("dotnet-inspect", ["--version"], root, {
    platform: "win32",
    spawn(command, arguments_, options) {
      calls.push({ command, arguments_, options });
      return command === "where.exe"
        ? { status: 0, stdout: "C:\\tools\\dotnet-inspect.cmd\n", stderr: "" }
        : { status: 0, stdout: "0.25.0+build\n", stderr: "" };
    },
  });
  assert.equal(result.status, 0);
  assert.deepEqual(calls, [
    {
      command: "where.exe",
      arguments_: ["dotnet-inspect"],
      options: {
        cwd: root,
        encoding: "utf8",
        shell: false,
        timeout: 30_000,
      },
    },
    {
      command: "cmd.exe",
      arguments_: ["/d", "/s", "/c", "dotnet-inspect --version"],
      options: {
        cwd: root,
        encoding: "utf8",
        shell: false,
        timeout: 30_000,
      },
    },
  ]);
});

test("Windows where exit 1 reports an optional missing dotnet-inspect", () => {
  const result = runVersionCommand("dotnet-inspect", ["--version"], root, {
    platform: "win32",
    spawn(command) {
      assert.equal(command, "where.exe");
      return {
        status: 1,
        stdout: "",
        stderr: "INFO: Could not find files for the given pattern(s).\n",
      };
    },
  });
  assert.equal(result.status, 1);
  assert.equal(result.error?.code, "ENOENT");
});

test("Windows preserves a real dotnet-inspect shim failure", () => {
  const result = runVersionCommand("dotnet-inspect", ["--version"], root, {
    platform: "win32",
    spawn(command) {
      return command === "where.exe"
        ? { status: 0, stdout: "C:\\tools\\dotnet-inspect.cmd\n", stderr: "" }
        : { status: 1, stdout: "", stderr: "tool failed\n" };
    },
  });
  assert.equal(result.status, 1);
  assert.equal(result.error, undefined);
  assert.equal(result.stderr, "tool failed\n");
});

test("Windows propagates a timed-out dotnet-inspect lookup", () => {
  const timeout = Object.assign(new Error("lookup timed out"), {
    code: "ETIMEDOUT",
  });
  let calls = 0;
  const result = runVersionCommand("dotnet-inspect", ["--version"], root, {
    platform: "win32",
    spawn(command) {
      calls += 1;
      assert.equal(command, "where.exe");
      return { status: null, stdout: "", stderr: "", error: timeout };
    },
  });
  assert.equal(calls, 1);
  assert.equal(result.error, timeout);
});

test("repository AI tooling matches its committed provenance record", () => {
  assert.doesNotThrow(() => checkAiTooling(root));
});
