# Mega

An AI-native engineer for the Brainbase Conversational Platform.
Design, deploy, and manage conversational agents from any code-native environment.

## What is Mega?

Mega gives AI coding tools (Claude Code, Cursor, Codex, or any environment that can run scripts) deep knowledge of the Brainbase platform and the ability to interact with it programmatically. Think of it as an expert Brainbase engineer that lives in your terminal.

**What it can do:**

- Write production-quality [Based](docs/based.md) flows from business requirements, documents, or spreadsheets
- Deploy agents across voice, chat, SMS, WhatsApp, and more
- Manage existing high-volume deployments — inspect logs, update flows, scale configurations
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
|-|-|
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

## For partners

If you're a Brainbase partner, Mega is how your engineering team can programmatically manage deployments at scale. Set your API key, open the repo in your preferred AI tool, and describe what you need. The AI has full context on Based, the platform's data model, and your available APIs.

## Contributing

This is an open-source project maintained by [Brainbase](https://brainbase.com). Issues and pull requests are welcome.

## License

MIT
