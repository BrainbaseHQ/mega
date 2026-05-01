<p align="center">
  <img src="assets/mega-sprite.svg" width="160" alt="Mega" />
</p>

<h1 align="center">Mega</h1>

<p align="center">
  <strong>Your AI teammate for the Brainbase Conversational Platform.</strong><br/>
  Describe what you want. Mega builds it, tests it, and manages it with guarded platform access.
</p>

<p align="center">
  <a href="https://docs.usebrainbase.com/mega">Docs</a> &middot;
  <a href="docs/based.md">Based Reference</a> &middot;
  <a href="examples/">Examples</a>
</p>

---

## What is Mega?

Mega gives AI coding tools — Claude Code, Cursor, Codex, or anything that reads files — deep knowledge of the Brainbase platform. It's not a CLI, not an SDK, not an agent framework. It's a repo full of context that makes your AI tool an expert Brainbase engineer.

You say what you need. Mega knows the rest.

**Write flows** — from business requirements, PDFs, spreadsheets, or a conversation.
**Deploy anywhere** — voice, chat, chat embed, SMS, WhatsApp, API. One flow can serve many channels.
**Scale** — templatize a working flow and replicate it across dozens of instances.
**Debug** — pull logs, runtime errors, LLM logs, and session traces, then fix and re-test.

## Quick start

```bash
git clone https://github.com/BrainbaseHQ/mega.git
cd mega
cp .env.example .env   # add your Brainbase API key
```

Open `mega/` in your AI tool. It auto-configures:

| Tool | Config | What Mega gives it |
|-|-|-|
| Claude Code | `CLAUDE.md` | Full platform context, Based reference, workflow patterns |
| Cursor | `.cursorrules` | Based syntax, platform conventions |
| Codex | `AGENTS.md` | Agent instructions for autonomous operation |

Then just talk to it:

```
"Here's our customer support playbook [attach PDF].
 Write a Based flow for inbound voice calls that routes
 to sales, service, or parts based on caller intent."
```

```
"Deploy the booking agent to these 40 phone numbers
 [attach spreadsheet]. Use the dealership name and hours
 from each row."
```

```
"Pull logs from deploy_abc123. Where are callers getting
 stuck? Fix it and redeploy."
```

## How it works — end-to-end

Here's what actually happens when you use Mega. This walks through building and deploying an appointment booking agent.

### 1. Describe what you need

```
"Build an appointment booking agent for a dental office.
 Greet callers, collect name and phone, let them pick a service
 (cleaning, filling, consultation), choose a time, and confirm."
```

### 2. Mega reads the Based reference

Your AI tool loads `CLAUDE.md` which points to `docs/based.md` — the complete Based language spec. It learns `loop/until/talk`, how `say()` and `.ask()` work, constraints, and patterns. It also finds `examples/appointment-booking.based` as a working template.

### 3. Mega writes the flow

```python
say("Thanks for calling Riverside Dental! How can I help you?")

loop:
    res = talk("You are Sarah, the scheduling assistant...", True)
until "caller wants to book":
    info = res.ask(question="What is their name?", example={"name": "Jane"})
    # ... collect details, confirm, book
until "caller wants to cancel":
    # ... handle cancellation
until "caller is done":
    say("Have a great day!")
    end_call()
```

### 4. Mega creates a worker and uploads the flow

```bash
./scripts/bb.sh workers create --name "Riverside Dental" --description "Appointment booking"
./scripts/bb.sh flows create <worker_id> --name "Booking" --code-file booking.based
```

`scripts/bb.sh` covers the common worker, flow, voice deployment, log, and tag paths. For the broader API surface, use the raw curl patterns in `docs/api-reference.md`.

### 5. Test directly against the engine

```bash
curl "https://studio.brainbaselabs.com/v1/chat/completions\
?agent_id=<worker_id>&session_id=test-001" \
  -H "Authorization: Bearer <engine_key>" \
  -H "x-brainbase-api-key: <your_api_key>" \
  -H 'x-initial-state: {"variables": {}}' \
  -H "Content-Type: application/json" \
  -d '{"model":"<model>","messages":[{"role":"user","content":"I need a cleaning"}]}'
```

### 6. Approve and deploy to a real channel

Mega treats platform writes as guarded operations. `GET` requests may run by default, but `POST`, `PATCH`, `PUT`, and `DELETE` require explicit user approval before execution, including live deployments and production flow updates.

```bash
./scripts/bb.sh deployments create-voice <worker_id> \
  --flow-id <flow_id> --phone "+15551234567" --name "Main Line" --engine-version v2
```

### Scaling: one flow, many deployments

For v2 live flows, do not assume dashboard variables are injected automatically. Put per-instance configuration at the top of each generated flow, or pass `variables` explicitly through `x-initial-state` in controlled engine tests.

```python
OFFICE_NAME = "Riverside Dental"
HOURS = "9am-5pm"
```

Deploy it 40 times with different values per office. Tell Mega:

```
"Here's a spreadsheet with 40 offices — name, hours, phone,
 services. Deploy the booking flow to each one."
```

It reads the spreadsheet, creates reviewed per-instance flows, tests each path, asks for approval, then deploys with the right configuration.

## Testing v1 engine flows

Open `mega/` in your AI tool (Cursor, Claude Code, Codex, etc.), make sure `BRAINBASE_API_KEY` is set in `.env`, and ask it to test your flow. The AI will use `scripts/test_v1_engine.py` to run a live WebSocket session against the v1 engine, then report back with the results.

**Quick test** — provide the worker/flow IDs and the messages to send:

> Test this v1 engine flow: worker_abc / flow_def. Send these messages in order: "Hello", "I'd like to book an appointment", "Tomorrow at 2 PM". Tell me how the agent responded at each step.

**Thorough test** — let the AI figure out what to test by reading the flow first:

> Fetch the flow code for worker_abc / flow_def using bb.sh, read it, and identify the key conversation branches. Then run a test session for each branch and give me a report on which ones work correctly.

**Test a specific feature** — point the AI at what matters:

> I need to test the hot deals functionality in worker_abc / flow_def. The flow calls a tee times API that returns hot deal data. Figure out which inputs trigger each hot deals branch, run the tests, and report back.

The AI handles everything: fetching the flow, understanding the branches, choosing test inputs, running the sessions, and analyzing the results.

### Setup

Use `uv` for local Python dependencies:

```bash
uv run --with websockets python scripts/test_v1_engine.py <worker_id> <flow_id> "Hello"
```

### Script reference

```bash
uv run --with websockets python scripts/test_v1_engine.py <worker_id> <flow_id> "message 1" "message 2" ...
```

| Flag | Default | Description |
|-|-|-|
| `--model` | `gpt-4o` | LLM model to use |
| `--state '{"key":"val"}'` | `{}` | Initial state JSON passed to the flow |
| `--no-streaming` | off | Get full responses instead of streaming |
| `--timeout` | `60` | Max seconds to wait for each agent response |

## What's inside

```
mega/
├── docs/
│   ├── based.md           # Complete Based language reference
│   ├── platform.md        # Workers, flows, deployments, resources
│   ├── deployments.md     # Deployment types and configuration
│   └── api-reference.md   # API hot paths, payloads, gotchas, curl patterns
├── examples/              # Validated, engine-tested Based flows
│   ├── inbound-router.based
│   ├── appointment-booking.based
│   ├── order-taking.based
│   ├── lead-qualification.based
│   └── outbound-campaign.based
├── scripts/
│   ├── bb.sh              # CLI wrapper for the Brainbase API
│   └── test_v1_engine.py  # WebSocket test client for v1 engine flows
├── CLAUDE.md              # Claude Code context
├── .cursorrules           # Cursor context
└── AGENTS.md              # Codex context
```

## The Based language

Based is Python + a small set of constructs for multi-turn, LLM-driven conversations. If you can write Python, you can write Based.

```python
loop:
    res = talk("You are a helpful assistant.", False)
until "user wants to schedule":
    details = res.ask(question="When?", example={"date": "tomorrow", "time": "2pm"})
    say(f"Booked for {details['date']} at {details['time']}.")
until "user says goodbye":
    say("Take care!")
```

See [docs/based.md](docs/based.md) for the full reference.

## Links

- [Brainbase API](https://brainbase-monorepo-api.onrender.com) — deployed API base URL
- [Brainbase docs](https://docs.usebrainbase.com)
- [Mega docs page](https://docs.usebrainbase.com/mega)
- [Based Language Fundamentals](https://docs.usebrainbase.com/language-fundamentals/overview)

## Contributing

Issues and pull requests welcome.

## License

MIT
