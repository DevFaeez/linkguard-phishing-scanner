# Security

LinkGuard is a research prototype, not a certified phishing or malware protection product.
Only the current source version is maintained; there is no guaranteed security-update schedule.

## Reporting an issue

Avoid posting real messages, private URLs, tokens, credentials or exploit payloads in public
issues. For sensitive findings, use GitHub's private vulnerability reporting if it is available;
otherwise ask the maintainer on GitHub for a private reporting channel before sharing details.
Use reserved example domains and synthetic inputs for public reproductions.

## Secrets and local artifacts

Keep `.env` files, signing keys, `key.properties`, `local.properties`, datasets, logs, APKs and
session artifacts out of Git. An ignore rule does not remove something already committed.
If a real secret is exposed, revoke/rotate it and review repository history rather than only
removing its latest copy. The local staged-file guard and optional Gitleaks scan help detect
mistakes but do not replace review. Enable the hook as shown in the README.

## Scope

The model does not fetch target websites or verify destination ownership/content. Its scores
are uncalibrated. Do not rely on a benign-looking verdict to authorize sensitive transactions.
Notification scanning is opt-in and depends on Android permissions and visible notification text.
The bundled Python service is for local use; external hosting requires TLS, authentication,
rate limiting and a deployment-specific privacy/logging review.
