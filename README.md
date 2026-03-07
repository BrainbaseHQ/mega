# Mega

An AI-native engineer for the Brainbase Conversational Platform.
Design, deploy, and manage conversational agents from any code-native environment.

## What is Mega?

Mega gives AI coding tools (Claude Code, Cursor, Codex, or any environment that can run scripts) deep knowledge of the Brainbase platform and the ability to interact with it programmatically. Think of it as an expert Brainbase engineer that lives in your terminal.

**What it can do:**

- Write production-quality [Based](docs/based.md) flows from business requirements, documents, or spreadsheets
- Deploy agents across voice, chat, SMS, WhatsApp, and more
- Manage existing deployments — inspect logs, update flows, scale configurations
- Clone a working deployment across dozens of instances with different parameters
- Test and iterate on flows before going live

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/BrainbaseHQ/mega.git
cd mega
```

### 2. Configure your API key

```bash
cp .env.example .env
# Add your Brainbase API key
```

### 3. Open in your AI tool

Mega auto-configures for your environment:

| Tool | Config file | What loads |
|-|-|-|
| Claude Code | `CLAUDE.md` | Full platform context, Based reference, interaction patterns |
| Cursor | `.cursorrules` | Based syntax, platform conventions |
| Codex | `AGENTS.md` | Agent instructions for autonomous operation |

Just open the `mega/` directory in your tool and start working.

### 4. Start building

Tell your AI tool what you need:

```
"Here's our customer support playbook [attach PDF].
 Write a Based flow for inbound voice calls that routes
 to sales, service, or parts based on caller intent."
```

```
"Take the appointment-booking worker and deploy it to
 these 40 phone numbers [attach spreadsheet]. Each should
 use the dealership name and hours from the sheet."
```

```
"Pull the logs from deployment deploy_abc123 for the last
 week. What are the most common call outcomes? Are there
 any flows where callers are getting stuck?"
```

## How it works — end-to-end workflow

Here's what actually happens when you use Mega. This example walks through building and deploying an appointment booking agent from scratch.

### Step 1: You describe what you need

Open the `mega/` directory in Claude Code (or Cursor, Codex, etc.) and describe what you want:

```
"Build me an appointment booking agent for a dental office.
 It should greet callers, collect their name and phone number,
 let them pick a service (cleaning, filling, consultation),
 choose a date/time, and confirm the booking."
```

### Step 2: The AI reads the Based reference

Your AI tool automatically loads `CLAUDE.md` (or `.cursorrules` / `AGENTS.md`), which points it to `docs/based.md`. It reads the full Based language reference and understands the `loop/until/talk` pattern, how `say()` and `.ask()` work, and the constraints (top-level constructs, no inline comments after `return`, etc.).

It also references `examples/appointment-booking.based` as a working template.

### Step 3: The AI writes the flow

It produces a `.based` file using the patterns from the docs:

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

### Step 4: The AI creates a worker and flow

Using `scripts/bb.sh`, the AI creates the worker and uploads the flow:

```bash
# Create a worker
./scripts/bb.sh workers create --name "Riverside Dental" --description "Appointment booking"

# Create the flow
./scripts/bb.sh flows create <worker_id> --name "Booking" --code-file booking.based
```

### Step 5: Test via the engine

The AI can test the flow directly against the Based engine (no deployment needed):

```bash
curl "https://studio.brainbaselabs.com/v1/chat/completions?agent_id=<worker_id>&session_id=test-001" \
  -H "Authorization: Bearer <engine_key>" \
  -H "x-brainbase-api-key: <your_api_key>" \
  -H 'x-initial-state: {"variables": {}}' \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4.1-mini", "messages": [{"role": "user", "content": "Hi, I need a cleaning"}]}'
```

### Step 6: Deploy

Once the flow works, create a deployment to connect it to a real channel:

```bash
./scripts/bb.sh deployments create-voice <worker_id> \
  --flow-id <flow_id> \
  --phone "+15551234567" \
  --name "Riverside Dental - Main Line"
```

### Scaling to many deployments

The real power is templatization. If you have 40 dental offices, you write **one flow** using `variables`:

```python
name = variables.get('office_name', 'our office')
hours = variables.get('hours', '9am-5pm')
```

Then deploy it 40 times with different variable values per office. Tell the AI:

```
"Here's a spreadsheet with 40 offices. Each row has the office name,
 hours, phone number, and services offered. Deploy the booking flow
 to each one using the data from the spreadsheet."
```

The AI reads the spreadsheet, creates workers, and deploys each one with the right variables.

## Project structure

```
mega/
├── docs/
│   ├── based.md           # Complete Based language reference
│   ├── platform.md        # Workers, flows, deployments, resources
│   └── deployments.md     # Deployment types and configuration
├── examples/              # Production-quality Based flow examples
│   ├── inbound-router.based
│   ├── appointment-booking.based
│   ├── order-taking.based
│   ├── lead-qualification.based
│   └── outbound-campaign.based
├── scripts/               # Platform interaction scripts
│   └── bb.sh              # CLI wrapper for Brainbase API
├── CLAUDE.md              # Claude Code context
├── .cursorrules           # Cursor context
└── AGENTS.md              # Codex context
```

## The Based language

Based is the language used to define conversational flows on Brainbase. It compiles to Python and executes on the Brainbase engine. If you can write Python, you can write Based — it adds a small set of constructs for managing multi-turn conversations.

See [docs/based.md](docs/based.md) for the complete reference.

## Documentation

The Based language reference in `docs/based.md` is the canonical source. For the latest official documentation, see the [Brainbase docs](https://docs.usebrainbase.com).

## Contributing

Issues and pull requests are welcome.

## License

MIT
