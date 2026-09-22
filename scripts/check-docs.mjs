import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { sourceRepository } from "./docs-links.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const siteRoot = path.join(root, "artifacts/docs/site");

function filesUnder(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(file) : [file];
  });
}

function lycheePath() {
  const platform = `${process.platform === "win32" ? "windows" : process.platform}-${process.arch}`;
  const spec = JSON.parse(
    readFileSync(path.join(root, "scripts/content-tools.json"), "utf8"),
  ).tools.lychee.platforms[platform];
  const executable = path.join(
    root,
    "artifacts/content-tools",
    platform,
    "lychee",
    `lychee${process.platform === "win32" ? ".exe" : ""}`,
  );
  if (
    !spec ||
    !existsSync(executable) ||
    createHash("sha256").update(readFileSync(executable)).digest("hex") !==
      spec.executableSha256
  ) {
    throw new Error(
      "Install the pinned link checker: pwsh ./scripts/install-content-tools.ps1",
    );
  }
  return executable;
}

export function checkRenderedLinks(directory) {
  const html = filesUnder(directory).filter((file) => file.endsWith(".html"));
  if (html.length === 0) throw new Error("No rendered HTML pages to check.");
  const result = spawnSync(
    lycheePath(),
    [
      "--config",
      path.join(root, ".lychee.toml"),
      "--root-dir",
      directory,
      "--index-files",
      "index.html",
      ...html,
    ],
    { encoding: "utf8", shell: false },
  );
  if (result.error) throw result.error;
  if (result.status !== 0)
    throw new Error(`Rendered links failed:\n${result.stdout}${result.stderr}`);
  return result.stdout + result.stderr;
}

export function checkSiteInventory(directory) {
  const files = filesUnder(directory);
  if (
    files.some((file) => path.basename(file).startsWith("foundation-checklist"))
  ) {
    throw new Error("The temporary foundation plan must not be published.");
  }
  const readJson = (file) =>
    JSON.parse(readFileSync(path.join(directory, file), "utf8"));
  const search = readJson("index.json");
  const manifest = readJson("manifest.json");
  const build = readJson("build-info.json");
  if (
    build.sourceRepository !== sourceRepository ||
    !/^[0-9a-f]{40}$/.test(build.sourceRevision)
  ) {
    throw new Error("Missing immutable documentation source revision.");
  }
  const pages = manifest.files.filter((file) => file.type === "Conceptual");
  if (!pages.length) throw new Error("The site has no conceptual pages.");
  for (const page of pages) {
    const output = page.output[".html"].relative_path;
    const entry = search[output];
    if (!entry?.summary || !entry.title || entry.href !== output) {
      throw new Error(`Search is missing the rendered page ${output}.`);
    }
    const html = readFileSync(path.join(directory, output), "utf8");
    const source = page.source_relative_path;
    const edit = `${sourceRepository}/blob/${build.sourceRevision}/${source}`;
    if (
      !html.includes(`href="${edit}/#`) &&
      !html.includes(`href="${edit}#`) &&
      !html.includes(`href="${edit}"`)
    ) {
      throw new Error(
        `Edit link does not point to the original source: ${source}.`,
      );
    }
    if (!html.includes('id="search-query"'))
      throw new Error(`Search UI missing from ${output}.`);
  }
  for (const entry of Object.values(search)) {
    if (
      !pages.some((page) => page.output[".html"].relative_path === entry.href)
    ) {
      throw new Error(
        `Search points outside the rendered pages: ${entry.href}.`,
      );
    }
  }
  for (const entry of readJson("toc.json").items) {
    if (!existsSync(path.join(directory, entry.href)))
      throw new Error(`Missing navigation page: ${entry.href}.`);
  }
  for (const file of [
    "index.html",
    "public/docfx.min.js",
    "public/docfx.min.css",
  ]) {
    if (!existsSync(path.join(directory, file)))
      throw new Error(`Missing site asset: ${file}.`);
  }
  return `Search and original-source edit links checked for ${pages.length} pages.`;
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  try {
    console.log(checkSiteInventory(siteRoot));
    console.log(checkRenderedLinks(siteRoot));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
