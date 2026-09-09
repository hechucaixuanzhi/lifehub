# Architecture overview

LifeHub Open separates durable user data from model-visible context.

- **Client:** Flutter, Riverpod and Drift provide local-first UI and a local
  event queue.
- **API:** FastAPI validates signed device requests and owns provider keys.
- **Storage:** PostgreSQL persists synchronized entities; pgvector is used only
  for optional semantic memory retrieval.
- **Conversation isolation:** each private character conversation, group
  conversation and writing project has a distinct identifier and context path.
- **Context composition:** stable character fields, selected worldbook,
  authorized user facts, relevant lore, recent history, and retrieved memories
  are selected explicitly for each model request.

The server must treat model output as untrusted. It may create a response, but
it cannot select another conversation's data, override a request scope, or
write structured assets without the corresponding server-side authorization.
