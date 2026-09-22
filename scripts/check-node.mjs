import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function readPolicy(packagePath, recommendationPath) {
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(packagePath, "utf8"));
  } catch (error) {
    throw new Error(
      `Cannot read the Node policy from ${packagePath}: ${error.message}`,
    );
  }

  const requirement = manifest.engines?.node;
  const match =
    typeof requirement === "string" && /^>=(\d+)$/.exec(requirement);
  if (!match) {
    throw new Error(
      `Unsupported Node policy '${requirement ?? "missing"}': package.json engines.node must use the simple >=N form.`,
    );
  }

  let recommended;
  try {
    recommended = readFileSync(recommendationPath, "utf8").trim();
  } catch (error) {
    throw new Error(
      `Cannot read the recommended Node version from ${recommendationPath}: ${error.message}`,
    );
  }
  if (!/^\d+$/.test(recommended)) {
    throw new Error(".node-version must contain one recommended Node major.");
  }

  return {
    minimumMajor: Number(match[1]),
    recommendedMajor: Number(recommended),
    requirement,
  };
}

export function assertSupportedNode(options = {}) {
  const version = options.version ?? process.version;
  const executable = options.executable ?? process.execPath;
  const policy =
    options.policy ??
    readPolicy(
      options.packagePath ?? path.join(root, "package.json"),
      options.recommendationPath ?? path.join(root, ".node-version"),
    );
  const match =
    typeof version === "string" && /^v?(\d+)(?:\.\d+){0,2}$/.exec(version);

  if (!match || Number(match[1]) < policy.minimumMajor) {
    const actual = version || "missing";
    const location = executable || "unknown executable";
    throw new Error(
      `Node.js ${actual} at '${location}' is unsupported; need Node.js ${policy.minimumMajor}+ (${policy.recommendedMajor} recommended). After changing PATH, restart the terminal and editor.`,
    );
  }

  return {
    executable,
    minimumMajor: policy.minimumMajor,
    recommendedMajor: policy.recommendedMajor,
    version,
  };
}

export function runNodeCheck(options = {}, output = console) {
  try {
    const result = assertSupportedNode(options);
    output.log(
      `Node.js ${result.version} at '${result.executable}' satisfies >=${result.minimumMajor} (${result.recommendedMajor} recommended).`,
    );
    return 0;
  } catch (error) {
    output.error(error instanceof Error ? error.message : String(error));
    return 1;
  }
}

function isCli() {
  return (
    process.argv[1] &&
    import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
  );
}

if (isCli()) {
  process.exitCode = runNodeCheck();
}
