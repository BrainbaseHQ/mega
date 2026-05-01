# Deployment types

Each deployment connects a worker's flow to a communication channel. The type determines what configuration is required and how users interact with the agent.

## Voice

Inbound and outbound phone calls. The most common deployment type.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |
| `phoneNumber` | Yes | Phone number to receive/make calls (E.164) |
| `externalConfig.voiceId` | No | Voice for TTS |
| `externalConfig.language` | No | Language code |
| `externalConfig.interruptibility` | No | How easily the user can interrupt (0-1) |
| `externalConfig.maxCallDurationMs` | No | Max call length in milliseconds |
| `backupPhoneNumber` | No | Fallback number if transfer fails |

> **v2 engine routing:** Pass `externalConfig.engineVersion: "v2"` when creating voice deployments. The API now attempts to inherit the worker's `engineVersion` when this is omitted, but callers should pass it explicitly for deterministic routing and baked-in agent behavior:
>
> ```json
> {
>   "name": "My Voice Deployment",
>   "flowId": "flow_...",
>   "phoneNumber": "+15551234567",
>   "externalConfig": { "engineVersion": "v2" }
> }
> ```

Voice deployments support:
- Call transfer via `transfer(phone_number)` in Based
- Outbound campaigns (scheduled batch calls)
- Custom webhooks for call events
- Voicemail detection and handling

## Chat

HTTP-based chat interface. Users send messages via API and receive responses.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |
| `welcomeMessage` | No | First message shown to user |
| `allowedUsers` | No | Restrict to specific user IDs |

## Chat embed (web widget)

Embeddable chat widget for websites.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |
| `agentName` | No | Name shown in widget header |
| `agentLogo` | No | Logo URL |
| `primaryColor` | No | Widget theme color (hex) |
| `welcomeMessage` | No | Greeting message |
| `styling` | No | Custom CSS/styling JSON |

Each chat embed deployment gets a unique `embedId` for the widget script.

## SMS

Text message conversations via Twilio.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |
| `phoneNumber` | Yes | SMS-enabled phone number (E.164) |
| `includeReason` | No | Enable condition tracing |

## WhatsApp

WhatsApp messaging via Twilio.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |
| `phoneNumber` | Yes | WhatsApp-enabled phone number (E.164) |
| `includeReason` | No | Enable condition tracing |
| `integrationId` | No | Twilio integration to use |

## API

OpenAI-compatible API endpoint for programmatic access.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |

API deployments expose an OpenAI-compatible `/v1/chat/completions` endpoint. Use any OpenAI SDK to interact with the flow.

## API source of truth

See [api-reference.md](api-reference.md) for the current OpenAPI-aligned deployment endpoints, including flow versions, deployment parameters/history/default checks, logs, runtime errors, sessions, phone assets, integrations, tests, exports, and outbound campaigns.

## Guarded writes

Agents may inspect deployments with `GET` requests. Creating, updating, deleting, or launching live deployment behavior uses `POST`, `PATCH`, `PUT`, or `DELETE` and requires explicit user approval by default. When the API returns an error, preserve the status and body in the agent loop before deciding on a fix.

## LLM model selection

Model selection and routing is managed by the Brainbase team. The platform supports models from multiple providers (OpenAI, Anthropic, Google). Contact the Brainbase team for model configuration.
