# Browser and accessibility expectations

The current frontend is a Blazor WebAssembly placeholder that displays application
information from the API. There is no editor yet. This policy separates recorded
checks from the browser and accessibility targets to verify with the first
functional frontend feature.

## Recorded browser check

The [staging deployment run on 2026-09-22 UTC](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35681727268)
passed the existing [deployment smoke test](../../tests/deploy-smoke/smoke.mjs)
for source revision `e164922c19213ae1ca2936554cca3970269cfac6` and release
`35681727268-1-e164922c1921`. Its browser installation log records Playwright
Chromium build `v1243`, Chrome Headless Shell `153.0.8010.12`, on the Linux runner.

That check loads the published frontend, verifies the release URL and base path,
observes a successful `/api/about` request with the expected source revision,
checks the rendered application heading, and rejects startup page errors. It
does not check editor interactions, keyboard operation, screen readers, error
recovery, or other browser engines. This is the only recorded browser baseline
here; it does not establish support for the targets below.

## Browser targets

For each target, check the latest two stable major versions available when the
feature is accepted. Record exact browser and operating-system versions; do not
mark a target tested based on another browser's result.

| Platform | Target browsers | Recorded status |
| --- | --- | --- |
| Windows | Chrome, Edge, Firefox | Unverified |
| macOS | Safari | Unverified |
| Android | Chrome | Unverified |
| iOS | Safari | Unverified |

The desktop targets cover the complete implemented workflow. Mobile checks cover
loading, navigation, readable layout, and touch operation of available controls;
decide and document the intended mobile editing scope when editor controls exist.
Until these checks are recorded, browser coverage and mobile editing remain
targets, not an acceptance claim.

This matrix is the browser policy. The current build has no Browserslist consumer;
browser targets are checked through the acceptance procedure below, not selected
or verified by build configuration.

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

Use the published build of the revision under review. Reuse and extend the
existing deployment smoke test for startup and API checks; add component coverage
for the feature's loading, success, expected failure, and invalid-response states
as described in [testing guidance](../quality/testing.md). Record manual checks
separately from automated results.

| Check | Procedure and required result |
| --- | --- |
| Startup and API | In each browser target, load and reload the published page, follow a route, and verify the expected API-backed content without unhandled page errors. |
| Keyboard | On desktop, complete every implemented workflow using Tab, Shift+Tab, Enter, Space, and the controls' documented keys. Every action must be reachable, focus visible and ordered, and no control may trap focus. Provide a keyboard alternative for any editor action that otherwise requires dragging. |
| Focus | Navigate between routes, including not-found; open and close any dialogs or menus. Verify a useful destination receives focus, dismissal returns focus to the invoking control, and asynchronous updates do not steal focus. |
| Loading and failures | Throttle loading, interrupt the API request, and supply an invalid response in a controlled test. Verify loading and errors are understandable and announced, recovery is reachable with keyboard and touch, and retry or reload restores a usable state. Check the unhandled-error controls too. |
| Screen reader | Check Windows with NVDA and Chrome, Edge, and Firefox; macOS and iOS with VoiceOver and Safari; Android with TalkBack and Chrome. Verify headings, control names and states, loading/error announcements, navigation, and the available workflow. |
| Mobile layout and touch | On Android and iOS devices, check portrait and landscape layouts, navigation, and available controls. Verify essential content and actions remain reachable without accidental activation; record any explicitly unsupported editor operations. |

For each result, record the date, revision or release, URL, browser and OS versions,
device/input method, screen-reader version when used, steps, and pass/fail or
unverified status in the feature's PR or a linked test record. Link failures to
the work needed before accepting the affected target. Browser automation does not
replace keyboard, assistive-technology, or physical-device checks. Extend the
matrix with concrete editor workflows as those features arrive rather than
claiming coverage for controls that do not yet exist.
