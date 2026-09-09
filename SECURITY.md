# Security policy

Do not report secrets or personal data in public issues. For a suspected
credential leak, privacy boundary failure, authentication bypass, or data
isolation bug, contact the repository maintainer privately and include only the
minimum sanitized reproduction needed to investigate.

Deployments exposed beyond a local development machine must use signed device
requests (`SKIP_AUTH=false`), strong database credentials, TLS terminated by a
deployment owner, and a restricted network path.
