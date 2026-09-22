import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { assertSupportedNode } from "./check-node.mjs";

const toolingRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

function git(root, args) {
  return execFileSync("git", args, {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"],
  });
}

async function loadPrettier() {
  const expected = JSON.parse(
    readFileSync(path.join(toolingRoot, "package.json")),
  ).devDependencies.prettier;
  const directory = path.join(toolingRoot, "node_modules", "prettier");
  try {
    const installed = JSON.parse(
      readFileSync(path.join(directory, "package.json")),
    ).version;
    if (installed !== expected) throw new Error("version mismatch");
  } catch {
    throw new Error(
      `Commit formatting needs Prettier ${expected}. Run npm ci --ignore-scripts from the repository root, then retry.`,
    );
  }
  return import(pathToFileURL(path.join(directory, "index.mjs")).href);
}

export async function checkStaged(root) {
  const files = git(root, [
    "diff",
    "--cached",
    "--name-only",
    "--no-renames",
    "--diff-filter=ACM",
    "-z",
  ])
    .split("\0")
    .filter((file) => /\.(md|jsonc?|ya?ml|css|[cm]?js)$/.test(file))
    .filter(
      (file) =>
        !/^(?:\.agents\/skills\/|artifacts\/)|(?:^|\/)(?:node_modules|bin|obj|\.git)\//i.test(
          file,
        ),
    );
  if (files.length === 0) return { checked: 0, failures: [] };

  assertSupportedNode();
  const prettier = await loadPrettier();
  const failures = [];
  let checked = 0;
  for (const file of files) {
    const absolutePath = path.join(root, file);
    const info = await prettier.getFileInfo(absolutePath, {
      ignorePath: path.join(root, ".prettierignore"),
    });
    if (info.ignored || !info.inferredParser) continue;
    const options =
      (await prettier.resolveConfig(absolutePath, { editorconfig: true })) ??
      {};
    // Read the index, including partially staged files. Never rewrite or restage.
    const source = git(root, ["show", `:${file}`]);
    try {
      if (
        !(await prettier.check(source, { ...options, filepath: absolutePath }))
      )
        failures.push(file);
    } catch (error) {
      throw new Error(`${file}: ${error.message}`);
    }
    checked++;
  }
  return { checked, failures };
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const root = git(process.cwd(), ["rev-parse", "--show-toplevel"]).trim();
    const { checked, failures } = await checkStaged(root);
    if (failures.length) {
      console.error(
        `Staged formatting needs attention:\n${failures.map((file) => `  ${file}`).join("\n")}`,
      );
      console.error(
        "Format the listed files in your editor, review the changes, and stage the intended hunks again. The full content formatter is: npm run format",
      );
      process.exitCode = 1;
    } else {
      console.log(
        `PASS staged formatting (${checked} file${checked === 1 ? "" : "s"}). Full checks run in CI.`,
      );
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
