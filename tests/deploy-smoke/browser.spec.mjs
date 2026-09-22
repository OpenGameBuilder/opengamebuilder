import { createRequire } from "node:module";
import os from "node:os";

import { expect, test as base } from "@playwright/test";

const require = createRequire(import.meta.url);
const playwrightVersion = require("@playwright/test/package.json").version;
const sourceRevision = process.env.EXPECTED_SOURCE_SHA;
const releaseId = process.env.EXPECTED_RELEASE_ID;

if (!/^[0-9a-f]{40}$/.test(sourceRevision ?? "")) {
  throw new Error("Playwright config did not provide EXPECTED_SOURCE_SHA");
}
if (!/^[a-zA-Z0-9][a-zA-Z0-9.-]{0,100}$/.test(releaseId ?? "")) {
  throw new Error("Playwright config did not provide EXPECTED_RELEASE_ID");
}

const releasePath = `/releases/${releaseId}/`;
const releaseIndexPath = `${releasePath}index.html`;

const test = base.extend({
  pageErrors: [
    async ({ page }, use) => {
      const errors = [];
      page.on("pageerror", (error) => errors.push(error.message));
      await use(errors);
      expect(
        errors,
        "The frontend must not raise unhandled page errors",
      ).toEqual([]);
    },
    { auto: true },
  ],
});

async function attachRuntimeEvidence(browser, browserName, testInfo) {
  await testInfo.attach("browser-and-os-versions", {
    contentType: "application/json",
    body: Buffer.from(
      `${JSON.stringify(
        {
          project: testInfo.project.name,
          browserEngine: browserName,
          browserVersion: browser.version(),
          playwrightVersion,
          operatingSystem: {
            platform: os.platform(),
            release: os.release(),
            version: os.version(),
            architecture: os.arch(),
            runnerOS: process.env.RUNNER_OS ?? null,
            runnerArchitecture: process.env.RUNNER_ARCH ?? null,
            runnerImage: process.env.ImageOS ?? null,
            runnerImageVersion: process.env.ImageVersion ?? null,
          },
        },
        null,
        2,
      )}\n`,
    ),
  });
}

test("published application starts through the release redirect and loads real assets", async ({
  baseURL,
  browser,
  browserName,
  page,
  request,
}, testInfo) => {
  await attachRuntimeEvidence(browser, browserName, testInfo);

  const alive = await request.get("/api/alive");
  expect(alive.status(), "The real API must be alive through the proxy").toBe(
    200,
  );
  const aliveBody = (await alive.text()).trim();
  expect(aliveBody).toBe("Healthy");
  await testInfo.attach("api-liveness", {
    contentType: "application/json",
    body: Buffer.from(
      `${JSON.stringify(
        { path: "/api/alive", status: alive.status(), body: aliveBody },
        null,
        2,
      )}\n`,
    ),
  });

  const root = await request.get("/");
  expect(root.status(), "The deployed root redirect page must load").toBe(200);
  expect(
    await root.text(),
    "The root page must select the expected release",
  ).toContain(releaseIndexPath);

  const responses = [];
  const failedRequests = [];
  page.on("response", (response) => responses.push(response));
  page.on("requestfailed", (request) =>
    failedRequests.push(
      `${request.method()} ${request.url()}: ${request.failure()?.errorText ?? "unknown failure"}`,
    ),
  );
  const aboutResponsePromise = page
    .waitForResponse(
      (response) => response.url() === new URL("/api/about", baseURL).href,
      { timeout: 15_000 },
    )
    .catch(() => null);

  await page.goto("/", { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(
    new RegExp(`${releaseIndexPath.replaceAll(".", "\\.")}$`),
  );
  await expect(
    page.locator("base"),
    "The release base href must match the deployed path",
  ).toHaveAttribute("href", releasePath);

  const aboutResponse = await aboutResponsePromise;
  expect(aboutResponse, "The frontend must request /api/about").not.toBeNull();
  expect(
    aboutResponse.status(),
    "The frontend /api/about request must return HTTP 200",
  ).toBe(200);
  const about = await aboutResponse.json();
  expect(
    about.sourceRevision,
    "The real API must report the expected source revision",
  ).toBe(sourceRevision);

  const expectedHeading = `${about.applicationName} ${about.version}`;
  await expect(
    page.locator("#app h1"),
    "The frontend must render API-backed heading content",
  ).toHaveText(expectedHeading);

  await expect
    .poll(
      () =>
        responses.some((response) =>
          new URL(response.url()).pathname.endsWith(".wasm"),
        ),
      { message: "The published WebAssembly runtime must load" },
    )
    .toBe(true);

  const cssResponse = responses.find(
    (response) =>
      new URL(response.url()).pathname === `${releasePath}css/app.css`,
  );
  expect(
    cssResponse?.status(),
    "The published CSS asset must load successfully",
  ).toBe(200);
  expect((await cssResponse.allHeaders())["content-type"]).toContain(
    "text/css",
  );

  const startupResponse = responses.find((response) =>
    /\/_framework\/blazor\.webassembly(?:\.[^/]+)?\.js$/.test(
      new URL(response.url()).pathname,
    ),
  );
  expect(
    startupResponse?.status(),
    "The published Blazor startup script must load successfully",
  ).toBe(200);
  expect((await startupResponse.allHeaders())["content-type"]).toContain(
    "text/javascript",
  );

  const wasmResponses = responses.filter((response) =>
    new URL(response.url()).pathname.endsWith(".wasm"),
  );
  expect(
    wasmResponses.length,
    "At least one WebAssembly asset must load",
  ).toBeGreaterThan(0);
  for (const response of wasmResponses) {
    expect(
      response.status(),
      `WebAssembly asset failed: ${response.url()}`,
    ).toBe(200);
    expect((await response.allHeaders())["content-type"]).toContain(
      "application/wasm",
    );
  }

  const failedPublishedResponses = responses
    .filter((response) => {
      const pathname = new URL(response.url()).pathname;
      return pathname.startsWith(releasePath) && !response.ok();
    })
    .map((response) => `${response.status()} ${response.url()}`);
  expect(
    failedPublishedResponses,
    "Every requested published release asset must load successfully",
  ).toEqual([]);
  expect(failedRequests, "Published release requests must not fail").toEqual(
    [],
  );
});

test("direct release index, reload, and the client not-found route match deployment routing", async ({
  page,
}) => {
  await page.goto(releaseIndexPath, { waitUntil: "domcontentloaded" });
  await expect(page.locator("#app h1")).toContainText("OpenGameBuilder");

  await page.reload({ waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(
    new RegExp(`${releaseIndexPath.replaceAll(".", "\\.")}$`),
  );
  await expect(page.locator("#app h1")).toContainText("OpenGameBuilder");

  await page.evaluate(() => globalThis.Blazor.navigateTo("not-found"));
  await expect(page).toHaveURL(new RegExp(`${releasePath}not-found$`));
  await expect(page.getByRole("heading", { name: "Not Found" })).toBeVisible();

  // The deployed edge falls back to its root redirect for a missing static
  // route, so a reload selects the active release's concrete index page.
  await page.reload({ waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(
    new RegExp(`${releaseIndexPath.replaceAll(".", "\\.")}$`),
  );
  await expect(page.locator("#app h1")).toContainText("OpenGameBuilder");
});
