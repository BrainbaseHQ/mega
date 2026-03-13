# Mega — Agent Instructions

You are working with the Brainbase Conversational Platform. You build, test, and deploy conversational agents using the Based language.

## Before you start

Read these docs — they are the canonical reference:
- `docs/based.md` — Based language (syntax, patterns, known limitations)
- `docs/platform.md` — Workers, flows, deployments, resources
- `docs/deployments.md` — Deployment types and configuration
- `examples/` — Production-quality Based flows

## Mandatory workflow for flows

**Never deploy a flow to a live channel without testing it first.**

1. Write the flow — save to `flows/` (gitignored for customer flows)
2. Create a worker and flow via the API (see `scripts/bb.sh` or `docs/platform.md`)
3. **Test via the OAI-compatible engine** — this is mandatory, not optional:
   ```bash
   curl "https://studio.brainbaselabs.com/v1/chat/completions\
   ?agent_id=<worker_id>&session_id=test-001" \
     -H "Authorization: Bearer <engine_key>" \
     -H "x-brainbase-api-key: <your_api_key>" \
     -H 'x-initial-state: {}' \
     -H "Content-Type: application/json" \
     -d '{"model":"gpt-4.1","messages":[{"role":"user","content":"Hello"}]}'
   ```
4. Run at least 2-3 turns to verify the conversation flow end-to-end
5. Fix any runtime errors, then re-test
6. Only then deploy to a live channel (voice, SMS, etc.)

Do NOT use chat deployments for testing — they are deprecated. The OAI engine is the only testing interface.

## Key v2 gotchas

- `variables` dict is NOT auto-injected in v2 — hardcode config values directly
- `.ask()` returns `AskProxy`, not a dict — use `.to_json()` before passing to `extract()`
- Voice deployment creation requires `externalConfig: { engineVersion: "v2" }` — the API does not auto-read from the worker
- `end_call()` and `transfer()` only exist in voice deployments — wrap in `try/except` with `done()` fallback for engine-testable flows
- `break` inside `for` loops in `until` blocks breaks the transpiler — use list comprehensions
- Don't put inline comments after `return` — put the comment on the line above
