# Security Policy

## Supported Versions

OpenGameBuilder is in active development.

Until stable releases are established, security support applies to:

| Version or branch | Supported |
| --- | --- |
| Current `main` branch | Yes |
| Current public production deployment | Yes |
| Current public staging deployment | Yes, for security reports |
| Older commits, branches, forks, or local deployments | No, unless maintainers say otherwise |
| Archived MyGameBuilder material outside this repository | No |

Once OpenGameBuilder has stable public releases, this section will be updated to describe which release lines receive security fixes.

## Reporting a Vulnerability

Please do not report security vulnerabilities in public GitHub issues, pull requests, comments, Discord channels, or other public community spaces.

The preferred way to report a vulnerability is GitHub’s private vulnerability reporting feature:

1. Go to the repository’s **Security** tab.
2. Click **Report a vulnerability**.
3. Submit the report through GitHub’s private advisory form.

If you are unsure whether something is a security issue, report it privately anyway. It is better to over-report privately than to accidentally disclose a real vulnerability in public.

## What to Include

Please include as much of the following information as you can:

- a clear description of the issue;
- steps to reproduce it;
- affected URL, branch, commit, release, or deployment, if known;
- expected behavior;
- actual behavior;
- screenshots, logs, proof-of-concept code, or requests/responses, if useful;
- whether you believe the issue is being actively exploited;
- any suggested fix or mitigation, if you have one.

Do not include sensitive personal data unless it is necessary to explain the issue. If sensitive data is necessary, keep it minimal.

## Examples of Security Issues

Security issues may include, but are not limited to:

- authentication or authorization bypasses;
- access to another user’s private data;
- cross-site scripting;
- cross-site request forgery;
- server-side request forgery;
- injection vulnerabilities;
- path traversal;
- unsafe file upload or file serving behavior;
- exposed secrets, tokens, credentials, or private keys;
- dependency vulnerabilities with a realistic impact on OpenGameBuilder;
- vulnerabilities in deployment, CI/CD, or infrastructure configuration;
- ways to abuse restored or playable content to expose private, sensitive, or identifying information.

## Non-Security Issues

Please use normal GitHub issues or the project Discord for:

- ordinary bugs;
- feature requests;
- setup problems;
- documentation problems;
- compatibility differences that do not expose users, data, infrastructure, or credentials to harm;
- general questions.

If a compatibility issue involves private, sensitive, identifying, or unsafe material, report it privately.

## Response Expectations

OpenGameBuilder is a volunteer-run project. The maintainers will make a best-effort attempt to:

- acknowledge valid reports within 7 days;
- provide an initial assessment within 14 days;
- keep reporters reasonably informed when a fix is being worked on;
- credit reporters when appropriate and requested, unless confidentiality or safety concerns prevent it.

These are goals, not guarantees. Some reports may take longer depending on severity, complexity, maintainer availability, and project status.

## Coordinated Disclosure

Please give the maintainers a reasonable opportunity to investigate and fix a vulnerability before publicly disclosing it.

Do not publicly share exploit details, proof-of-concept code, screenshots, logs, or reproduction steps until the issue has been resolved or the maintainers have agreed that disclosure is appropriate.

The maintainers may publish a security advisory, release notes, or other public notice after a fix is available.

## Good-Faith Security Research

Good-faith security research is welcome.

If you follow this policy, avoid harming users or systems, and report vulnerabilities privately, the project will treat your report as helpful security research.

Please do not:

- attack, degrade, spam, or overload OpenGameBuilder services;
- access, modify, delete, or exfiltrate data that is not yours;
- attempt social engineering;
- test against third-party services without permission;
- disclose private, sensitive, identifying, or archival material publicly;
- use security testing as a way to obtain access to non-public systems or data;
- continue testing after you are asked to stop.

If testing could affect other users, project infrastructure, or sensitive material, ask privately first.

## No Bug Bounty

OpenGameBuilder does not currently offer a paid bug bounty program.

Reports are appreciated, but no payment, reward, or compensation should be expected unless a future program says otherwise.

## Maintainer Handling

Security reports should be handled privately by the project founder, maintainers, or designated security contacts.

When a report is submitted through GitHub private vulnerability reporting, maintainers may accept the report as a draft security advisory, ask for more information, collaborate on a fix privately, or close the report if it is not considered a security issue.

If a report involves someone who would normally handle security reports, that person should not handle the report alone when another trusted maintainer or moderator is available.
