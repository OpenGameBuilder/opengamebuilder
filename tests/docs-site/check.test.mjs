import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  checkRenderedLinks,
  checkSiteInventory,
  siteRoot,
} from "../../scripts/check-docs.mjs";
import {
  resolveRepositoryLinks,
  sourceRepository,
} from "../../scripts/docs-links.mjs";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

function fixture(action) {
  const directory = mkdtempSync(path.join(root, "artifacts/docs/fixture-"));
  const write = (file, content) => {
    const target = path.join(directory, file);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, content);
  };
  try {
    action(directory, write);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test("rendered checks reject missing pages, anchors, and assets while staying offline", () => {
  fixture((directory, write) => {
    write(
      "index.html",
      '<a href="page.html#section">Guide</a><link rel="stylesheet" href="style.css"><a href="https://unavailable.invalid">Remote</a>',
    );
    write("page.html", '<h1 id="section">Guide</h1>');
    write("style.css", "body { color: black; }");
    assert.doesNotThrow(() => checkRenderedLinks(directory));
    write("page.html", '<h1 id="renamed">Guide</h1>');
    assert.throws(() => checkRenderedLinks(directory), /section/);
    write("page.html", '<h1 id="section">Guide</h1>');
    rmSync(path.join(directory, "style.css"));
    assert.throws(() => checkRenderedLinks(directory), /style\.css/);
    write("style.css", "body { color: black; }");
    rmSync(path.join(directory, "page.html"));
    assert.throws(() => checkRenderedLinks(directory), /page\.html/);
  });
});

test("site inventory rejects a missing search entry and accidental plan publication", () => {
  fixture((directory, write) => {
    write("manifest.json", readFileSync(path.join(siteRoot, "manifest.json")));
    write(
      "build-info.json",
      readFileSync(path.join(siteRoot, "build-info.json")),
    );
    write("index.json", "{}");
    assert.throws(() => checkSiteInventory(directory), /Search is missing/);
    write("docs/foundation-checklist.html", "temporary plan");
    assert.throws(() => checkSiteInventory(directory), /must not be published/);
  });
});

test("site gate rejects an unresolved source link after DocFX's repository-link diagnostic", () => {
  fixture((directory, write) => {
    write("index.md", "# Broken guide\n\n[Missing document](missing.md)\n");
    write(
      "docfx.json",
      JSON.stringify({
        rules: { InvalidFileLink: "info" },
        build: {
          content: ["*.md"],
          template: ["default", "modern"],
          output: "site",
        },
      }),
    );
    const result = spawnSync(
      "dotnet",
      [
        "tool",
        "run",
        "docfx",
        "--",
        "build",
        path.join(directory, "docfx.json"),
        "--warningsAsErrors",
      ],
      { cwd: path.join(root, "docs"), encoding: "utf8", shell: false },
    );
    if (result.error) throw result.error;
    const diagnostic = result.stdout + result.stderr;
    assert.equal(result.status, 0, diagnostic);
    assert.match(diagnostic, /missing\.md/);
    assert.match(diagnostic, /InvalidFileLink|InvalidHref/);
    assert.throws(
      () =>
        resolveRepositoryLinks(
          path.join(directory, "site"),
          directory,
          "a".repeat(40),
        ),
      /missing local link missing\.md/,
    );
  });
});

test("relative links retain page context and resolve repository source against each build's commit", () => {
  for (const revision of ["a".repeat(40), "b".repeat(40)]) {
    fixture((directory, write) => {
      write("docs/page.md", "# Guide\n");
      write("source/example.cs", "// checked source\n");
      write("site/docs/guide.html", '<h1 id="setup">Setup</h1>');
      write(
        "site/docs/page.html",
        '<a href="guide.html#setup">Guide</a><a href="../source/example.cs">Code</a><a href="../source/">Directory</a><a href="https://example.com">Remote</a>',
      );
      write(
        "site/manifest.json",
        JSON.stringify({
          files: [
            {
              type: "Conceptual",
              source_relative_path: "docs/page.md",
              output: { ".html": { relative_path: "docs/page.html" } },
            },
          ],
        }),
      );
      resolveRepositoryLinks(path.join(directory, "site"), directory, revision);
      const html = readFileSync(
        path.join(directory, "site/docs/page.html"),
        "utf8",
      );
      assert.ok(html.includes('href="guide.html#setup"'));
      assert.ok(
        html.includes(`${sourceRepository}/blob/${revision}/source/example.cs`),
      );
      assert.ok(html.includes(`${sourceRepository}/tree/${revision}/source`));
      assert.ok(html.includes('href="https://example.com"'));
      assert.equal(
        readFileSync(path.join(directory, "docs/page.md"), "utf8"),
        "# Guide\n",
      );

      write("site/docs/page.html", '<a href="../../outside.txt">Outside</a>');
      assert.throws(
        () =>
          resolveRepositoryLinks(
            path.join(directory, "site"),
            directory,
            revision,
          ),
        /missing local link/,
      );
      write("docs/omitted.md", "# Omitted guide\n");
      write("site/docs/page.html", '<a href="omitted.md">Omitted</a>');
      assert.throws(
        () =>
          resolveRepositoryLinks(
            path.join(directory, "site"),
            directory,
            revision,
          ),
        /documentation target was not rendered/,
      );
      write("site/docs/page.html", '<img src="../source/example.cs">');
      assert.throws(
        () =>
          resolveRepositoryLinks(
            path.join(directory, "site"),
            directory,
            revision,
          ),
        /missing site asset/,
      );
    });
  }
});
