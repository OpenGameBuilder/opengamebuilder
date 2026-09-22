# Changelog

<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

Notable changes are curated here. See the [release-note process](docs/release/README.md#curated-release-notes)
for preparing an entry and [GitHub Releases](https://github.com/OpenGameBuilder/opengamebuilder/releases)
for published versions predating this changelog.

## Unreleased

### Changed

- Contributor tooling recommends Node.js 24 and accepts Node.js 22 or newer.
  A single [setup command](docs/quality/content-checks.md) prepares the content
  tools, and optional commit hooks check staged formatting without modifying
  files or requiring the full validation toolchain.
- Release notes now come from the reviewed version entry in this changelog.
  Maintainers can generate PR drafting material and prepare entries with the
  [release-note tools](docs/release/README.md#curated-release-notes); production
  releases require a dated entry before deployment.
- Staging and production can use separate hosts and SSH keys. Each environment
  must select its edge profile; see the [hosting configuration](docs/setup/hosting.md).

### Fixed

- A failed first deployment can recover to an undeployed state and be retried.
  Failed cleanup retains the pending transaction and diagnostics; see
  [activation and recovery](docs/setup/hosting.md#application-activation-and-rollback).
