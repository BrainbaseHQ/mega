# Deployment types

Each deployment connects a worker's flow to a communication channel. The type determines what configuration is required and how users interact with the agent.

## Voice

Inbound and outbound phone calls. The most common deployment type.

| Field | Required | Description |
|-|-|-|
| `flowId` | Yes | The Based flow to execute |
| `phoneNumber` | Yes | Phone number to receive/make calls (E.164) |
| `engineModel` | No | LLM model (default: `gpt-4o`) |
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
| `engineModel` | No | LLM model |
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

## Supported LLM models

| Provider | Models |
|-|-|
| OpenAI | `gpt-4.1`, `gpt-4.1-mini`, `gpt-4o`, `gpt-4o-mini`, `o3`, `o4-mini` |
| Anthropic | `claude-sonnet-4-5`, `claude-opus-4-5` |
| Google | `gemini-2.5-flash`, `gemini-2.0-flash` |

The model is set per-deployment. If not specified, defaults to `gpt-4o`.
