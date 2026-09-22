import { spawnSync } from "node:child_process";
import {
  existsSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { parse } from "parse5";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const sourceRepository =
  "https://github.com/OpenGameBuilder/opengamebuilder";

function documentationFiles(directory = root) {
  const markdown = (folder) =>
    readdirSync(folder, { withFileTypes: true }).flatMap((entry) => {
      const file = path.join(folder, entry.name);
      return entry.isDirectory()
        ? markdown(file)
        : entry.name.endsWith(".md")
          ? [file]
          : [];
    });
  return [
    ...readdirSync(directory)
      .filter((name) => name.endsWith(".md") && name !== "AGENTS.md")
      .map((name) => path.join(directory, name)),
    ...markdown(path.join(directory, "docs")).filter(
      (file) => path.basename(file) !== "foundation-checklist.md",
    ),
  ];
}

export function sourceRevision(repositoryRoot = root) {
  const result = spawnSync("git", ["rev-parse", "HEAD"], {
    cwd: repositoryRoot,
    encoding: "utf8",
    shell: false,
  });
  if (result.error) throw result.error;
  const revision = result.stdout.trim();
  if (result.status !== 0 || !/^[0-9a-f]{40}$/.test(revision)) {
    throw new Error(
      `Cannot resolve the documentation source commit: ${result.stderr}`,
    );
  }
  return revision;
}

function inside(directory, candidate) {
  const relative = path.relative(directory, candidate);
  return (
    relative !== ".." &&
    !relative.startsWith(`..${path.sep}`) &&
    !path.isAbsolute(relative)
  );
}

// Page links stay local. Only links to existing repository files/directories
// omitted from the site become source URLs, pinned to this build's commit.
export function resolveRepositoryLinks(directory, repositoryRoot, revision) {
  if (!/^[0-9a-f]{40}$/.test(revision))
    throw new Error("Source revision must be a full commit SHA.");
  const manifest = JSON.parse(
    readFileSync(path.join(directory, "manifest.json"), "utf8"),
  );
  let count = 0;
  for (const page of manifest.files.filter(
    (item) => item.type === "Conceptual",
  )) {
    const output = path.join(directory, page.output[".html"].relative_path);
    const source = path.join(repositoryRoot, page.source_relative_path);
    const html = readFileSync(output, "utf8");
    const edits = [];
    function visit(node) {
      for (const attribute of node.attrs ?? []) {
        if (!["href", "src"].includes(attribute.name)) continue;
        const href = attribute.value;
        if (!href || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(href)) continue;
        const url = new URL(href, "https://site.invalid/");
        const relative = decodeURIComponent(href.split(/[?#]/, 1)[0]);
        const renderedTarget = path.resolve(path.dirname(output), relative);
        if (inside(directory, renderedTarget) && existsSync(renderedTarget))
          continue;
        const target = path.resolve(path.dirname(source), relative);
        if (!inside(repositoryRoot, target) || !existsSync(target)) {
          throw new Error(
            `${page.source_relative_path}: missing local link ${href}`,
          );
        }
        const repositoryPath = path
          .relative(repositoryRoot, target)
          .replaceAll(path.sep, "/");
        if (repositoryPath.endsWith(".md") && repositoryPath !== "AGENTS.md") {
          throw new Error(
            `${page.source_relative_path}: documentation target was not rendered: ${href}`,
          );
        }
        // Images and scripts must ship as site resources; a GitHub file page is
        // not an asset replacement. Missing generated resources must also fail.
        if (node.tagName !== "a" || attribute.name !== "href") {
          throw new Error(
            `${page.source_relative_path}: missing site asset ${href}`,
          );
        }
        const kind = statSync(target).isDirectory() ? "tree" : "blob";
        const encodedPath = repositoryPath
          .split("/")
          .map(encodeURIComponent)
          .join("/");
        const destination = `${sourceRepository}/${kind}/${revision}/${encodedPath}${url.search}${url.hash}`;
        const location = node.sourceCodeLocation.attrs[attribute.name];
        edits.push({
          ...location,
          value: `href="${destination.replaceAll("&", "&amp;")}"`,
        });
        count++;
      }
      for (const child of node.childNodes ?? []) visit(child);
    }
    visit(parse(html, { sourceCodeLocationInfo: true }));
    let rewritten = html;
    for (const edit of edits.sort((a, b) => b.startOffset - a.startOffset)) {
      rewritten =
        rewritten.slice(0, edit.startOffset) +
        edit.value +
        rewritten.slice(edit.endOffset);
    }
    if (edits.length) writeFileSync(output, rewritten);
  }
  writeFileSync(
    path.join(directory, "build-info.json"),
    JSON.stringify({ sourceRepository, sourceRevision: revision }, null, 2) +
      "\n",
  );
  return `Resolved ${count} repository links against ${revision}; documentation links remain relative.`;
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  try {
    const revision = sourceRevision();
    if (process.argv[2] === "prepare") {
      writeFileSync(
        path.join(root, "artifacts/docs/source-metadata.json"),
        JSON.stringify({
          docurl: Object.fromEntries(
            documentationFiles().map((file) => {
              const relative = path
                .relative(root, file)
                .replaceAll(path.sep, "/");
              return [
                relative,
                `${sourceRepository}/blob/${revision}/${relative}`,
              ];
            }),
          ),
        }),
      );
    } else if (process.argv[2] === "resolve") {
      console.log(
        resolveRepositoryLinks(
          path.join(root, "artifacts/docs/site"),
          root,
          revision,
        ),
      );
    } else
      throw new Error("Usage: node scripts/docs-links.mjs prepare|resolve");
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
