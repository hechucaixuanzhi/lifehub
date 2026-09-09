# Privacy and release guide

## What this repository does not include

The public distribution contains no personal database, device keys, provider
keys, media uploads, private messages, memory records, real-person seeds,
social-media imports, or deployment history.

## Before publishing your own fork

1. Start from a fresh repository history; do not publish a private repository's
   historical commits.
2. Keep `.env`, database backups, upload directories, exports and device keys
   out of version control.
3. Replace all sample cards with characters you have the right to use.
4. Remove media, voice samples, face galleries and public-post imports unless
   you have the necessary rights and consent.
5. Use `SKIP_AUTH=false`, strong database credentials and a private network for
   any deployment other than a local development test.

## Data boundaries

Character memories are scoped by character and conversation. Group chat and
writing-project context must remain separate from private character chat. A
forwarded message is explicit user-provided input to the destination only; it
does not grant the destination access to the source conversation's full memory.
