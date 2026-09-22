import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { lstatSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SOURCE_NAMES = ["aspire-skills", "aspire-cli", "dotnet-inspect"];
const TOOL_NAMES = ["aspire", "dotnet-inspect"];
const SKILL_NAMES = [
  "aspire",
  "aspire-deployment",
  "aspire-init",
  "aspire-monitoring",
  "aspire-orchestration",
  "aspireify",
  "dotnet-inspect",
];
const LICENSE_FILES = [
  "docs/licenses/aspire-MIT.txt",
  "docs/licenses/aspire-skills-MIT.txt",
];
const ASPIRE_MCP_ARGS = ["tool", "run", "aspire", "--", "agent", "mcp"];
const SHA256 = /^[0-9a-f]{64}$/u;
const COMMIT = /^[0-9a-f]{40}$/u;
const VERSION = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/u;

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function readJson(root, relative) {
  try {
    return JSON.parse(readFileSync(path.join(root, relative), "utf8"));
  } catch (error) {
    throw new Error(`${relative} is not valid JSON: ${error.message}`);
  }
}

function normalizedSha256(file) {
  const normalized = readFileSync(file, "utf8").replace(/\r\n?/gu, "\n");
  return createHash("sha256").update(normalized, "utf8").digest("hex");
}

function filesUnder(root, relative, problems) {
  const directory = path.join(root, relative);
  let entries;
  try {
    entries = readdirSync(directory, { withFileTypes: true });
  } catch (error) {
    problems.push(`Cannot enumerate ${relative}: ${error.message}`);
    return [];
  }
  return entries.flatMap((entry) => {
    const child = path.posix.join(relative, entry.name);
    if (entry.isSymbolicLink()) {
      problems.push(`${child} must not be a symbolic link`);
      return [];
    }
    return entry.isDirectory()
      ? filesUnder(root, child, problems)
      : entry.isFile()
        ? [child]
        : [];
  });
}

function checkExactKeys(value, expected, label, problems) {
  if (!isObject(value)) {
    problems.push(`${label} must be an object`);
    return false;
  }
  const actual = Object.keys(value).toSorted();
  const wanted = [...expected].toSorted();
  if (actual.join("\0") !== wanted.join("\0")) {
    problems.push(
      `${label} keys must be exactly ${wanted.join(", ")} (found ${actual.join(", ") || "none"})`,
    );
    return false;
  }
  return true;
}

function checkSource(name, source, problems) {
  if (!isObject(source)) {
    problems.push(`sources.${name} must be an object`);
    return;
  }
  const allowed = [
    "repository",
    "version",
    "commit",
    "source",
    "license",
    ...(source.artifact === undefined ? [] : ["artifact"]),
  ];
  if (!checkExactKeys(source, allowed, `sources.${name}`, problems)) return;

  if (!VERSION.test(source.version ?? ""))
    problems.push(`sources.${name}.version must be a semantic version`);
  if (!COMMIT.test(source.commit ?? ""))
    problems.push(
      `sources.${name}.commit must be a lowercase 40-character SHA`,
    );

  let repository;
  try {
    repository = new URL(source.repository);
    if (
      repository.protocol !== "https:" ||
      repository.hostname !== "github.com" ||
      !/^\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/u.test(repository.pathname) ||
      repository.search ||
      repository.hash
    ) {
      throw new Error("expected an HTTPS GitHub repository URL");
    }
  } catch (error) {
    problems.push(`sources.${name}.repository is invalid: ${error.message}`);
    repository = undefined;
  }

  for (const field of ["source", "license"]) {
    try {
      const url = new URL(source[field]);
      if (
        url.protocol !== "https:" ||
        url.hostname !== "github.com" ||
        url.search ||
        (url.hash && !/^#L\d+(?:-L\d+)?$/u.test(url.hash)) ||
        !url.pathname.split("/").includes(source.commit) ||
        (repository &&
          !url.pathname.startsWith(
            `${repository.pathname.replace(/\/$/u, "")}/`,
          ))
      ) {
        throw new Error(
          "expected a revision-bound URL in the declared repository",
        );
      }
    } catch (error) {
      problems.push(`sources.${name}.${field} is invalid: ${error.message}`);
    }
  }

  if (source.artifact !== undefined) {
    if (
      checkExactKeys(
        source.artifact,
        ["url", "sha256"],
        `sources.${name}.artifact`,
        problems,
      )
    ) {
      try {
        const artifact = new URL(source.artifact.url);
        if (artifact.protocol !== "https:" || artifact.search || artifact.hash)
          throw new Error("expected an immutable HTTPS URL");
      } catch (error) {
        problems.push(
          `sources.${name}.artifact.url is invalid: ${error.message}`,
        );
      }
      if (!SHA256.test(source.artifact.sha256 ?? ""))
        problems.push(
          `sources.${name}.artifact.sha256 must be a lowercase SHA-256`,
        );
    }
  }
}

function checkManifest(root, manifest, problems) {
  if (
    !checkExactKeys(
      manifest,
      ["schemaVersion", "sources", "tools", "files"],
      "provenance manifest",
      problems,
    )
  )
    return undefined;
  if (manifest.schemaVersion !== 1)
    problems.push("provenance manifest schemaVersion must be 1");

  const sourcesValid = checkExactKeys(
    manifest.sources,
    SOURCE_NAMES,
    "sources",
    problems,
  );
  if (sourcesValid) {
    for (const name of SOURCE_NAMES)
      checkSource(name, manifest.sources[name], problems);
  }
  const toolsValid = checkExactKeys(
    manifest.tools,
    TOOL_NAMES,
    "tools",
    problems,
  );
  if (toolsValid) {
    for (const name of TOOL_NAMES) {
      if (
        !checkExactKeys(
          manifest.tools[name],
          ["version"],
          `tools.${name}`,
          problems,
        )
      )
        continue;
      if (!VERSION.test(manifest.tools[name].version ?? ""))
        problems.push(`tools.${name}.version must be a semantic version`);
    }
  }
  if (sourcesValid && toolsValid) {
    for (const [tool, source] of [
      ["aspire", "aspire-cli"],
      ["dotnet-inspect", "dotnet-inspect"],
    ]) {
      if (manifest.tools[tool]?.version !== manifest.sources[source]?.version)
        problems.push(
          `tools.${tool}.version does not match sources.${source}.version`,
        );
    }
  }

  if (!isObject(manifest.files)) {
    problems.push("files must be an object");
    return manifest.tools;
  }
  const skillRoots = readdirSync(path.join(root, ".agents/skills"), {
    withFileTypes: true,
  })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .toSorted();
  if (skillRoots.join("\0") !== SKILL_NAMES.join("\0")) {
    problems.push(
      `.agents/skills directories must be exactly ${SKILL_NAMES.join(", ")} (found ${skillRoots.join(", ") || "none"})`,
    );
  }
  const expectedFiles = [
    ...filesUnder(root, ".agents/skills", problems),
    ...LICENSE_FILES,
  ].toSorted();
  const recordedFiles = Object.keys(manifest.files).toSorted();
  for (const file of recordedFiles) {
    if (
      path.posix.normalize(file) !== file ||
      file.startsWith("/") ||
      file.startsWith("../") ||
      file.includes("\\")
    )
      problems.push(
        `files key is not a canonical repository-relative path: ${file}`,
      );
    if (!SHA256.test(manifest.files[file] ?? ""))
      problems.push(`files.${file} must be a lowercase SHA-256`);
  }
  for (const file of expectedFiles.filter(
    (file) => !Object.hasOwn(manifest.files, file),
  ))
    problems.push(`${file} is not recorded in the provenance manifest`);
  for (const file of recordedFiles.filter(
    (file) => !expectedFiles.includes(file),
  ))
    problems.push(
      `${file} is recorded but is not an installed skill or license file`,
    );
  for (const file of expectedFiles.filter((file) =>
    Object.hasOwn(manifest.files, file),
  )) {
    const absolute = path.join(root, file);
    try {
      if (lstatSync(absolute).isSymbolicLink()) {
        problems.push(`${file} must not be a symbolic link`);
        continue;
      }
      const actual = normalizedSha256(absolute);
      if (actual !== manifest.files[file])
        problems.push(`${file} checksum mismatch`);
    } catch (error) {
      problems.push(`${file} cannot be verified: ${error.message}`);
    }
  }
  return manifest.tools;
}

function checkAspireVersions(root, tools, problems) {
  const expected = tools?.aspire?.version;
  if (!VERSION.test(expected ?? "")) return;

  const dotnetTools = readJson(root, ".config/dotnet-tools.json");
  const toolVersion = dotnetTools?.tools?.["aspire.cli"]?.version;
  if (toolVersion !== expected)
    problems.push(
      `.config/dotnet-tools.json aspire.cli version ${toolVersion ?? "missing"} does not match ${expected}`,
    );

  const project = readFileSync(
    path.join(
      root,
      "src/OpenGameBuilder.AppHost/OpenGameBuilder.AppHost.csproj",
    ),
    "utf8",
  );
  const sdkTags = [...project.matchAll(/<Sdk\b[^>]*>/gu)];
  const sdk = sdkTags.find((match) =>
    /\bName=["']Aspire\.AppHost\.Sdk["']/u.test(match[0]),
  )?.[0];
  const sdkVersion = sdk?.match(/\bVersion=["']([^"']+)["']/u)?.[1];
  if (sdkVersion !== expected)
    problems.push(
      `Aspire.AppHost.Sdk version ${sdkVersion ?? "missing"} does not match ${expected}`,
    );

  const packages = readFileSync(
    path.join(root, "Directory.Packages.props"),
    "utf8",
  );
  const packageTags = [...packages.matchAll(/<PackageVersion\b[^>]*>/gu)];
  const appHost = packageTags.find((match) =>
    /\bInclude=["']Aspire\.Hosting\.AppHost["']/u.test(match[0]),
  )?.[0];
  const packageVersion = appHost?.match(/\bVersion=["']([^"']+)["']/u)?.[1];
  if (packageVersion !== expected)
    problems.push(
      `Aspire.Hosting.AppHost version ${packageVersion ?? "missing"} does not match ${expected}`,
    );
}

function checkJsonAdapter(root, relative, select, requireType, problems) {
  const configuration = readJson(root, relative);
  const adapter = select(configuration);
  if (!isObject(adapter)) {
    problems.push(`${relative} does not define the Aspire MCP adapter`);
    return;
  }
  if (requireType && adapter.type !== "stdio")
    problems.push(`${relative} Aspire MCP adapter type must be stdio`);
  if (
    adapter.command !== "dotnet" ||
    !Array.isArray(adapter.args) ||
    adapter.args.length !== ASPIRE_MCP_ARGS.length ||
    adapter.args.some((argument, index) => argument !== ASPIRE_MCP_ARGS[index])
  )
    problems.push(
      `${relative} Aspire MCP adapter must run: dotnet ${ASPIRE_MCP_ARGS.join(" ")}`,
    );
}

function parseCodexAspireAdapter(root, problems) {
  const relative = ".codex/config.toml";
  const text = readFileSync(path.join(root, relative), "utf8");
  const headers = [...text.matchAll(/^\s*\[([^\]]+)\]\s*(?:#.*)?$/gmu)];
  const matching = headers.filter(
    (match) => match[1].trim() === "mcp_servers.aspire",
  );
  if (matching.length !== 1) {
    problems.push(`${relative} must contain one [mcp_servers.aspire] section`);
    return;
  }
  const start = matching[0].index + matching[0][0].length;
  const next = headers.find((header) => header.index > matching[0].index);
  const section = text.slice(start, next?.index ?? text.length);
  const values = {};
  for (const line of section.split(/\r?\n/u)) {
    const match = line.match(/^\s*([A-Za-z0-9_-]+)\s*=\s*(.*?)\s*(?:#.*)?$/u);
    if (!match) continue;
    if (Object.hasOwn(values, match[1])) {
      problems.push(
        `${relative} repeats ${match[1]} in the Aspire MCP adapter`,
      );
      continue;
    }
    if (!["command", "args", "startup_timeout_sec"].includes(match[1])) {
      problems.push(`${relative} has unsupported Aspire MCP key ${match[1]}`);
      continue;
    }
    try {
      values[match[1]] = JSON.parse(match[2]);
    } catch {
      problems.push(`${relative} has an invalid ${match[1]} value`);
    }
  }
  if (
    values.command !== "dotnet" ||
    !Array.isArray(values.args) ||
    values.args.length !== ASPIRE_MCP_ARGS.length ||
    values.args.some((argument, index) => argument !== ASPIRE_MCP_ARGS[index])
  )
    problems.push(
      `${relative} Aspire MCP adapter must run: dotnet ${ASPIRE_MCP_ARGS.join(" ")}`,
    );
}

export function runVersionCommand(command, arguments_, root, options = {}) {
  const platform = options.platform ?? process.platform;
  const spawn = options.spawn ?? spawnSync;
  if (
    platform === "win32" &&
    command === "dotnet-inspect" &&
    arguments_.length === 1 &&
    arguments_[0] === "--version"
  ) {
    const lookup = spawn("where.exe", ["dotnet-inspect"], {
      cwd: root,
      encoding: "utf8",
      shell: false,
      timeout: 30_000,
    });
    if (lookup.status === 1 && !lookup.error)
      return {
        ...lookup,
        error: Object.assign(new Error("dotnet-inspect is not installed"), {
          code: "ENOENT",
        }),
      };
    if (lookup.error || lookup.status !== 0) return lookup;
    return spawn("cmd.exe", ["/d", "/s", "/c", "dotnet-inspect --version"], {
      cwd: root,
      encoding: "utf8",
      shell: false,
      timeout: 30_000,
    });
  }
  return spawn(command, arguments_, {
    cwd: root,
    encoding: "utf8",
    shell: false,
    timeout: 30_000,
  });
}

function reportedVersion(result) {
  return (result.stdout ?? "").match(
    /\b\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?/u,
  )?.[0];
}

function checkInstalled(root, tools, options, problems, warnings) {
  const run = options.commandRunner ?? runVersionCommand;
  const aspire = run(
    "dotnet",
    ["tool", "run", "aspire", "--", "--version"],
    root,
  );
  if (aspire.error || aspire.status !== 0) {
    problems.push(
      `Installed Aspire version check failed: ${aspire.error?.message ?? (aspire.stderr || aspire.stdout || `exit ${aspire.status}`).trim()}`,
    );
  } else if (reportedVersion(aspire) !== tools.aspire.version) {
    problems.push(
      `Installed Aspire version ${reportedVersion(aspire) ?? "unrecognized"} does not match ${tools.aspire.version}`,
    );
  }

  const inspect = run("dotnet-inspect", ["--version"], root);
  if (inspect.error?.code === "ENOENT") {
    const message = "Optional dotnet-inspect executable is not installed";
    if (options.requireInspect) problems.push(message);
    else warnings.push(message);
  } else if (inspect.error || inspect.status !== 0) {
    problems.push(
      `Installed dotnet-inspect version check failed: ${inspect.error?.message ?? (inspect.stderr || inspect.stdout || `exit ${inspect.status}`).trim()}`,
    );
  } else if (reportedVersion(inspect) !== tools["dotnet-inspect"].version) {
    problems.push(
      `Installed dotnet-inspect version ${reportedVersion(inspect) ?? "unrecognized"} does not match ${tools["dotnet-inspect"].version}`,
    );
  }
}

export function checkAiTooling(root, options = {}) {
  const problems = [];
  const warnings = [];
  const manifest = readJson(root, ".config/ai-tooling-provenance.json");
  const tools = checkManifest(root, manifest, problems);
  checkAspireVersions(root, tools, problems);
  checkJsonAdapter(
    root,
    ".mcp.json",
    (configuration) => configuration?.servers?.aspire,
    true,
    problems,
  );
  checkJsonAdapter(
    root,
    ".vscode/mcp.json",
    (configuration) => configuration?.servers?.aspire,
    true,
    problems,
  );
  parseCodexAspireAdapter(root, problems);
  if ((options.installed || options.requireInspect) && tools)
    checkInstalled(root, tools, options, problems, warnings);
  if (problems.length)
    throw new Error(
      `AI tooling validation failed:\n${problems.map((problem) => `- ${problem}`).join("\n")}`,
    );
  return { checkedFileCount: Object.keys(manifest.files).length, warnings };
}

const isMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isMain) {
  try {
    const arguments_ = process.argv.slice(2);
    if (
      arguments_.some(
        (argument) => !["--installed", "--require-inspect"].includes(argument),
      ) ||
      new Set(arguments_).size !== arguments_.length
    )
      throw new Error(
        "Usage: node scripts/check-ai-tooling.mjs [--installed] [--require-inspect]",
      );
    const repositoryRoot = path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      "..",
    );
    const result = checkAiTooling(repositoryRoot, {
      installed: arguments_.includes("--installed"),
      requireInspect: arguments_.includes("--require-inspect"),
    });
    for (const warning of result.warnings) console.warn(`WARN ${warning}`);
    console.log(`PASS AI tooling (${result.checkedFileCount} files)`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
