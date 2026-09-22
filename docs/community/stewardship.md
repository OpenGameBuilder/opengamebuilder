# Practical stewardship

The [organization governance](https://github.com/OpenGameBuilder/.github/blob/main/GOVERNANCE.md)
remains authoritative. This page records responsibilities and material-handling
rules for the current small project; it does not appoint additional maintainers.

## Responsibilities and continuity

GitHub inspection on 2026-09-22 UTC confirmed `ostomachion` as the sole organization
owner and the only application collaborator with write/admin access.

| Area                                               | Current responsibility and handoff                                                                                                                                                                                  |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Project decisions, repository access, and releases | `ostomachion`; see [governance](https://github.com/OpenGameBuilder/.github/blob/main/GOVERNANCE.md) and [GitHub setup](../setup/github.md#deployment-authority-and-recovery).                                       |
| Hosting and application recovery                   | `ostomachion` is the documented release/recovery operator; use [hosting recovery](../setup/hosting.md#application-activation-and-rollback). A working rollback procedure does not establish backup operator access. |
| Domains, DNS, and renewals                         | No separate operator or recovery handoff is recorded. `ostomachion` owns arranging and privately documenting that handoff before delegating operations; registrar/account access has not been verified here.        |
| Historical archive                                 | Managed in the separate [archive repository](https://github.com/OpenGameBuilder/mygamebuilder-archive). Application permissions do not confer ownership of archived material.                                       |

There is no agreed backup maintainer or independent private reporting contact
recorded. Both remain deferred, owned by `ostomachion`: before wider participation
or an operational handoff, agree a role with a willing trusted person, establish
the minimum required access, and rehearse recovery. Record their consent, scope,
and public contact route; keep account recovery details private.

Do not add `CODEOWNERS` until real area owners have accepted responsibility and
can satisfy the review requirement. Repository read access alone is not a
maintainer, recovery, or reporting role.

[Private vulnerability reporting](../../SECURITY.md) remains enabled. General
sensitive reports use the contact in the
[Code of Conduct](https://github.com/OpenGameBuilder/.github/blob/main/CODE_OF_CONDUCT.md#reporting-an-issue).
Neither route currently provides an independent escalation path for a concern
involving the primary contact. Do not describe that gap as resolved or publish
sensitive details as a workaround.

## Material intake and creator requests

Before adding a historical game, submitted asset, or fixture, record a short
provenance note alongside it or in the reviewing PR:

- Source, creator, and where and when it was obtained.
- License or explicit permission, the uses it permits, and required attribution.
  Technical access or presence in an archive is not permission to import or publish.
- A privacy review covering personal information and sensitive historical content.
- Any creator restrictions or requests, who reviewed them, and the agreed action.

If permission or privacy is unclear, leave the material out until reviewed.
The application's Apache-2.0 license does not grant rights to original games,
assets, or other submissions. Implementation tests use independently created
fixtures with recorded provenance; follow the [source-material policy](../../AI_POLICY.md#decompiled-source-and-original-client-material).

Creator, privacy, and removal requests go through [Support](../../SUPPORT.md#mygamebuilder-archive-and-compatibility-questions).
Pause disputed use while the responsible maintainer reviews the request. For
copies in this application, record what was removed or replaced and any remaining
distribution limits; avoid copying sensitive details into public records. Refer
archive changes to the archive maintainers. Do not promise that deleting a current
file also erases Git history, existing downloads, or third-party copies.
