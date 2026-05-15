# Security Policy

## Supported Versions

Only the latest tagged release receives security updates. Older versions are not patched — please update before reporting issues.

| Version | Supported |
|---------|-----------|
| latest  | yes       |
| older   | no        |

## Reporting a Vulnerability

**Do not open a public issue for security problems.** Public issues disclose the vulnerability before a fix is available.

Report privately through **GitHub Security Advisories**:

1. Go to https://github.com/korenskoy/yamp-zvuk-com/security/advisories/new
2. Fill in the form with a description, reproduction steps, and any proof-of-concept code.
3. Submit. Only the maintainer will see the report until it is published.

If you cannot use GitHub Security Advisories for any reason, contact the maintainer directly via the email associated with the GitHub account.

## What to expect

- **Acknowledgement** within 7 days.
- **Initial assessment** within 14 days (severity, affected versions, intended fix window).
- **Fix and disclosure** coordinated with the reporter. The advisory is published once a release containing the fix is available, with credit to the reporter unless anonymity is requested.

## Scope

In scope:

- Code in this repository (`Sources/YAMP/**`).
- Build, packaging, and release scripts (`scripts/**`).
- Distributed DMG artifacts on the Releases page.

Out of scope:

- Vulnerabilities in zvuk.com infrastructure or its official API — report those to Zvuk directly.
- Vulnerabilities in third-party dependencies — report them upstream (we will still accept advisories that describe how this client is impacted).
- Social-engineering, physical access, or attacks requiring a pre-compromised macOS user account.
