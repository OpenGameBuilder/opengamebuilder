// Compensate only for actionlint's documented cache-mode schema gap.
export function checkDeploymentCachePolicy(file, workflow) {
  if (
    !/^\.github\/workflows\/(_deploy|cd-production|cd-staging)\.yml$/.test(file)
  )
    return;
  if (workflow["cache-mode"] !== "none") {
    throw new Error(
      `${file}: protected-source deployment requires root cache-mode: none.`,
    );
  }
  for (const [job, definition] of Object.entries(workflow.jobs ?? {})) {
    if ("cache-mode" in definition && definition["cache-mode"] !== "none") {
      throw new Error(
        `${file}: job ${job} must not override cache-mode: none.`,
      );
    }
  }
}
