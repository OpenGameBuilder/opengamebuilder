import { execFileSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { defineConfig, devices } from "@playwright/test";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(testDirectory, "../..");
const artifactsDirectory = path.join(repositoryRoot, "artifacts");
const webPublishDirectory = path.join(artifactsDirectory, "web", "wwwroot");
const apiAssembly = path.join(
  artifactsDirectory,
  "browser-api",
  "OpenGameBuilder.Api.dll",
);
const browserSiteDirectory = path.join(artifactsDirectory, "browser-site");

const sourceRevision = (
  process.env.EXPECTED_SOURCE_SHA ??
  execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: repositoryRoot,
    encoding: "utf8",
  })
).trim();
if (!/^[0-9a-f]{40}$/.test(sourceRevision)) {
  throw new Error("EXPECTED_SOURCE_SHA must be a full lowercase Git SHA");
}

const releaseId =
  process.env.EXPECTED_RELEASE_ID ?? `pr-${sourceRevision.slice(0, 12)}`;
if (!/^[a-zA-Z0-9][a-zA-Z0-9.-]{0,100}$/.test(releaseId)) {
  throw new Error("EXPECTED_RELEASE_ID is not a valid release identifier");
}
process.env.EXPECTED_SOURCE_SHA = sourceRevision;
process.env.EXPECTED_RELEASE_ID = releaseId;

function parsePort(name, fallback) {
  const value = Number.parseInt(process.env[name] ?? String(fallback), 10);
  if (!Number.isInteger(value) || value < 1024 || value > 65535) {
    throw new Error(`${name} must be a port from 1024 through 65535`);
  }
  return value;
}

const apiPort = parsePort("BROWSER_API_PORT", 4173);
const webPort = parsePort("BROWSER_WEB_PORT", 4174);
if (apiPort === webPort) {
  throw new Error("BROWSER_API_PORT and BROWSER_WEB_PORT must differ");
}

const reportSubdirectory = process.env.BROWSER_HARNESS_REPORT_SUBDIR ?? "";
if (
  reportSubdirectory &&
  (!/^[a-zA-Z0-9][a-zA-Z0-9./-]*$/.test(reportSubdirectory) ||
    reportSubdirectory
      .split("/")
      .some((segment) => !segment || segment === "." || segment === ".."))
) {
  throw new Error("BROWSER_HARNESS_REPORT_SUBDIR is not a safe relative path");
}

const browserArtifactsRoot = path.join(artifactsDirectory, "browser");
const browserArtifacts = path.resolve(
  browserArtifactsRoot,
  reportSubdirectory || ".",
);
if (
  browserArtifacts !== browserArtifactsRoot &&
  !browserArtifacts.startsWith(`${browserArtifactsRoot}${path.sep}`)
) {
  throw new Error("Browser report path escapes artifacts/browser");
}
const baseURL = `http://127.0.0.1:${webPort}`;
const apiURL = `http://127.0.0.1:${apiPort}`;

export default defineConfig({
  testDir: testDirectory,
  testMatch: "browser.spec.mjs",
  outputDir: path.join(browserArtifacts, "test-results"),
  forbidOnly: true,
  failOnFlakyTests: true,
  fullyParallel: false,
  workers: 1,
  retries: 1,
  timeout: 60_000,
  expect: { timeout: 30_000 },
  metadata: {
    sourceRevision,
    releaseId,
    operatingSystem: `${os.platform()} ${os.release()} (${os.arch()})`,
  },
  reporter: [
    ["list"],
    [
      "html",
      {
        outputFolder: path.join(browserArtifacts, "html-report"),
        open: "never",
      },
    ],
    ["json", { outputFile: path.join(browserArtifacts, "results.json") }],
  ],
  use: {
    baseURL,
    headless: true,
    navigationTimeout: 30_000,
    actionTimeout: 15_000,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
  ],
  webServer: [
    {
      name: "published-api",
      command: "dotnet OpenGameBuilder.Api.dll",
      cwd: path.dirname(apiAssembly),
      env: {
        ...process.env,
        DOTNET_ENVIRONMENT: "Production",
        ASPNETCORE_ENVIRONMENT: "Production",
        ASPNETCORE_URLS: apiURL,
        SOURCE_SHA: sourceRevision,
        ReverseProxy__KnownNetworks: "127.0.0.0/8;::1/128",
      },
      wait: { stdout: /Now listening on:/ },
      reuseExistingServer: false,
      timeout: 60_000,
      stdout: "pipe",
      stderr: "pipe",
    },
    {
      name: "release-site",
      command: "node local-server.mjs",
      cwd: testDirectory,
      env: {
        ...process.env,
        BROWSER_API_URL: apiURL,
        BROWSER_SITE_URL: baseURL,
        BROWSER_REPOSITORY_ROOT: repositoryRoot,
        BROWSER_WEB_PUBLISH_DIRECTORY: webPublishDirectory,
        BROWSER_SITE_DIRECTORY: browserSiteDirectory,
        EXPECTED_RELEASE_ID: releaseId,
      },
      url: baseURL,
      reuseExistingServer: false,
      timeout: 30_000,
      stdout: "pipe",
      stderr: "pipe",
    },
  ],
});
