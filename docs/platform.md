# Platform reference

The Brainbase Conversational Platform organizes work into **teams**, **workers**, **flows**, and **deployments**.

## Data model

### Teams

A team is your organization on Brainbase. All resources (workers, phone numbers, integrations, API keys) belong to a team. Users can be members of multiple teams.

### Workers

A worker is a conversational agent. It's the top-level container for everything related to one agent.

| Field | Description |
|-|-|
| `id` | `worker_<uuid>` |
| `name` | Display name |
| `description` | What this worker does |
| `engineVersion` | `v2` (current) |
| `status` | Active/inactive |

A worker contains:
- **Flows** — the Based code that defines behavior
- **Deployments** — live instances (voice, chat, SMS, etc.)
- **Resources** — knowledge base files and links (RAG)
- **Phone numbers** — assigned numbers for voice/SMS

### Flows

A flow is a Based program attached to a worker. Each worker can have multiple flows (e.g., "Inbound Call", "Outbound Campaign", "Chat Support").

| Field | Description |
|-|-|
| `id` | `flow_<uuid>` |
| `name` | Flow name |
| `code` | The Based source code |
| `variables` | JSON key-value pairs accessible via `variables` in the flow |
| `version` | Auto-incrementing version number |

Flows can have **flow parameters** — named variables configured per-deployment, enabling one flow to serve many deployments with different settings.

### Deployments

A deployment is a live instance of a worker+flow, connected to a channel (phone number, chat widget, API endpoint, etc.).

| Field | Description |
|-|-|
| `id` | `deploy_<uuid>` |
| `name` | Deployment name |
| `type` | Channel type (see below) |
| `status` | `ACTIVE`, `CREATING`, `INACTIVE` |

See [deployments.md](deployments.md) for full details on each type.

### Resources (RAG)

Resources are knowledge base items attached to a worker. The engine can query them during conversations.

**Types:**
- **Links** — web pages crawled and indexed
- **Files** — uploaded documents (PDF, DOCX, etc.)

Resources can be organized into **folders**. Each folder maintains its own vector index.

### Phone numbers

Phone numbers are team-level resources that can be assigned to workers and deployments.

| Field | Description |
|-|-|
| `number` | E.164 format (e.g., `+15551234567`) |
| `provider` | `brainbase` (purchased through platform) or `twilio` (imported) |
| `countryCode` | Country code (e.g., `US`) |

## Relationships

```
Team
├── Workers
│   ├── Flows (Based code)
│   ├── Deployments (live instances, each references one flow)
│   ├── Resources (knowledge base)
│   └── Phone Numbers (assigned)
├── Phone Numbers (pool)
├── Integrations (Twilio, etc.)
└── API Keys
```

A deployment connects a flow to a channel. When a call/message arrives on that channel, the engine loads the flow's Based code, creates (or resumes) a session, and executes.

## API authentication

All API requests require an `x-api-key` header with your team's API key.

```bash
curl -H "x-api-key: YOUR_API_KEY" https://api.brainbase.com/api/workers
```

## Key API endpoints

| Endpoint | Method | Description |
|-|-|-|
| `/api/workers` | GET | List all workers |
| `/api/workers` | POST | Create a worker |
| `/api/workers/:id` | GET | Get a worker |
| `/api/workers/:id` | PATCH | Update a worker |
| `/api/workers/:id` | DELETE | Delete a worker |
| `/api/workers/:workerId/flows` | GET | List flows for a worker |
| `/api/workers/:workerId/flows` | POST | Create a flow |
| `/api/workers/:workerId/flows/:id` | GET | Get a flow |
| `/api/workers/:workerId/flows/:id` | PATCH | Update a flow |
| `/api/workers/:workerId/deployments/voice` | GET | List voice deployments |
| `/api/workers/:workerId/deployments/voice` | POST | Create voice deployment |
| `/api/workers/:workerId/resources/:type` | GET | List resources (link/file) |
| `/api/workers/:workerId/resources/query` | POST | Query knowledge base |
| `/api/workers/:workerId/deploymentLogs/voice` | GET | List voice deployment logs |
| `/api/workers/:workerId/deploymentLogs/voice/:logId` | GET | Get a voice deployment log |
| `/api/workers/:workerId/deploymentLogs/chat` | GET | List chat deployment logs |
| `/api/workers/:workerId/deploymentLogs/chat/:logId` | GET | Get a chat deployment log |
| `/api/logs/:logId` | GET | Get any deployment log by ID (no worker/deployment context needed) |

### Deployment logs

Every conversation (call, chat session, SMS thread, etc.) produces a **deployment log**. Logs share a common set of base fields and include type-specific fields depending on the channel.

**Base fields** (all log types):

| Field | Description |
|-|-|
| `id` | `log_<uuid>` |
| `type` | Delegate type: `VoiceDeploymentLog`, `ChatDeploymentLog`, `ChatEmbedDeploymentLog`, `WhatsappDeploymentLog`, `SmsDeploymentLog`, `ApiDeploymentLog`, `EmailDeploymentLog` |
| `workerId` | Parent worker |
| `deploymentId` | Parent deployment |
| `flowId` | Flow that was executed |
| `createdAt` | When the log was created |
| `extractionsData` | Extracted data (JSON) |
| `metadata` | Arbitrary metadata (JSON) |
| `flowSnapshot` | Snapshot of the flow code at execution time |
| `sessionLogData` | Engine session trace data (JSON) |

**Voice-specific fields:** `startTime`, `endTime`, `fromNumber`, `toNumber`, `direction`, `transcription`, `messages`, `recordingUrl`, `status`, `duration`, `call_sid`, `externalCallId`

**Chat-specific fields:** `startTime`, `endTime`, `userId`, `userName`, `userEmail`, `messages`, `rating`, `feedback`, `messageCount`, `duration`

**ChatEmbed-specific fields:** `startTime`, `endTime`, `sessionId`, `messages`, `status`, `messageCount`, `duration`, `userAgent`, `originUrl`

**WhatsApp/SMS-specific fields:** `startTime`, `endTime`, `fromNumber`, `toNumber`, `direction`, `transcription`, `messages`, `status`

**API-specific fields:** `startTime`, `endTime`, `requestModel`, `requestMessages`, `responseContent`, `promptTokens`, `completionTokens`, `totalTokens`

#### Universal log lookup

The `/api/logs/:logId` endpoint fetches any log by ID without needing to know the worker or deployment. This is useful for:
- Direct links to logs from external systems (alerts, CRMs, webhooks)
- Debugging when you only have a log ID
- Building dashboards that span multiple workers

```bash
curl -H "x-api-key: YOUR_API_KEY" \
  https://brainbase-monorepo-api.onrender.com/api/logs/log_82788ca4-6e9f-4778-83d4-96868cbe5edb
```

The response includes all base fields plus the type-specific delegate fields flattened into the top level. The `type` field tells you which delegate type is present.
