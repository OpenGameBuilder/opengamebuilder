import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(testDirectory, "../..");
const cli = path.join(
  testDirectory,
  "node_modules",
  "@playwright",
  "test",
  "cli.js",
);
const config = path.join(testDirectory, "playwright.config.mjs");
const browserArtifacts = path.join(repositoryRoot, "artifacts", "browser");

const faults = [
  {
    name: "wrong-api-route",
    diagnostic: "The frontend /api/about request must return HTTP 200",
  },
  {
    name: "wrong-base",
    diagnostic: "The release base href must match the deployed path",
  },
  {
    name: "missing-asset",
    diagnostic: "The published CSS asset must load successfully",
  },
  {
    name: "unusable-frontend",
    diagnostic: "The frontend must request /api/about",
  },
];

function collectTests(suites) {
  return suites.flatMap((suite) => [
    ...(suite.specs ?? []).flatMap((spec) => spec.tests ?? []),
    ...collectTests(suite.suites ?? []),
  ]);
}

for (const [index, fault] of faults.entries()) {
  const apiPort = 4273 + index * 2;
  const webPort = apiPort + 1;
  const result = spawnSync(
    process.execPath,
    [
      cli,
      "test",
      "--config",
      config,
      "--project=chromium",
      "--grep=published application starts",
      "--retries=0",
    ],
    {
      cwd: repositoryRoot,
      encoding: "utf8",
      timeout: 120_000,
      maxBuffer: 4 * 1024 * 1024,
      env: {
        ...process.env,
        BROWSER_API_PORT: String(apiPort),
        BROWSER_WEB_PORT: String(webPort),
        BROWSER_HARNESS_FAULT: fault.name,
        BROWSER_HARNESS_REPORT_SUBDIR: `negative/${fault.name}`,
      },
    },
  );

  const reportDirectory = path.join(browserArtifacts, "negative", fault.name);
  await mkdir(reportDirectory, { recursive: true });
  const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
  await writeFile(
    path.join(reportDirectory, "run.log"),
    `fault=${fault.name}\nexit=${result.status ?? "none"}\nsignal=${result.signal ?? "none"}\n\n--- stdout ---\n${result.stdout ?? ""}\n--- stderr ---\n${result.stderr ?? ""}`,
  );

  if (result.error) throw result.error;
  assert.notEqual(
    result.status,
    0,
    `${fault.name} unexpectedly passed even though the API remained alive`,
  );
  const report = JSON.parse(
    await readFile(path.join(reportDirectory, "results.json"), "utf8"),
  );
  const tests = collectTests(report.suites ?? []);
  assert.equal(tests.length, 1, `${fault.name} must run exactly one test`);
  assert.equal(report.stats?.unexpected, 1, `${fault.name} must be unexpected`);
  assert.equal(report.stats?.expected, 0, `${fault.name} must not pass`);
  assert.equal(report.stats?.flaky, 0, `${fault.name} must not be flaky`);

  const [reportedTest] = tests;
  assert.equal(reportedTest.projectName, "chromium");
  assert.equal(reportedTest.status, "unexpected");
  assert.equal(reportedTest.results?.length, 1);
  const [testResult] = reportedTest.results;
  assert.equal(testResult.status, "failed");

  const errorMessages = (testResult.errors ?? [])
    .map((error) => error.message ?? "")
    .join("\n");
  assert.ok(
    errorMessages.includes(fault.diagnostic),
    `${fault.name} failed for an unexpected reason:\n${errorMessages}\nRunner output:\n${output}`,
  );

  const livenessAttachment = (testResult.attachments ?? []).find(
    (attachment) => attachment.name === "api-liveness",
  );
  assert.ok(
    livenessAttachment?.body,
    `${fault.name} lacks API liveness evidence`,
  );
  const liveness = JSON.parse(
    Buffer.from(livenessAttachment.body, "base64").toString("utf8"),
  );
  assert.deepEqual(liveness, {
    path: "/api/alive",
    status: 200,
    body: "Healthy",
  });
  console.log(`PASS ${fault.name}: ${fault.diagnostic}`);
}
