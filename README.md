# LifeHub Open

LifeHub Open is a local-first Flutter and FastAPI application for personal
configurable AI conversations. The default app opens directly into AI chat.
It includes moments, a companion-chat engine, character cards, worldbooks,
per-character memories, and optional vector retrieval.

This repository is a clean public distribution. It intentionally contains:

- no user profiles, messages, memories, media, voice samples, or device keys;
- no real-person character cards, biographies, social feeds, or face galleries;
- no provider keys, cookies, tunnel URLs, deployment identifiers, or database
  dumps;
- only fictional editable starter characters (`Nova` and `Lumi`).

## Architecture

```text
Flutter client (local SQLite)
  -> signed sync and chat API
  -> FastAPI
  -> PostgreSQL + pgvector (optional semantic memory retrieval)
```

The backend holds model-provider credentials. The mobile client holds a device
key pair in secure storage and never receives provider API keys.

## Quick start

1. Copy `backend/.env.example` to `backend/.env` and configure a provider key
   if you want live model replies.
2. Start the backend locally:

   ```bash
   cd backend
   python -m venv .venv
   # Activate the virtual environment for your shell.
   pip install -r requirements.txt
   uvicorn app.main:app --reload --port 8000
   ```

3. Run the Flutter client:

   ```bash
   cd app
   flutter pub get
   dart run build_runner build
   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
   ```

For PostgreSQL and pgvector, copy `.env.example` to `.env`, set a strong local
database password, copy `backend/.env.example` to `backend/.env`, then run
`docker compose up --build`.

## Privacy and rights

LifeHub Open is designed for self-hosting. You control the characters,
memories and media that you create. Do not upload another person's voice,
face, private messages, or copyrighted media unless you have the rights and
consent required for your use.

Read [the release and privacy guide](docs/PRIVACY_AND_RELEASE.md) before
publishing a derivative or deploying it for other people.

## License

Source code is Apache-2.0. Bundled third-party assets have their own licenses;
see [THIRD_PARTY.md](docs/THIRD_PARTY.md).

## Status

This is an early public release. The included example characters are starting
points, not trained identities or representations of real people.

## Temporarily dormant modules

Life tracking, study, exercise, pets, inbox and the activity timeline are hidden
by default. Their implementation, database tables and existing records are retained.
No database migration or data deletion is performed by this change.

In chat-only mode, life-data seeding and mobile push/pull sync do not run;
the backend does not expose /sync, /timeline or /mi_fitness routes and does not
start the fitness scheduler or initialize life-data snapshots. Life-data tools
are neither advertised to the model nor executable. Device registration, AI
chat, characters, groups, worldbooks, memories, voice, media and moments remain.

To restore the dormant modules, set LIFE_TRACKING_ENABLED=true in backend/.env
and restart the backend, then rebuild the client using:

```bash
flutter run --dart-define=LIFE_TRACKING_ENABLED=true
```

Keep both switches aligned. The fitness scheduler still requires its separate
MI_FITNESS_SYNC_ENABLED setting and valid provider credentials.
