# LifeHub Open backend

The backend is a FastAPI service for signed device requests, sync, media,
character cards, chat, memories, worldbooks, and optional pgvector retrieval.

## Local development

```bash
python -m venv .venv
# Activate the environment for your shell.
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --port 8000
```

`SKIP_AUTH=true` is suitable only for a local, single-machine smoke test. Use
`SKIP_AUTH=false` for any networked deployment and keep generated device keys
private.

## PostgreSQL and pgvector

The repository-root `docker-compose.yml` starts PostgreSQL and the backend.
Copy both environment examples, choose a strong database password, and run:

```bash
docker compose up --build
```

Run Alembic migrations against PostgreSQL before a production deployment:

```bash
alembic upgrade head
```

## Provider configuration

Provider API keys belong only in `backend/.env`. The API accepts missing keys
for local development, but live chat, embeddings, TTS, and vision require the
relevant provider to be configured. Never place keys in the mobile app, issue
tracker, screenshots, or commits.
