import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import parseYaml from "markdownlint-cli2/parsers/yaml";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

function readYaml(relativePath) {
  return parseYaml(readFileSync(path.join(root, relativePath), "utf8"));
}

function asArray(value) {
  return Array.isArray(value) ? value : [value];
}

test("production release validates the selected source before deployment and publishes once", () => {
  const workflow = readYaml(".github/workflows/cd-production.yml");
  const { deploy, publish, validate } = workflow.jobs;

  assert.equal(deploy.needs, "validate");
  assert.deepEqual(asArray(publish.needs).toSorted(), ["deploy", "validate"]);

  const validateCheckout = validate.steps.find((step) =>
    step.uses?.startsWith("actions/checkout@"),
  );
  assert.equal(
    validateCheckout.with.ref,
    "${{ needs.resolve-source.outputs.protected-revision }}",
  );
  const selectedSourceValidation = validate.steps.find((step) =>
    step.run?.includes("scripts/validate-release.sh"),
  );
  assert.ok(selectedSourceValidation, "selected source validation must run");
  assert.equal(selectedSourceValidation.env.SOURCE_REF, "${{ inputs.ref }}");

  const publishCheckout = publish.steps.find((step) =>
    step.uses?.startsWith("actions/checkout@"),
  );
  assert.equal(
    publishCheckout.with.ref,
    "${{ needs.validate.outputs.source_sha }}",
  );
  const publishStep = publish.steps.find((step) =>
    step.run?.includes("scripts/publish-release.sh"),
  );
  assert.ok(publishStep, "the release publisher must have one workflow owner");
  assert.equal(
    publishStep.env.SOURCE_SHA,
    "${{ needs.validate.outputs.source_sha }}",
  );

  for (const [name, job] of Object.entries({ deploy, publish, validate })) {
    assert.equal(job["continue-on-error"], undefined, name);
    assert.doesNotMatch(job.if ?? "", /always\s*\(/, name);
    for (const step of job.steps ?? []) {
      assert.equal(
        step["continue-on-error"],
        undefined,
        `${name}: ${step.name}`,
      );
      assert.doesNotMatch(
        step.if ?? "",
        /always\s*\(/,
        `${name}: ${step.name}`,
      );
    }
  }

  assert.deepEqual(Object.keys(workflow.on), ["workflow_dispatch"]);
  const workflowDirectory = path.join(root, ".github/workflows");
  const owners = readdirSync(workflowDirectory)
    .filter((file) => file.endsWith(".yml") || file.endsWith(".yaml"))
    .filter((file) => {
      const source = readFileSync(path.join(workflowDirectory, file), "utf8");
      return (
        source.includes("scripts/publish-release.sh") ||
        /\brelease\s+create\b/.test(source)
      );
    });
  assert.deepEqual(owners, ["cd-production.yml"]);

  for (const file of readdirSync(workflowDirectory).filter(
    (name) => name.endsWith(".yml") || name.endsWith(".yaml"),
  )) {
    const triggers = readYaml(path.join(".github/workflows", file)).on ?? {};
    assert.equal("release" in triggers, false, file);
    assert.equal(
      triggers.push !== null &&
        typeof triggers.push === "object" &&
        "tags" in triggers.push,
      false,
      file,
    );
  }
});

test("release drafting uses the recorded repository labels and excludes mechanical maintenance", () => {
  const release = readYaml(".github/release.yml").changelog;
  assert.deepEqual(release.exclude.labels.toSorted(), [
    "dependencies",
    "internal",
  ]);

  const categorized = release.categories.flatMap((category) => category.labels);
  const recordedLabels = new Set([
    ".NET",
    "api",
    "db",
    "dependencies",
    "devops",
    "docker",
    "documentation",
    "dotnet_sdk_package_manager",
    "duplicate",
    "dx",
    "github_actions",
    "good first issue",
    "help wanted",
    "internal",
    "invalid",
    "question",
    "ui/ux",
    "wontfix",
  ]);
  assert.equal(categorized.filter((label) => label === "*").length, 1);
  assert.deepEqual(
    categorized
      .filter((label) => label !== "*")
      .filter((label) => !recordedLabels.has(label)),
    [],
  );
  assert.deepEqual(
    categorized.filter((label) => release.exclude.labels.includes(label)),
    [],
  );
  assert.equal(new Set(categorized).size, categorized.length);
});
