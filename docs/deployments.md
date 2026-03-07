# Deployment types

Each deployment connects a worker's flow to a communication channel. The type determines what configuration is required and how users interact with the agent.

## Voice

Inbound and outbound phone calls. The most common deployment type.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |
| `phoneNumber` | Yes | Phone number to receive/make calls (E.164) |
| `voiceId` | No | Voice for TTS |
| `language` | No | Language code |
| `interruptionSensitivity` | No | How easily the user can interrupt (0-1) |
| `maxCallDuration` | No | Max call length in seconds |
| `backupPhoneNumber` | No | Fallback number if transfer fails |

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
| `stylingConfig` | No | Custom CSS/styling JSON |

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

## LLM model selection

Model selection and routing is managed by the Brainbase team. The platform supports models from multiple providers (OpenAI, Anthropic, Google). Contact the Brainbase team for model configuration.
