# Browser and accessibility expectations

The current frontend is a Blazor WebAssembly placeholder that displays application
information from the API. There is no editor yet. This policy separates automated
engine checks from branded-browser, device, and accessibility acceptance.

## Automated engine coverage

The [published-application harness](../../tests/deploy-smoke/playwright.config.mjs)
checks the Release frontend and real API in Playwright's pinned Chromium,
Firefox, and WebKit builds. Full PR validation requires all three on Ubuntu;
documentation-only PRs run content checks. The tests cover startup, API-backed
content, expected source revision, release base path, routes/reload, asset loading,
and unhandled page errors. See [testing commands](../quality/testing.md#published-application-browser-checks)
for local setup and retained reports.

Each report records the exact engine, Playwright, OS, runner image when available,
and source versions. The automated support commitment is the current pinned
engine set exercised by these checks, maintained through dependency updates.
It is not a promise to test the previous two versions of every branded browser.

Playwright's Chromium and Firefox builds are distinct from installed Chrome,
Edge, and Firefox products. Its WebKit build is not Safari, and running WebKit
on Windows or Linux does not test macOS or iOS integration. Device emulation
likewise does not establish physical-device support. These distinctions follow
[Playwright's browser documentation](https://playwright.dev/docs/browsers).

### Recorded local engine results

On 2026-09-22, the harness passed all six tests on Windows 11 Home x64
(`10.0.26200`), with Playwright Test 1.63.0 and Node.js 22.23.2. The checkout was
`b072449fe0e2daf7f38fff353f9ef7f7dd405626` with the browser-harness changes;
the local API reported that SHA for release `pr-b072449fe0e2`.

| Playwright engine | Exact browser version | Result   |
| ----------------- | --------------------- | -------- |
| Chromium          | 153.0.8010.12         | 2 passed |
| Firefox           | 155.0                 | 2 passed |
| WebKit            | 26.6                  | 2 passed |

There were no retries, flaky passes, skipped tests, or unhandled page errors.
The generated `artifacts/browser/results.json` and HTML report contain the
per-engine OS/version attachments. CI retains equivalent reports as artifacts;
the first hosted Ubuntu run of this harness remains unverified. These local
results do not establish new live-host, branded-browser, physical-device, or
accessibility acceptance.

## Recorded deployment browser check

The [staging deployment run on 2026-09-22 UTC](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35681727268)
passed the existing [deployment smoke test](../../tests/deploy-smoke/smoke.mjs)
for source revision `e164922c19213ae1ca2936554cca3970269cfac6` and release
`35681727268-1-e164922c1921`. Its browser installation log records Playwright
Chromium build `v1243`, Chrome Headless Shell `153.0.8010.12`, on the Linux runner.

That check loads the published frontend, verifies the release URL and base path,
observes a successful `/api/about` request with the expected source revision,
checks the rendered application heading, and rejects startup page errors. It
does not check editor interactions, keyboard operation, screen readers, error
recovery, or other browser engines. It establishes live Chromium evidence for
that release only, separately from the local harness.

## Branded-browser and device targets

For each target actually checked, use the current stable version available when
the feature is accepted and record the exact browser and OS versions. Do not
mark a target tested based on another engine's result. Previous-version coverage
is aspirational until a concrete need and repeatable check exist.

| Platform | Target browsers       | Recorded status |
| -------- | --------------------- | --------------- |
| Windows  | Chrome, Edge, Firefox | Unverified      |
| macOS    | Safari                | Unverified      |
| Android  | Chrome                | Unverified      |
| iOS      | Safari                | Unverified      |

The desktop targets cover the complete implemented workflow. Mobile checks cover
loading, navigation, readable layout, and touch operation of available controls;
decide and document the intended mobile editing scope when editor controls exist.
Until these checks are recorded, browser coverage and mobile editing remain
targets, not an acceptance claim.

The current build has no Browserslist consumer. These targets are checked through
the acceptance procedure below, not selected or verified by build configuration.

## Accessibility baseline and outstanding work

A source inspection of the placeholder found the following on 2026-09-22 UTC.
These are implementation observations, not a runtime accessibility pass:

- [Route navigation](../../src/OpenGameBuilder.Web.Client/App.razor) uses
  `FocusOnNavigate` with selector `h1`; the
  [not-found page](../../src/OpenGameBuilder.Web.Client/Pages/NotFound.razor) has
  only an `h3`, so it has no matching focus target.
- The [home page](../../src/OpenGameBuilder.Web.Client/Pages/Home.razor.cs)
  changes its heading from loading to success or an HTTP-failure message. It has
  no explicit live region or retry control; announcements and recovery have not
  been tested.
- The [startup page](../../src/OpenGameBuilder.Web.Client/wwwroot/index.html)
  provides a loading SVG and CSS-generated loading text without an explicit live
  region. Its unhandled-error UI has a reload link, but its dismiss control is a
  `span` without keyboard or button semantics in the markup.

Resolve these gaps with the first functional frontend feature.
There is currently no recorded keyboard, focus, or screen-reader acceptance, and
no claim of accessibility conformance.

## Acceptance procedure for the first feature and later editor work

Use the published build of the revision under review. Extend the local harness
with a meaningful user action and visible result when an interactive feature
exists. Keep the deployment smoke focused on live startup and API checks; add component coverage
for the feature's loading, success, expected failure, and invalid-response states
as described in [testing guidance](../quality/testing.md). Record manual checks
separately from automated results.

| Check                   | Procedure and required result                                                                                                                                                                                                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Startup and API         | In each browser target, load and reload the published page, follow a route, and verify the expected API-backed content without unhandled page errors.                                                                                                                                                   |
| Keyboard                | On desktop, complete every implemented workflow using Tab, Shift+Tab, Enter, Space, and the controls' documented keys. Every action must be reachable, focus visible and ordered, and no control may trap focus. Provide a keyboard alternative for any editor action that otherwise requires dragging. |
| Focus                   | Navigate between routes, including not-found; open and close any dialogs or menus. Verify a useful destination receives focus, dismissal returns focus to the invoking control, and asynchronous updates do not steal focus.                                                                            |
| Loading and failures    | Throttle loading, interrupt the API request, and supply an invalid response in a controlled test. Verify loading and errors are understandable and announced, recovery is reachable with keyboard and touch, and retry or reload restores a usable state. Check the unhandled-error controls too.       |
| Screen reader           | Check Windows with NVDA and Chrome, Edge, and Firefox; macOS and iOS with VoiceOver and Safari; Android with TalkBack and Chrome. Verify headings, control names and states, loading/error announcements, navigation, and the available workflow.                                                       |
| Mobile layout and touch | On Android and iOS devices, check portrait and landscape layouts, navigation, and available controls. Verify essential content and actions remain reachable without accidental activation; record any explicitly unsupported editor operations.                                                         |

For each result, record the date, revision or release, URL, browser and OS versions,
device/input method, screen-reader version when used, steps, and pass/fail or
unverified status in the feature's PR or a linked test record. Link failures to
the work needed before accepting the affected target. Browser automation does not
replace keyboard, assistive-technology, or physical-device checks. Extend the
matrix with concrete editor workflows as those features arrive rather than
claiming coverage for controls that do not yet exist.
