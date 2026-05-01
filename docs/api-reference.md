# Brainbase API reference for Mega

This is the AI-native API surface Mega should use before falling back to the monorepo source. It is aligned to `core/brainbase-monorepo/brainbase-api/openapi.json` and selected route/schema source.

## Defaults

- Base URL: `https://brainbase-monorepo-api.onrender.com`
- All platform paths below are under `/api`.
- Auth header: `x-api-key: $BRAINBASE_API_KEY`
- Read operations (`GET`) are safe to run by default.
- Write operations (`POST`, `PATCH`, `PUT`, `DELETE`) require explicit user approval by default, including flow updates and live deployments.
- When an API call fails, return the HTTP status, response body, request path, and relevant IDs back to the agent loop. Do not hide validation details.

```bash
curl -sS "$BRAINBASE_API_URL/api/workers" \
  -H "x-api-key: $BRAINBASE_API_KEY"
```

## CLI coverage

`scripts/bb.sh` is a hot-path helper, not the full API. Prefer it for:

- workers: list, get, create, update, delete, worker tags
- flows: list, get, create, update, versions list/get/commit
- deployments: list by type, universal get, create voice
- logs: list deployment logs, universal get
- team tags: list, create, update, delete

Use raw curl for endpoint families not implemented by `bb.sh`.

## Workers

| Operation | Method and path | Notes |
|-|-|-|
| List workers | `GET /workers` | Includes assigned worker tags. |
| Create worker | `POST /workers` | Body requires `name`, `description`, and `status`; nullable fields must be sent as `null` if omitted. |
| Get worker | `GET /workers/{id}` | Worker-scoped lookup. |
| Update worker | `PATCH /workers/{id}` | Partial body. |
| Delete worker | `DELETE /workers/{id}` | Requires approval. |

```bash
./scripts/bb.sh workers create --name "Riverside Dental" --description "Appointment booking"
```

Raw body:

```json
{
  "name": "Riverside Dental",
  "description": "Appointment booking",
  "status": null
}
```

## Flows and versions

| Operation | Method and path | Notes |
|-|-|-|
| List flows | `GET /workers/{workerId}/flows` | Worker-scoped. |
| Create flow | `POST /workers/{workerId}/flows` | Requires `name`, `label`, `code`; `label` may be `null`; `validate` defaults on the API. |
| Get flow | `GET /workers/{workerId}/flows/{flowId}` | Supports `versionId` and `deploymentId`. |
| Universal flow get | `GET /flows/{flowId}` | Same `versionId` and `deploymentId` query params, no worker ID required. |
| Update flow | `PATCH /workers/{workerId}/flows/{flowId}` | Use `commitMessage` for production/API-key updates. API-key code updates auto-commit a version. |
| Delete flow | `DELETE /workers/{workerId}/flows/{flowId}` | Requires approval. |
| List versions | `GET /workers/{workerId}/flows/{flowId}/versions?limit=20&offset=0` | Ordered by version number descending. |
| Get version | `GET /workers/{workerId}/flows/{flowId}/versions/{versionId}` | Returns snapshot code and variables. |
| Commit version | `POST /workers/{workerId}/flows/{flowId}/versions` | Body requires `commitMessage`. |

```bash
./scripts/bb.sh flows create <worker_id> --name "Booking" --code-file booking.based
./scripts/bb.sh flows update <worker_id> <flow_id> --code-file booking.based --commit-message "fix confirmation loop"
./scripts/bb.sh flows get <worker_id> <flow_id> --deployment-id <deployment_id>
```

Flow parameter gotcha: `GET .../flows/{flowId}?deploymentId=...` returns `_mergedParameters` where deployment parameters override flow parameters. In v2 runtime, dashboard/deployment variables are not automatically injected into the Based `variables` dict. Only rely on `variables` when explicitly passed through the engine request `x-initial-state` or another runtime path you control.

## Deployments

Universal lookup:

| Operation | Method and path | Notes |
|-|-|-|
| Get any deployment | `GET /deployments/{deploymentId}` | Works across Voice, VoiceV1, Chat, ChatEmbed, Whatsapp, SMS, Email, Slack, API. |
| Include relations | `GET /deployments/{deploymentId}?include=sentinelAssignments,successCriteria,deploymentParameters` | Delegate fields are flattened. |
| History | `GET /workers/{workerId}/deployments/{deploymentId}/history` | `limit`, `offset`, `changeType=FLOW_VERSION|CONFIG|VOICE_SETTINGS|STATUS|PARAMETERS`. |
| Parameters | `GET/POST /workers/{workerId}/deployments/{deploymentId}/params` | Param body: `name`, `value`, optional `description`. |
| Parameter update/delete | `PATCH/DELETE /workers/{workerId}/deployments/{deploymentId}/params/{paramId}` | Requires approval. |

Voice:

| Operation | Method and path | Notes |
|-|-|-|
| List voice deployments | `GET /workers/{workerId}/deployments/voice` | Worker-scoped. |
| Create voice deployment | `POST /workers/{workerId}/deployments/voice` | Requires `name`, `phoneNumber`, `flowId`. |
| Get/update/delete voice | `GET/PATCH/DELETE /workers/{workerId}/deployments/voice/{deploymentId}` | Writes require approval. |
| Custom webhooks | `/workers/{workerId}/deployments/{deploymentId}/voice/customWebhooks` | List/create/get/update/delete. |

Use `externalConfig.engineVersion: "v2"` explicitly for deterministic v2 voice routing. The API attempts to inherit the worker `engineVersion` when this is omitted, but callers should still pass it.

```bash
./scripts/bb.sh deployments create-voice <worker_id> \
  --flow-id <flow_id> \
  --phone "+15551234567" \
  --name "Main Line" \
  --engine-version v2
```

```json
{
  "name": "Main Line",
  "phoneNumber": "+15551234567",
  "flowId": "flow_...",
  "externalConfig": {
    "engineVersion": "v2"
  },
  "createSipTrunk": true
}
```

Chat and chat embed:

| Type | Create/list path | Required body |
|-|-|-|
| Chat | `GET/POST /workers/{workerId}/deployments/chat` | `name`, `flowId`; optional `flowVersionId`, `allowedUsers`, `welcomeMessage`, `llmModel`, `modelConfig`, `extractions`, `successCriteria`. |
| Chat embed | `GET/POST /workers/{workerId}/deployments/chat-embed` | `name`, `flowId`; optional `flowVersionId`, `welcomeMessage`, `agentName`, `agentLogoUrl`, `primaryColor`, `styling`. |

Voice v1:

| Operation | Method and path | Notes |
|-|-|-|
| List/create | `GET/POST /workers/{workerId}/deployments/voicev1` | Legacy voice deployment path. |
| Get/update/delete | `GET/PUT/DELETE /workers/{workerId}/deployments/voicev1/{deploymentId}` | Create body has many required nullable fields: `objective`, `startSentence`, `endSentence`, `voiceId`, `language`, `allowedTransferNumbers`, `functions`, `model`, `resourceKeys`, `wsBaseUrl`, `config`. |

The current OpenAPI does not expose create endpoints for SMS, WhatsApp, Email, Slack, or API deployments, but universal lookup and logs may return those deployment/log types.

## Logs, runtime errors, LLM logs, sessions

| Operation | Method and path | Notes |
|-|-|-|
| Universal log get | `GET /logs/{logId}` | No worker or deployment ID required. |
| Voice logs | `GET /workers/{workerId}/deploymentLogs/voice` | Filters include `deploymentId`, `flowId`, `direction`, `fromNumber`, `toNumber`, `status`, `externalCallId`, `callSid`, `searchQuery`, time ranges, duration, `fields`, `page`, `limit`, `cursor`. |
| Chat logs | `GET /workers/{workerId}/deploymentLogs/chat` | Worker-scoped; get by `/{logId}`. |
| Chat embed logs | `GET /workers/{workerId}/deploymentLogs/chat-embed` | Worker-scoped; get by `/{logId}`. |
| SMS logs | `GET /workers/{workerId}/deploymentLogs/sms` | Worker-scoped; get by `/{logId}`. |
| WhatsApp logs | `GET /workers/{workerId}/deploymentLogs/whatsapp` | Worker-scoped; get by `/{logId}`. |
| Runtime errors | `GET /workers/{workerId}/runtime-errors` | Filters: `deploymentId`, `type`, `service`, `severity`, `limit`, `offset`. |
| Runtime error get | `GET /workers/{workerId}/runtime-errors/{errorId}` | Use for stack traces and line numbers. |
| LLM logs | `GET /workers/{workerId}/llm-logs` | Filters: `callId`, `sessionId`, `eventType`, `limit`, `offset`. The response strips model from request JSON. |
| LLM by call/session | `GET /workers/{workerId}/llm-logs/by-call/{callId}` and `/by-session/{sessionId}` | Ordered ascending for trace reconstruction. |
| Session data | `GET /workers/{workerId}/sessions/{sessionId}` | Returns state, messages, trace, token counts, and error. |

```bash
./scripts/bb.sh logs list <worker_id> --type voice --deployment-id <deployment_id> --fields id,startTime,status,direction,duration
./scripts/bb.sh logs get <log_id>
```

Debug loop pattern:

1. Start from the deployment log transcript/messages.
2. Pull `sessionLogData` or `GET /sessions/{sessionId}` for trace/state.
3. Pull runtime errors for stack trace, function name, line number, and metadata.
4. Pull LLM logs by `callId` or `sessionId` when prompt/request context matters.
5. Return all error context to the agent loop before editing a flow.

## Resources and folders

| Operation | Method and path | Notes |
|-|-|-|
| Folders | `GET/POST /workers/{workerId}/folders` | Create body: `name`, optional `description`. |
| Folder get/update/delete | `GET/PUT/DELETE /workers/{workerId}/folders/{folderId}` | Folder names must be unique per worker. |
| Folder resources | `GET /workers/{workerId}/folders/{folderId}/resources` | Lists resources in folder. |
| Link resources | `GET/POST /workers/{workerId}/resources/link` | Create body: `name`, `rawLink`, `updateFrequency`, optional `folderId`. |
| File resources | `GET/POST /workers/{workerId}/resources/file` | Create body: `name`, `s3FilePath`, `fileName`, `mimeType`, `size`, optional `folderId`. Upload to S3 must happen separately. |
| Resource details | `GET /workers/{workerId}/resources/{resourceId}` | Link or file. |
| Move resource | `POST /workers/{workerId}/resources/{resourceId}/move` | Body: `{ "folderId": "folder_..." }` or `null` to unfile. |
| Delete resource | `DELETE /workers/{workerId}/resources/{resourceId}` | Requires approval. |
| Query RAG | `POST /workers/{workerId}/resources/query` | Body requires `query`; optional `resources`, `folderId`, `folderName`, `queryParams`. |

RAG query body:

```json
{
  "query": "What are the office hours?",
  "folderId": "folder_...",
  "queryParams": {
    "topK": 5,
    "onlyNeedContext": true
  }
}
```

## Phone assets, integrations, hours

| Family | Paths | Notes |
|-|-|-|
| Phone numbers | `GET /team/assets/phone_numbers`, `GET /team/assets/available_phone_numbers`, `POST /team/assets/register_phone_number`, `POST /team/assets/purchase_phone_numbers`, `DELETE /team/assets/phone_numbers/{phoneNumberId}/delete` | Register body: `phoneNumber`, `integrationId`; purchase body: `phoneNumbers[]`, optional `integrationId`. |
| WhatsApp sender | `POST /team/assets/purchase_whatsapp_sender`, `GET /team/assets/whatsapp_sender_status/{senderSid}` | Purchase requires E.164 number and profile fields. |
| Twilio integrations | `GET /team/integrations`, `GET /team/integrations/{integrationId}`, `POST /team/integrations/twilio/create`, `PATCH /team/integrations/{integrationId}`, `DELETE /team/integrations/twilio/{integrationId}/delete` | Create body requires plaintext `accountSid` and `authToken`; the API encrypts token storage. |
| Business hours | `GET/POST /workers/business-hours`, `GET/PUT/DELETE /workers/business-hours/{id}` | Worker hours. |
| Team phone hours | `GET/POST /workers/team-phone-hours`, `GET/PUT/DELETE /workers/team-phone-hours/{id}` | Team phone availability. |
| Callable check | `POST /workers/check-callable` | Check whether a phone number is callable at a given time. |

## Default checks, exports, analysis

| Operation | Method and path | Notes |
|-|-|-|
| Team default checks | `GET /team/default-checks`, `POST /team/default-checks`, `PUT /team/default-checks` | `POST` initializes defaults. `PUT` upserts latency/API/AI checks, thresholds, alert emails, sample rate. |
| Deployment default checks | `GET/PUT/DELETE /workers/{workerId}/deployments/{deploymentId}/default-checks` | `GET` returns resolved team plus deployment overrides. `DELETE` reverts to team defaults. |
| Create export | `POST /team/exports` | Queues CSV/JSON deployment log export. Body: `format`, `startDate`, `endDate`, optional `logType`, `workerId`, `deploymentId`, `fields`, `filtersJson`. Max 90-day window; one active export per team. |
| List exports | `GET /team/exports` | 20 most recent exports. |
| Export status | `GET /team/exports/{exportId}` | Returns status and download URL when complete. |
| Voice analysis | `POST /voice-analysis` | Detailed voice deployment analysis with billing breakdown. |

## Tests and Echo

| Operation | Method and path | Notes |
|-|-|-|
| Legacy worker tests | `POST /workers/{workerId}/tests`, `PUT/DELETE /workers/{workerId}/tests/{testId}`, `POST /workers/{workerId}/tests/{testId}/run`, `GET /workers/{workerId}/tests/{testId}/runs` | Test create requires `name`, `description`, `checkpoints`, `testMode`, `systemPrompt`, `flowId`. |
| Echo agents | `GET/POST /echo/agents`, `PUT/DELETE /echo/agents/{id}` | Create body: `name`, `type`, `purpose`, `goals`, optional deployment/suite/scorecard IDs. |
| Echo scorecards | `GET/POST /echo/scorecards`, `GET/PUT/DELETE /echo/scorecards/{id}` | Create body requires `name`; optional `description`, `items`, `suiteId`, `agentId`, `deploymentId`. |
| Echo suites | `GET/POST /echo/suites`, `PUT/DELETE /echo/suites/{id}` | Create body requires `name`; optional `description`, deployment and scorecard IDs. |
| Echo run | `POST /echo/run` | Requires `team-secret` header, not `x-api-key`; body must include `type: "agent" | "test_suite"` and `agent_data`. |

Use the OAI-compatible engine for normal flow testing before live deployment. Echo is for test-agent/suite workflows, not a replacement for the required 2-3 turn engine test before creating a live channel.

## Outbound campaigns and batch calls

| Operation | Method and path | Notes |
|-|-|-|
| Voice outbound campaigns | `GET/POST /workers/{workerId}/deployments/voice/{deploymentId}/outbound-campaigns` | Create body requires `data`; optional `name`, `description`, `batch_size`, `batch_interval_minutes`, `additional_data`, `telephonyProvider`, `status`, `flow_id`. |
| Campaign get/update/delete | `GET/PATCH/DELETE /workers/{workerId}/deployments/voice/{deploymentId}/outbound-campaigns/{campaignId}` | Writes require approval. |
| Stop campaign | `POST /workers/{workerId}/deployments/voice/{deploymentId}/stop-campaign` | Removes queued calls. |
| Voice batch calls | `POST /workers/{workerId}/deployments/voice/{deploymentId}/make-batch-calls` and `/stop-batch-calls` | Batch data array is required. |
| Voice v1 campaigns | `POST /workers/{workerId}/deployments/voicev1/{deploymentId}/campaigns`, `POST /campaigns/{campaignId}/run`, `GET /campaigns/{campaignId}`, `GET/PUT /campaigns/{campaignId}/data/{dataId}` | Legacy campaign path. |
| Voice v1 batch calls | `POST /workers/{workerId}/deployments/voicev1/{deploymentId}/make-batch-calls` | Requires `data[]` with `id` and E.164 `phoneNumber`. |

Batch row example:

```json
{
  "data": [
    {
      "id": "lead-001",
      "phoneNumber": "+15551234567",
      "name": "Jane"
    }
  ],
  "batch_size": 10,
  "batch_interval_minutes": 5
}
```
