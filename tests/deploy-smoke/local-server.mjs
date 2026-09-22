import assert from "node:assert/strict";
import { createReadStream } from "node:fs";
import { cp, mkdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import http from "node:http";
import path from "node:path";

const releaseId = process.env.EXPECTED_RELEASE_ID;
const repositoryRoot = path.resolve(process.env.BROWSER_REPOSITORY_ROOT ?? "");
const sourceDirectory = path.resolve(
  process.env.BROWSER_WEB_PUBLISH_DIRECTORY ?? "",
);
const siteDirectory = path.resolve(process.env.BROWSER_SITE_DIRECTORY ?? "");
const siteURL = new URL(process.env.BROWSER_SITE_URL ?? "");
const apiURL = new URL(process.env.BROWSER_API_URL ?? "");
const fault = process.env.BROWSER_HARNESS_FAULT ?? "none";
const supportedFaults = new Set([
  "none",
  "wrong-api-route",
  "wrong-base",
  "missing-asset",
  "unusable-frontend",
]);

assert.match(
  releaseId ?? "",
  /^[a-zA-Z0-9][a-zA-Z0-9.-]{0,100}$/,
  "EXPECTED_RELEASE_ID is required",
);
assert.equal(siteURL.protocol, "http:", "BROWSER_SITE_URL must use HTTP");
assert.equal(siteURL.hostname, "127.0.0.1", "The site must bind to loopback");
assert.equal(apiURL.protocol, "http:", "BROWSER_API_URL must use HTTP");
assert.equal(apiURL.hostname, "127.0.0.1", "The API must bind to loopback");
assert.ok(
  supportedFaults.has(fault),
  `Unknown browser harness fault: ${fault}`,
);
assert.equal(
  sourceDirectory,
  path.join(repositoryRoot, "artifacts", "web", "wwwroot"),
  "The frontend source must be artifacts/web/wwwroot",
);
assert.equal(
  siteDirectory,
  path.join(repositoryRoot, "artifacts", "browser-site"),
  "The prepared site must use artifacts/browser-site",
);

const releasePath = `/releases/${releaseId}/`;
const releaseDirectory = path.join(siteDirectory, "releases", releaseId);
const sourceIndex = path.join(sourceDirectory, "index.html");
const releaseIndex = path.join(releaseDirectory, "index.html");

await stat(sourceIndex).catch(() => {
  throw new Error(
    `Release-published frontend is missing at ${sourceDirectory}. Publish it before running browser tests.`,
  );
});

await rm(siteDirectory, { recursive: true, force: true });
await mkdir(path.dirname(releaseDirectory), { recursive: true });
await cp(sourceDirectory, releaseDirectory, { recursive: true });

let indexMarkup = await readFile(releaseIndex, "utf8");
const expectedBase = '<base href="/" />';
assert.equal(
  indexMarkup.split(expectedBase).length - 1,
  1,
  "Published index must contain exactly one root base element",
);
const renderedBase =
  fault === "wrong-base" ? "/broken-release-base/" : releasePath;
indexMarkup = indexMarkup.replace(
  expectedBase,
  `<base href="${renderedBase}" />`,
);
await writeFile(releaseIndex, indexMarkup);

const redirectMarkup = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=${releasePath}index.html">
  <title>OpenGameBuilder</title>
</head>
<body>
  <script>location.replace(${JSON.stringify(`${releasePath}index.html`)})</script>
  <a href="${releasePath}index.html">Open OpenGameBuilder</a>
</body>
</html>
`;
await writeFile(path.join(siteDirectory, "index.html"), redirectMarkup);

const contentTypes = new Map([
  [".css", "text/css; charset=utf-8"],
  [".dat", "application/octet-stream"],
  [".dll", "application/octet-stream"],
  [".html", "text/html; charset=utf-8"],
  [".ico", "image/x-icon"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".pdb", "application/octet-stream"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".wasm", "application/wasm"],
  [".woff", "font/woff"],
  [".woff2", "font/woff2"],
]);

function sendText(response, statusCode, body) {
  response.writeHead(statusCode, {
    "cache-control": "no-store",
    "content-type": "text/plain; charset=utf-8",
  });
  response.end(body);
}

function proxyApi(request, response, requestURL) {
  const upstreamPath =
    fault === "wrong-api-route" && requestURL.pathname === "/api/about"
      ? "/api/missing-about"
      : `${requestURL.pathname}${requestURL.search}`;
  const headers = { ...request.headers };
  delete headers.host;
  headers.host = apiURL.host;
  headers["x-forwarded-for"] = request.socket.remoteAddress ?? "127.0.0.1";
  headers["x-forwarded-proto"] = "https";

  const upstream = http.request(
    {
      hostname: apiURL.hostname,
      port: apiURL.port,
      method: request.method,
      path: upstreamPath,
      headers,
    },
    (upstreamResponse) => {
      response.writeHead(
        upstreamResponse.statusCode ?? 502,
        upstreamResponse.headers,
      );
      upstreamResponse.pipe(response);
    },
  );
  upstream.on("error", (error) => {
    if (!response.headersSent)
      sendText(response, 502, `API proxy failed: ${error.message}`);
    else response.destroy(error);
  });
  request.pipe(upstream);
}

async function resolveStaticFile(pathname) {
  let decodedPath;
  try {
    decodedPath = decodeURIComponent(pathname);
  } catch {
    return undefined;
  }

  const candidate = path.resolve(
    siteDirectory,
    decodedPath === "/" ? "index.html" : `.${decodedPath}`,
  );
  if (
    candidate !== siteDirectory &&
    !candidate.startsWith(`${siteDirectory}${path.sep}`)
  ) {
    return undefined;
  }

  try {
    if ((await stat(candidate)).isFile()) return candidate;
  } catch {
    // Missing paths use the deployed edge fallback below.
  }

  // Match the deployed edge: an unknown static path falls back to the root
  // redirect, which selects the active release's concrete index page.
  return path.join(siteDirectory, "index.html");
}

const server = http.createServer(async (request, response) => {
  try {
    const requestURL = new URL(request.url ?? "/", siteURL);
    if (requestURL.pathname.startsWith("/api/")) {
      proxyApi(request, response, requestURL);
      return;
    }

    if (
      fault === "missing-asset" &&
      requestURL.pathname === `${releasePath}css/app.css`
    ) {
      sendText(response, 404, "Injected missing CSS asset");
      return;
    }

    if (
      fault === "unusable-frontend" &&
      (requestURL.pathname === `${releasePath}index.html` ||
        requestURL.pathname.startsWith(releasePath))
    ) {
      response.writeHead(200, {
        "cache-control": "no-store",
        "content-type": "text/html; charset=utf-8",
      });
      response.end(
        `<!doctype html><html><head><base href="${releasePath}" /></head><body><p>Injected unusable frontend</p></body></html>`,
      );
      return;
    }

    const file = await resolveStaticFile(requestURL.pathname);
    if (!file) {
      sendText(response, 404, "Not found");
      return;
    }

    const fileInfo = await stat(file);
    response.writeHead(200, {
      "cache-control": "no-store",
      "content-length": fileInfo.size,
      "content-type":
        contentTypes.get(path.extname(file).toLowerCase()) ??
        "application/octet-stream",
    });
    if (request.method === "HEAD") response.end();
    else createReadStream(file).pipe(response);
  } catch (error) {
    sendText(
      response,
      500,
      error instanceof Error ? error.message : String(error),
    );
  }
});

server.listen(Number(siteURL.port), siteURL.hostname, () => {
  console.log(
    `Release site ${releaseId} listening at ${siteURL.origin} (fault: ${fault})`,
  );
});
