import assert from "node:assert/strict";
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  absoluteChangelogDestination,
  absolutizeMarkdownLinks,
  buildDraft,
  parseChangelog,
  prepareChangelog,
  readVersionPrefix,
  renderReleaseNotes,
  runCli,
  selectVersionSection,
  validateDate,
  validateVersion,
} from "../../scripts/changelog.mjs";

const sha = "0123456789abcdef0123456789abcdef01234567";
const repository = "Example/project";
const props = (version = "1.2.3") =>
  `<Project><PropertyGroup><VersionPrefix>${version}</VersionPrefix></PropertyGroup></Project>\n`;

function changelog(unreleased = "\n### Changed\n\n- Current work.\n") {
  return `# Changelog\n\n## Unreleased\n${unreleased}\n## 1.2.2 - 2026-09-01\n\n- Earlier work.\n`;
}

function fixture(action) {
  const directory = mkdtempSync(path.join(os.tmpdir(), "ogb-changelog-"));
  writeFileSync(path.join(directory, "CHANGELOG.md"), changelog());
  writeFileSync(path.join(directory, "Directory.Build.props"), props());
  try {
    action(directory);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

test("versions and dates use strict plain forms", () => {
  for (const version of ["0.0.0", "1.2.3", "12.34.56"]) {
    assert.equal(validateVersion(version), version);
  }
  for (const version of [
    "v1.2.3",
    "1.2",
    "01.2.3",
    "1.2.3-rc.1",
    "1.2.3+meta",
  ]) {
    assert.throws(() => validateVersion(version), /plain semantic version/);
  }
  assert.equal(validateDate("2024-02-29"), "2024-02-29");
  for (const date of ["2023-02-29", "2026-13-01", "2026-9-01", "not-a-date"]) {
    assert.throws(() => validateDate(date), /date|YYYY-MM-DD/);
  }
  assert.equal(readVersionPrefix(props()), "1.2.3");
  assert.throws(
    () => readVersionPrefix(`${props()}<VersionPrefix>2.0.0</VersionPrefix>`),
    /exactly one/,
  );
});

test("changelog structure requires one leading Unreleased and unique dated versions", () => {
  assert.equal(parseChangelog(changelog()).releases[0].version, "1.2.2");
  assert.doesNotThrow(() => parseChangelog(changelog("\n")));
  assert.throws(
    () => parseChangelog("# Changelog\n"),
    /exactly one.*Unreleased/,
  );
  assert.throws(
    () => parseChangelog(`${changelog()}\n## 1.2.2 - 2026-09-02\n\n- Again.\n`),
    /Duplicate changelog version/,
  );
  assert.throws(
    () =>
      parseChangelog("# Changelog\n\n## Unreleased\n\n## v1.2.3\n\n- Bad.\n"),
    /Unsupported level-two/,
  );
  assert.throws(
    () =>
      parseChangelog(
        "# Changelog\n\n## 1.2.3 - 2026-09-22\n\n- Bad.\n\n## Unreleased\n",
      ),
    /first level-two/,
  );
});

test("fenced headings do not split exact release section boundaries", () => {
  const source = `${changelog("\n")}\n## 1.2.1 - 2026-08-01\n\nBefore.\n\n\`\`\`markdown\n## 9.9.9 - 2099-01-01\n\`\`\`\n\nAfter.\n\n## 1.2.0 - 2026-07-01\n\n- Last.\n`;
  const selected = selectVersionSection(source, "1.2.1");
  assert.match(selected.body, /9\.9\.9/);
  assert.match(selected.body, /After/);
  assert.doesNotMatch(selected.body, /- Last/);
  assert.deepEqual(
    parseChangelog(source).releases.map((release) => release.version),
    ["1.2.2", "1.2.1", "1.2.0"],
  );
});

test("prepare preserves CRLF content and opens a fresh Unreleased section", () => {
  const source = `<!-- markdownlint config -->\n${changelog()}`.replaceAll(
    "\n",
    "\r\n",
  );
  const prepared = prepareChangelog(source, "1.2.3", "2026-09-22");
  assert.ok(!/(^|[^\r])\n/.test(prepared), "all newlines remain CRLF");
  assert.match(prepared, /^<!-- markdownlint config -->\r\n/);
  assert.match(
    prepared,
    /## Unreleased\r\n\r\n## 1\.2\.3 - 2026-09-22\r\n\r\n### Changed/,
  );
  assert.match(prepared, /## 1\.2\.2 - 2026-09-01/);
  assert.equal(
    selectVersionSection(prepared, "1.2.3").body.includes("Current work"),
    true,
  );
});

test("prepare rejects empty notes or an existing version before writing", () => {
  assert.throws(
    () =>
      prepareChangelog(
        changelog("\n### Changed\n\n<!-- later -->\n"),
        "1.2.3",
        "2026-09-22",
      ),
    /no substantive/,
  );
  assert.throws(
    () => prepareChangelog(changelog(), "1.2.2", "2026-09-22"),
    /already contains/,
  );
  assert.throws(
    () =>
      prepareChangelog(
        changelog("\n[only-a-reference]: docs/guide.md\n"),
        "1.2.3",
        "2026-09-22",
      ),
    /no substantive/,
  );
  fixture((directory) => {
    writeFileSync(
      path.join(directory, "Directory.Build.props"),
      props("1.2.2"),
    );
    const target = path.join(directory, "CHANGELOG.md");
    const before = readFileSync(target, "utf8");
    assert.throws(
      () => runCli(["prepare", "--date", "2026-09-22"], directory),
      /already contains/,
    );
    assert.equal(readFileSync(target, "utf8"), before);
  });
});

test("release selection rejects missing, empty, and malformed entries", () => {
  assert.throws(() => selectVersionSection(changelog(), "1.2.3"), /found 0/);
  assert.throws(
    () =>
      selectVersionSection(
        `${changelog()}\n## 1.2.3 - 2026-09-22\n\n### Fixed\n`,
        "1.2.3",
      ),
    /no substantive/,
  );
  assert.throws(
    () =>
      selectVersionSection(
        `${changelog()}\n## 1.2.3 (2026-09-22)\n\n- Notes.\n`,
        "1.2.3",
      ),
    /Unsupported level-two/,
  );
});

test("release notes contain only the selected entry and absolute repository links", () => {
  const source = `# Changelog\n\n## Unreleased\n\n- Future.\n\n## 1.2.3 - 2026-09-22\n\n- [Guide](docs/guide.md#start)\n- [Root](#policy)\n- [Web](https://example.com/page)\n- [Reference][hosting]\n\n[hosting]: docs/setup/hosting.md "Hosting"\n\n## 1.2.2 - 2026-09-01\n\n- Earlier.\n`;
  const notes = renderReleaseNotes(source, "1.2.3", repository, sha);
  assert.match(notes, /^## 1\.2\.3 - 2026-09-22/);
  assert.match(
    notes,
    new RegExp(
      `github\\.com/Example/project/blob/${sha}/docs/guide\\.md#start`,
    ),
  );
  assert.match(
    notes,
    new RegExp(
      `github\\.com/Example/project/blob/${sha}/CHANGELOG\\.md#policy`,
    ),
  );
  assert.match(notes, /https:\/\/example\.com\/page/);
  assert.match(
    notes,
    new RegExp(
      `github\\.com/Example/project/blob/${sha}/docs/setup/hosting\\.md "Hosting"`,
    ),
  );
  assert.doesNotMatch(notes, /Future|Earlier|Unreleased/);
});

test("link conversion handles images and protects fenced examples", () => {
  const markdown = `![Diagram](art/map.png "Map"), [\`API\`](docs/backend/api.md), and \`[literal](inline.md)\`\n\n\`\`\`markdown\n[Example](relative.md)\n\`\`\`example\n[Still fenced](still-relative.md)\n\`\`\`\n`;
  const converted = absolutizeMarkdownLinks(markdown, repository, sha);
  assert.match(
    converted,
    new RegExp(`github\\.com/Example/project/blob/${sha}/art/map\\.png "Map"`),
  );
  assert.match(converted, /\[Example\]\(relative\.md\)/);
  assert.match(converted, /\[Still fenced\]\(still-relative\.md\)/);
  assert.match(converted, /`\[literal\]\(inline\.md\)`/);
  assert.ok(
    converted.includes(
      `[\`API\`](https://github.com/Example/project/blob/${sha}/docs/backend/api.md)`,
    ),
  );
  assert.equal(
    absoluteChangelogDestination("mailto:team@example.com", repository, sha),
    "mailto:team@example.com",
  );
});

test("ambiguous or unsafe Markdown destinations fail explicitly", () => {
  for (const markdown of [
    "[Angle](<docs/a file.md>)\n",
    "[Space](docs/a file.md)\n",
    "[Nested](docs/guide_(old).md)\n",
    "[Escape](../secret.md)\n",
    "[Protocol](//example.com/path)\n",
  ]) {
    assert.throws(
      () => absolutizeMarkdownLinks(markdown, repository, sha),
      /unsupported|escapes the repository/,
      markdown,
    );
  }
});

test("release notes reject references defined outside the selected entry", () => {
  const source = `# Changelog\n\n[shared]: docs/shared.md\n\n## Unreleased\n\n## 1.2.3 - 2026-09-22\n\n- Read [the shared guide][shared].\n`;
  assert.throws(
    () => renderReleaseNotes(source, "1.2.3", repository, sha),
    /missing Markdown reference definition: shared/,
  );
});

test("check --release requires the current dated substantive entry", () => {
  fixture((directory) => {
    assert.equal(runCli(["check"], directory), "Changelog is valid");
    assert.throws(() => runCli(["check", "--release"], directory), /found 0/);
    const prepared = prepareChangelog(
      readFileSync(path.join(directory, "CHANGELOG.md"), "utf8"),
      "1.2.3",
      "2026-09-22",
    );
    writeFileSync(path.join(directory, "CHANGELOG.md"), prepared);
    assert.equal(
      runCli(["check", "--release"], directory),
      "Changelog is valid",
    );
    writeFileSync(
      path.join(directory, "CHANGELOG.md"),
      prepared.replace("- Current work.", "- [Ambiguous](docs/a file.md)"),
    );
    assert.throws(
      () => runCli(["check", "--release"], directory),
      /unsupported/,
    );
    assert.throws(() => runCli(["check", "--unknown"], directory), /Usage/);
  });
});

test("notes overwrites its output while strict options reject omissions", () => {
  fixture((directory) => {
    writeFileSync(
      path.join(directory, "CHANGELOG.md"),
      prepareChangelog(changelog(), "1.2.3", "2026-09-22"),
    );
    const output = path.join(directory, "artifacts", "release", "notes.md");
    writeFileSync(path.join(directory, "old-notes.md"), "old\n");
    const existingOutput = path.join(directory, "old-notes.md");
    runCli(
      [
        "notes",
        "--repository",
        repository,
        "--source-sha",
        sha,
        "--output",
        "artifacts/release/notes.md",
      ],
      directory,
    );
    assert.match(readFileSync(output, "utf8"), /Current work/);
    runCli(
      [
        "notes",
        "--repository",
        repository,
        "--source-sha",
        sha,
        "--output",
        "old-notes.md",
      ],
      directory,
    );
    assert.match(readFileSync(existingOutput, "utf8"), /Current work/);
    assert.throws(
      () => runCli(["notes", "--repository", repository], directory),
      /Missing required option/,
    );
  });
});

test("draft invokes gh with argument arrays and records review identities", () => {
  const calls = [];
  const run = (file, arguments_, options) => {
    calls.push({ arguments_, file, options });
    if (file === "git") return `${sha}\n`;
    return JSON.stringify({ body: "## What's Changed\n\n* Fix one thing." });
  };
  const draft = buildDraft({
    previousTag: "v1.2.2",
    repository,
    root: "fixture-root",
    run,
    version: "1.2.3",
  });
  assert.deepEqual(calls[0].arguments_, ["rev-parse", "HEAD"]);
  assert.deepEqual(calls[1].arguments_, [
    "api",
    "--method",
    "POST",
    "repos/Example/project/releases/generate-notes",
    "-f",
    "tag_name=v1.2.3",
    "-f",
    `target_commitish=${sha}`,
    "-f",
    "previous_tag_name=v1.2.2",
    "-f",
    "configuration_file_path=.github/release.yml",
  ]);
  assert.equal(
    calls.every((call) => call.options.shell === undefined),
    true,
  );
  assert.match(draft, /Version: `1\.2\.3`/);
  assert.match(draft, new RegExp(`Source SHA: \`${sha}\``));
  assert.match(draft, /Previous tag: `v1\.2\.2`/);
  assert.match(draft, /Fix one thing/);
});

test("first-release draft omits previous_tag_name and refuses output overwrite", () => {
  fixture((directory) => {
    const calls = [];
    const run = (file, arguments_) => {
      calls.push({ arguments_, file });
      return file === "git"
        ? sha
        : JSON.stringify({ body: "Initial release." });
    };
    const output = path.join(directory, "artifacts", "release-draft.md");
    runCli(["draft", "--output", "artifacts/release-draft.md"], directory, run);
    assert.equal(
      calls[1].arguments_.some((argument) =>
        argument.startsWith("previous_tag_name="),
      ),
      false,
    );
    assert.match(readFileSync(output, "utf8"), /none \(first release\)/);
    assert.throws(
      () =>
        runCli(
          ["draft", "--output", "artifacts/release-draft.md"],
          directory,
          run,
        ),
      /EEXIST|exist/i,
    );
    assert.equal(calls.length, 2, "existing output fails before git or gh");
    assert.equal(existsSync(output), true);
  });
});
