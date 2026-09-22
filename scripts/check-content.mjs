import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkDeploymentCachePolicy } from "./workflow-cache-policy.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
process.chdir(root);
const args = process.argv.slice(2);
const mode = args.shift() ?? "all";
const fix = args[0] === "--fix";
if (fix) args.shift();
const explicit = args[0] === "--files";
if (explicit) args.shift();
const modes = [
  "all",
  "format",
  "prettier",
  "markdown",
  "workflows",
  "shellcheck",
  "shell-format",
  "links",
  "external-links",
];
if (
  !modes.includes(mode) ||
  (fix && !["format", "prettier", "shell-format"].includes(mode)) ||
  (!explicit && args.length) ||
  (explicit && !args.length)
) {
  throw new Error(
    "Usage: node scripts/check-content.mjs [all|format|prettier|markdown|workflows|shellcheck|shell-format|links|external-links] [--fix] [--files paths...]",
  );
}
if (process.versions.node.split(".")[0] !== "22") {
  throw new Error(
    "Content checks require Node.js 22. Select it on PATH before running this command.",
  );
}

function run(command, arguments_, label = command) {
  console.log(`Checking ${label}`);
  const result = spawnSync(command, arguments_, {
    cwd: root,
    stdio: "inherit",
    shell: false,
  });
  if (result.error) throw result.error;
  if (result.status !== 0)
    throw new Error(
      `${label} failed (exit ${result.status}). See the diagnostic above.`,
    );
}

function npmTool(name, bin) {
  const expected = JSON.parse(readFileSync("package.json", "utf8"))
    .devDependencies[name];
  const manifest = path.join(root, "node_modules", name, "package.json");
  if (
    !existsSync(manifest) ||
    JSON.parse(readFileSync(manifest, "utf8")).version !== expected
  ) {
    throw new Error(
      `Install pinned ${name} ${expected}: npm ci --ignore-scripts`,
    );
  }
  return path.join(root, "node_modules", name, bin);
}

function nativeTool(name) {
  const platform = `${process.platform === "win32" ? "windows" : process.platform}-${process.arch}`;
  const manifest = JSON.parse(
    readFileSync("scripts/content-tools.json", "utf8"),
  );
  const tool = manifest.tools[name];
  const spec = tool?.platforms[platform];
  if (!spec) throw new Error(`Unsupported content-tool platform: ${platform}`);
  const executable = path.join(
    root,
    "artifacts",
    "content-tools",
    platform,
    name,
    name + (process.platform === "win32" ? ".exe" : ""),
  );
  if (
    !existsSync(executable) ||
    createHash("sha256").update(readFileSync(executable)).digest("hex") !==
      spec.executableSha256
  ) {
    throw new Error(
      `Missing or incorrect ${name} ${tool.version}. Run pwsh ./scripts/install-content-tools.ps1`,
    );
  }
  return executable;
}

// Git enumerates source without traversing ignored dependencies or build output.
// Include new files so local checks cover work before it is staged.
const listing = explicit
  ? args
  : (() => {
      const result = spawnSync(
        "git",
        ["ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        { encoding: "utf8" },
      );
      if (result.error) throw result.error;
      if (result.status !== 0)
        throw new Error(`Cannot enumerate source files: ${result.stderr}`);
      return result.stdout.split("\0").filter(Boolean);
    })();
const files = [...new Set(listing)].map((file) =>
  path.relative(root, path.resolve(root, file)).replaceAll("\\", "/"),
);
if (files.some((file) => file.startsWith("../") || path.isAbsolute(file)))
  throw new Error("Content inputs must be inside this checkout.");
const source = files.filter(
  (file) =>
    existsSync(file) &&
    !/(^|\/)(bin|obj|node_modules|artifacts|\.git|\.vs)\//i.test(file) &&
    !file.startsWith(".agents/skills/"),
);
const content = source.filter((file) =>
  /\.(md|jsonc?|ya?ml|css|[cm]?js)$/.test(file),
);
const markdown = source.filter((file) => file.endsWith(".md"));
const shell = source.filter(
  (file) => file.endsWith(".sh") || file === ".husky/pre-commit",
);
const workflows = source.filter(
  (file) =>
    /\.ya?ml$/.test(file) &&
    (explicit || file.startsWith(".github/workflows/")),
);
const selected = (name) =>
  mode === "all" ||
  mode === name ||
  (mode === "format" && ["prettier", "shell-format"].includes(name));

try {
  if (selected("prettier") && content.length) {
    run(
      process.execPath,
      [
        npmTool("prettier", "bin/prettier.cjs"),
        fix ? "--write" : "--check",
        ...content,
      ],
      "Prettier (fix: pwsh ./scripts/check.ps1 format -Fix)",
    );
  }
  if (selected("markdown") && markdown.length) {
    run(
      process.execPath,
      [npmTool("markdownlint-cli2", "markdownlint-cli2-bin.mjs"), ...markdown],
      "Markdown structure",
    );
  }
  if (selected("workflows") && workflows.length) {
    npmTool("markdownlint-cli2", "markdownlint-cli2-bin.mjs");
    const { default: parseYaml } =
      await import("markdownlint-cli2/parsers/yaml");
    for (const file of workflows) {
      checkDeploymentCachePolicy(file, parseYaml(readFileSync(file, "utf8")));
    }
    // Explicit ShellCheck path keeps Bash run-block checks identical on both OSes.
    run(
      nativeTool("actionlint"),
      [
        "-color",
        "-shellcheck",
        nativeTool("shellcheck"),
        "-pyflakes=",
        ...workflows,
      ],
      "workflow syntax and Bash run blocks",
    );
  }
  if (selected("shellcheck") && shell.length) {
    run(
      nativeTool("shellcheck"),
      [
        "--external-sources",
        "--source-path=SCRIPTDIR",
        "--severity=style",
        ...shell,
      ],
      "ShellCheck",
    );
  }
  if (selected("shell-format") && shell.length) {
    run(
      nativeTool("shfmt"),
      [fix ? "-w" : "-d", ...shell],
      "shfmt (fix: pwsh ./scripts/check.ps1 format -Fix)",
    );
  }
  if ((selected("links") || mode === "external-links") && markdown.length) {
    const external = mode === "external-links";
    run(
      nativeTool("lychee"),
      [
        "--config",
        external ? ".lychee-external.toml" : ".lychee.toml",
        "--root-dir",
        root,
        ...markdown,
      ],
      external
        ? "external links (maintenance report)"
        : "local links and anchors",
    );
  }
  console.log(`PASS content ${mode}`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
