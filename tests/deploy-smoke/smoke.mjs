import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const baseUrl = process.env.SMOKE_TEST_BASE_URL?.replace(/\/$/, '');
const expectedRevision = process.env.EXPECTED_SOURCE_SHA;
const expectedReleaseId = process.env.EXPECTED_RELEASE_ID;

assert.match(baseUrl ?? '', /^https:\/\//, 'A public HTTPS smoke URL is required');
assert.match(expectedRevision ?? '', /^[0-9a-f]{40}$/, 'Expected source revision is required');
assert.match(expectedReleaseId ?? '', /^[a-zA-Z0-9][a-zA-Z0-9.-]{0,100}$/, 'Expected release ID is required');

const origin = new URL(baseUrl).origin;
const expectedPage = `${origin}/releases/${expectedReleaseId}/`;
const browser = await chromium.launch();
try {
  let lastError;
  for (let attempt = 1; attempt <= 6; attempt++) {
    const context = await browser.newContext();
    const page = await context.newPage();
    const pageErrors = [];
    page.on('pageerror', error => pageErrors.push(error.message));
    try {
      const aboutResponsePromise = page.waitForResponse(
        response => response.url() === `${origin}/api/about`,
        { timeout: 30000 },
      );
      aboutResponsePromise.catch(() => {});
      await page.goto(`${baseUrl}/`, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForURL(expectedPage, { timeout: 30000 });
      const aboutResponse = await aboutResponsePromise;
      assert.equal(aboutResponse.status(), 200, 'The page must successfully call /api/about');
      const about = await aboutResponse.json();
      assert.equal(about.sourceRevision, expectedRevision, 'The running API must match the requested source revision');
      assert.equal(await page.locator('base').getAttribute('href'), `/releases/${expectedReleaseId}/`);
      const title = `${about.applicationName} ${about.version}`;
      await page.waitForFunction(
        expected => document.querySelector('#app h1')?.textContent?.includes(expected),
        title,
        { timeout: 30000 },
      );
      assert.deepEqual(pageErrors, [], 'The frontend must start without page errors');
      console.log(`PASS ${expectedReleaseId}: frontend rendered ${title} using API ${expectedRevision}`);
      process.exitCode = 0;
      lastError = undefined;
      break;
    } catch (error) {
      lastError = error;
      console.error(`Smoke attempt ${attempt}/6 failed: ${error.message}`);
      if (pageErrors.length > 0) console.error(`Browser errors: ${pageErrors.join('; ')}`);
      if (attempt < 6) await new Promise(resolve => setTimeout(resolve, 5000));
    } finally {
      await context.close();
    }
  }
  if (lastError) throw lastError;
} finally {
  await browser.close();
}
