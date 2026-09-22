import { execFileSync } from "node:child_process";
import {
  constants,
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const versionPattern = "(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)";
const versionRegex = new RegExp(`^${versionPattern}$`);
const releaseHeadingRegex = new RegExp(
  `^## (${versionPattern}) - (\\d{4}-\\d{2}-\\d{2})$`,
);
const fullShaRegex = /^[0-9a-f]{40}$/i;
const repositoryRegex = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

function fail(message) {
  throw new Error(message);
}

export function validateVersion(version, label = "version") {
  if (!versionRegex.test(version)) {
    fail(`${label} must be a plain semantic version (X.Y.Z): ${version}`);
  }
  return version;
}

export function validateDate(date, label = "date") {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    fail(`${label} must use YYYY-MM-DD: ${date}`);
  }
  const parsed = new Date(`${date}T00:00:00Z`);
  if (
    Number.isNaN(parsed.valueOf()) ||
    parsed.toISOString().slice(0, 10) !== date
  ) {
    fail(`${label} is not a valid calendar date: ${date}`);
  }
  return date;
}

export function readVersionPrefix(source) {
  const matches = [
    ...source.matchAll(/<VersionPrefix>\s*([^<]+?)\s*<\/VersionPrefix>/g),
  ];
  if (matches.length !== 1) {
    fail(
      `Directory.Build.props must contain exactly one VersionPrefix; found ${matches.length}`,
    );
  }
  return validateVersion(matches[0][1].trim(), "VersionPrefix");
}

function scanLevelTwoHeadings(source) {
  const headings = [];
  let fence;
  let offset = 0;

  for (const lineWithEnding of source.match(/.*(?:\r\n|\n|$)/g) ?? []) {
    if (lineWithEnding === "") break;
    const line = lineWithEnding.replace(/\r?\n$/, "");
    const fenceMatch = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (fenceMatch) {
      const marker = fenceMatch[1];
      if (!fence) {
        fence = { character: marker[0], length: marker.length };
      } else if (
        marker[0] === fence.character &&
        marker.length >= fence.length &&
        new RegExp(`^ {0,3}${fence.character}{${fence.length},}\\s*$`).test(
          line,
        )
      ) {
        fence = undefined;
      }
    } else if (!fence && /^##(?:\s|$)/.test(line)) {
      headings.push({
        heading: line,
        lineEnd: offset + line.length,
        start: offset,
      });
    }
    offset += lineWithEnding.length;
  }

  return headings;
}

export function isSubstantive(body) {
  const withoutComments = body.replace(/<!--[\s\S]*?-->/g, "");
  return withoutComments.split(/\r?\n/).some((line) => {
    const trimmed = line.trim();
    return (
      trimmed !== "" &&
      !/^#{1,6}(?:\s|$)/.test(trimmed) &&
      !/^(?:[-*_]\s*){3,}$/.test(trimmed) &&
      !/^(?:[-+*]|\d+[.)])\s*$/.test(trimmed) &&
      !/^(`{3,}|~{3,})/.test(trimmed) &&
      !/^\[[^\]]+\]:/.test(trimmed)
    );
  });
}

export function parseChangelog(source) {
  const headings = scanLevelTwoHeadings(source);
  const sections = headings.map((item, index) => ({
    ...item,
    bodyEnd: headings[index + 1]?.start ?? source.length,
    bodyStart: item.lineEnd,
  }));
  const unreleased = sections.filter(
    (section) => section.heading === "## Unreleased",
  );
  if (unreleased.length !== 1) {
    fail(
      `CHANGELOG.md must contain exactly one "## Unreleased" heading; found ${unreleased.length}`,
    );
  }
  if (sections[0] !== unreleased[0]) {
    fail('"## Unreleased" must be the first level-two heading in CHANGELOG.md');
  }

  const releases = [];
  const versions = new Set();
  for (const section of sections) {
    if (section === unreleased[0]) continue;
    const match = section.heading.match(releaseHeadingRegex);
    if (!match) {
      fail(
        `Unsupported level-two changelog heading: ${section.heading}. Expected "## X.Y.Z - YYYY-MM-DD"`,
      );
    }
    const [, version, date] = match;
    validateVersion(version);
    validateDate(date, `date for ${version}`);
    if (versions.has(version)) {
      fail(`Duplicate changelog version: ${version}`);
    }
    versions.add(version);
    releases.push({ ...section, date, version });
  }

  return { releases, sections, unreleased: unreleased[0] };
}

export function prepareChangelog(source, version, date) {
  validateVersion(version);
  validateDate(date);
  const changelog = parseChangelog(source);
  if (changelog.releases.some((release) => release.version === version)) {
    fail(`CHANGELOG.md already contains version ${version}`);
  }
  const unreleasedBody = source.slice(
    changelog.unreleased.bodyStart,
    changelog.unreleased.bodyEnd,
  );
  if (!isSubstantive(unreleasedBody)) {
    fail("The Unreleased section has no substantive release notes");
  }
  const newline = source.includes("\r\n") ? "\r\n" : "\n";
  const replacement = `## Unreleased${newline}${newline}## ${version} - ${date}`;
  return (
    source.slice(0, changelog.unreleased.start) +
    replacement +
    source.slice(changelog.unreleased.lineEnd)
  );
}

export function selectVersionSection(source, version) {
  validateVersion(version);
  const changelog = parseChangelog(source);
  const matches = changelog.releases.filter(
    (release) => release.version === version,
  );
  if (matches.length !== 1) {
    fail(
      `CHANGELOG.md must contain exactly one dated entry for VersionPrefix ${version}; found ${matches.length}`,
    );
  }
  const release = matches[0];
  const body = source.slice(release.bodyStart, release.bodyEnd);
  if (!isSubstantive(body)) {
    fail(`Changelog entry ${version} has no substantive release notes`);
  }
  return { ...release, body };
}

function validateRepository(repository) {
  if (!repositoryRegex.test(repository)) {
    fail(`repository must use OWNER/REPO: ${repository}`);
  }
  return repository;
}

function splitLocalDestination(raw) {
  if (raw.startsWith("<")) {
    fail(`Angle-bracket Markdown link destinations are unsupported: ${raw}`);
  }
  const match = raw.match(/^(\S+?)(\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\s*$/);
  if (!match) {
    fail(`Ambiguous Markdown link destination is unsupported: ${raw}`);
  }
  return { destination: match[1], title: match[2] ?? "" };
}

export function absoluteChangelogDestination(
  destination,
  repository,
  sourceSha,
) {
  validateRepository(repository);
  if (!fullShaRegex.test(sourceSha)) {
    fail(`source SHA must be a full 40-character commit SHA: ${sourceSha}`);
  }
  if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(destination)) return destination;
  if (destination.startsWith("//")) {
    fail(`Protocol-relative Markdown links are unsupported: ${destination}`);
  }

  const [pathAndQuery, fragment] = destination.split(/#(.*)/s, 2);
  const [pathname, query] = pathAndQuery.split(/\?(.*)/s, 2);
  const localPath = pathname === "" ? "CHANGELOG.md" : pathname;
  if (localPath.startsWith("/") || localPath.includes("\\")) {
    fail(
      `Repository link must be a forward-slash relative path: ${destination}`,
    );
  }
  const normalized = path.posix.normalize(localPath);
  if (normalized === ".." || normalized.startsWith("../")) {
    fail(`Repository link escapes the repository: ${destination}`);
  }
  const encodedPath = normalized
    .split("/")
    .map((segment) => encodeURIComponent(decodeURIComponent(segment)))
    .join("/");
  let result = `https://github.com/${repository}/blob/${sourceSha}/${encodedPath}`;
  if (query !== undefined) result += `?${query}`;
  if (fragment !== undefined) result += `#${fragment}`;
  return result;
}

function rewriteMarkdownLine(line, repository, sourceSha) {
  const reference = line.match(/^(\s{0,3}\[[^\]]+\]:\s*)(.*)$/);
  if (reference) {
    const { destination, title } = splitLocalDestination(reference[2]);
    const converted = absoluteChangelogDestination(
      destination,
      repository,
      sourceSha,
    );
    return `${reference[1]}${converted}${title}`;
  }

  const codeRanges = [...line.matchAll(/(`+)(.*?)\1/g)].map((match) => [
    match.index,
    match.index + match[0].length,
  ]);
  let result = "";
  let cursor = 0;
  const opening = /!?\[[^\]\n]+\]\(/g;
  for (let match = opening.exec(line); match; match = opening.exec(line)) {
    if (
      codeRanges.some(
        ([start, end]) => match.index >= start && match.index < end,
      )
    ) {
      continue;
    }
    const destinationStart = opening.lastIndex;
    const closing = line.indexOf(")", destinationStart);
    if (closing < 0) {
      fail(`Unclosed Markdown link is unsupported: ${line.trim()}`);
    }
    const raw = line.slice(destinationStart, closing);
    if (raw.includes("(")) {
      fail(`Parenthesized Markdown link destinations are unsupported: ${raw}`);
    }
    const { destination, title } = splitLocalDestination(raw);
    const converted = absoluteChangelogDestination(
      destination,
      repository,
      sourceSha,
    );
    result += line.slice(cursor, destinationStart) + converted + title + ")";
    cursor = closing + 1;
    opening.lastIndex = closing + 1;
  }
  return result + line.slice(cursor);
}

function normalizeReference(label) {
  return label.trim().replace(/\s+/g, " ").toLowerCase();
}

function validateReferenceLinks(markdown) {
  const definitions = new Set();
  const uses = [];
  let fence;
  for (const line of markdown.split(/\r?\n/)) {
    const fenceMatch = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (fenceMatch) {
      const marker = fenceMatch[1];
      if (!fence) {
        fence = { character: marker[0], length: marker.length };
      } else if (
        marker[0] === fence.character &&
        marker.length >= fence.length &&
        line.slice(fenceMatch[0].length).trim() === ""
      ) {
        fence = undefined;
      }
      continue;
    }
    if (fence) continue;
    const withoutCode = line.replace(/(`+)(.*?)\1/g, "");
    const definition = withoutCode.match(/^\s{0,3}\[([^\]]+)\]:\s*\S+/);
    if (definition) {
      const key = normalizeReference(definition[1]);
      if (definitions.has(key)) {
        fail(`Duplicate Markdown reference definition: ${definition[1]}`);
      }
      definitions.add(key);
      continue;
    }
    for (const match of withoutCode.matchAll(/!?\[([^\]]+)\]\[([^\]]*)\]/g)) {
      uses.push({
        key: normalizeReference(match[2] || match[1]),
        label: match[2] || match[1],
      });
    }
  }
  for (const use of uses) {
    if (!definitions.has(use.key)) {
      fail(
        `Selected changelog entry is missing Markdown reference definition: ${use.label}`,
      );
    }
  }
}

export function absolutizeMarkdownLinks(markdown, repository, sourceSha) {
  validateRepository(repository);
  if (!fullShaRegex.test(sourceSha)) {
    fail(`source SHA must be a full 40-character commit SHA: ${sourceSha}`);
  }
  let fence;
  return markdown
    .split(/(?<=\n)/)
    .map((lineWithEnding) => {
      const ending = lineWithEnding.endsWith("\n") ? "\n" : "";
      const line = lineWithEnding.replace(/\r?\n$/, "");
      const fenceMatch = line.match(/^ {0,3}(`{3,}|~{3,})/);
      if (fenceMatch) {
        const marker = fenceMatch[1];
        if (!fence) {
          fence = { character: marker[0], length: marker.length };
        } else if (
          marker[0] === fence.character &&
          marker.length >= fence.length &&
          line.slice(fenceMatch[0].length).trim() === ""
        ) {
          fence = undefined;
        }
        return line + ending;
      }
      return (
        (fence ? line : rewriteMarkdownLine(line, repository, sourceSha)) +
        ending
      );
    })
    .join("");
}

export function renderReleaseNotes(source, version, repository, sourceSha) {
  const release = selectVersionSection(source, version);
  validateReferenceLinks(release.body);
  const body = release.body.trim();
  const markdown = `## ${release.version} - ${release.date}\n\n${body}\n`;
  return absolutizeMarkdownLinks(markdown, repository, sourceSha);
}

export function buildDraft({
  previousTag,
  repository = "OpenGameBuilder/opengamebuilder",
  root = process.cwd(),
  run = execFileSync,
  version,
}) {
  validateVersion(version);
  validateRepository(repository);
  if (previousTag !== undefined) {
    const previousVersion = previousTag.match(/^v(.+)$/)?.[1];
    if (!previousVersion) fail(`previous tag must use vX.Y.Z: ${previousTag}`);
    validateVersion(previousVersion, "previous tag");
  }
  const sourceSha = String(
    run("git", ["rev-parse", "HEAD"], {
      cwd: root,
      encoding: "utf8",
    }),
  ).trim();
  if (!fullShaRegex.test(sourceSha)) {
    fail(`git rev-parse HEAD did not return a full commit SHA: ${sourceSha}`);
  }
  const arguments_ = [
    "api",
    "--method",
    "POST",
    `repos/${repository}/releases/generate-notes`,
    "-f",
    `tag_name=v${version}`,
    "-f",
    `target_commitish=${sourceSha}`,
  ];
  if (previousTag !== undefined) {
    arguments_.push("-f", `previous_tag_name=${previousTag}`);
  }
  arguments_.push("-f", "configuration_file_path=.github/release.yml");
  const response = String(
    run("gh", arguments_, { cwd: root, encoding: "utf8" }),
  );
  let generated;
  try {
    generated = JSON.parse(response);
  } catch {
    fail("gh api returned invalid JSON while generating release notes");
  }
  if (typeof generated.body !== "string" || generated.body.trim() === "") {
    fail("gh api returned no generated release-note body");
  }
  const base = previousTag ?? "none (first release)";
  return `# Draft release v${version}\n\n- Version: \`${version}\`\n- Source SHA: \`${sourceSha}\`\n- Previous tag: \`${base}\`\n\n## Generated notes\n\n${generated.body.trim()}\n`;
}

function parseOptions(arguments_, allowed, required = allowed) {
  const options = {};
  for (let index = 0; index < arguments_.length; index += 2) {
    const option = arguments_[index];
    const value = arguments_[index + 1];
    if (
      !option?.startsWith("--") ||
      value === undefined ||
      value.startsWith("--")
    ) {
      fail(
        `Expected an option and value, received: ${arguments_.slice(index).join(" ")}`,
      );
    }
    const name = option.slice(2);
    if (!allowed.includes(name)) fail(`Unknown option: ${option}`);
    if (options[name] !== undefined) fail(`Duplicate option: ${option}`);
    options[name] = value;
  }
  for (const name of required) {
    if (options[name] === undefined) fail(`Missing required option: --${name}`);
  }
  return options;
}

export function runCli(arguments_, root = process.cwd(), run = execFileSync) {
  const [command, ...rest] = arguments_;
  const changelogPath = path.join(root, "CHANGELOG.md");
  const propsPath = path.join(root, "Directory.Build.props");
  if (command === "check") {
    if (rest.length > 1 || (rest.length === 1 && rest[0] !== "--release")) {
      fail("Usage: changelog.mjs check [--release]");
    }
    const source = readFileSync(changelogPath, "utf8");
    parseChangelog(source);
    if (rest[0] === "--release") {
      const version = readVersionPrefix(readFileSync(propsPath, "utf8"));
      renderReleaseNotes(
        source,
        version,
        "OpenGameBuilder/opengamebuilder",
        "0".repeat(40),
      );
    }
    return "Changelog is valid";
  }
  if (command === "prepare") {
    const options = parseOptions(rest, ["date"]);
    const source = readFileSync(changelogPath, "utf8");
    const version = readVersionPrefix(readFileSync(propsPath, "utf8"));
    const prepared = prepareChangelog(source, version, options.date);
    writeFileSync(changelogPath, prepared);
    return `Prepared changelog entry ${version}`;
  }
  if (command === "notes") {
    const options = parseOptions(rest, ["repository", "source-sha", "output"]);
    const version = readVersionPrefix(readFileSync(propsPath, "utf8"));
    const notes = renderReleaseNotes(
      readFileSync(changelogPath, "utf8"),
      version,
      options.repository,
      options["source-sha"],
    );
    const output = path.resolve(root, options.output);
    mkdirSync(path.dirname(output), { recursive: true });
    writeFileSync(output, notes);
    return `Wrote curated release notes for ${version}`;
  }
  if (command === "draft") {
    const options = parseOptions(
      rest,
      ["previous-tag", "output", "repository"],
      ["output"],
    );
    const version = readVersionPrefix(readFileSync(propsPath, "utf8"));
    const output = path.resolve(root, options.output);
    if (existsSync(output)) fail(`Draft output already exists: ${output}`);
    mkdirSync(path.dirname(output), { recursive: true });
    const draft = buildDraft({
      previousTag: options["previous-tag"],
      repository: options.repository,
      root,
      run,
      version,
    });
    writeFileSync(output, draft, {
      flag: "wx",
      mode: constants.S_IRUSR | constants.S_IWUSR,
    });
    return `Wrote generated release draft for ${version}`;
  }
  fail(
    "Usage: changelog.mjs <check [--release]|prepare --date DATE|notes --repository OWNER/REPO --source-sha SHA --output PATH|draft --output PATH [--previous-tag TAG] [--repository OWNER/REPO]>",
  );
}

const isMain = process.argv[1]
  ? path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
  : false;
if (isMain) {
  try {
    console.log(runCli(process.argv.slice(2)));
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
