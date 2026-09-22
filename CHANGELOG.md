# Changelog

Notable changes are curated here. See the [release-note process](docs/release/README.md#curated-release-notes)
for preparing an entry and [GitHub Releases](https://github.com/OpenGameBuilder/opengamebuilder/releases)
for published versions predating this changelog.

## Unreleased

### Changed

- Staging and production can use separate hosts and SSH keys. Each environment
  must select its edge profile; see the [hosting configuration](docs/setup/hosting.md).

### Fixed

- A failed first deployment can recover to an undeployed state and be retried.
  Failed cleanup retains the pending transaction and diagnostics; see
  [activation and recovery](docs/setup/hosting.md#application-activation-and-rollback).
