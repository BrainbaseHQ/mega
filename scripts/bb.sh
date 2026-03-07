#!/bin/bash
# bb.sh — Brainbase API CLI
# Thin wrapper for interacting with the Brainbase API.
# Requires BRAINBASE_API_KEY and BRAINBASE_API_URL in .env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

API_URL="${BRAINBASE_API_URL:-https://brainbase-monorepo-api.onrender.com}"
API_KEY="${BRAINBASE_API_KEY:-}"

if [ -z "$API_KEY" ]; then
    echo "Error: BRAINBASE_API_KEY is not set. Add it to .env" >&2
    exit 1
fi

request() {
    local method="$1"
    local path="$2"
    shift 2
    curl -s -X "$method" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        "$API_URL/api$path" \
        "$@"
}

case "${1:-help}" in
    workers)
        case "${2:-list}" in
            list)
                request GET "/workers"
                ;;
            get)
                request GET "/workers/$3"
                ;;
            create)
                request POST "/workers" -d "{\"name\": \"$3\"}"
                ;;
            delete)
                request DELETE "/workers/$3"
                ;;
            *)
                echo "Usage: bb.sh workers [list|get|create|delete] [args]"
                ;;
        esac
        ;;
    flows)
        case "${2:-}" in
            list)
                request GET "/workers/$3/flows"
                ;;
            get)
                request GET "/workers/$3/flows/$4"
                ;;
            create)
                local code
                code=$(cat "$5")
                request POST "/workers/$3/flows" -d "$(jq -n --arg name "$4" --arg code "$code" '{name: $name, code: $code}')"
                ;;
            update)
                # Usage: bb.sh flows update <worker_id> <flow_id> --code-file <path>
                if [ "${5:-}" = "--code-file" ] && [ -n "${6:-}" ]; then
                    local code
                    code=$(cat "$6")
                    request PATCH "/workers/$3/flows/$4" -d "$(jq -n --arg code "$code" '{code: $code}')"
                else
                    echo "Usage: bb.sh flows update <worker_id> <flow_id> --code-file <path>"
                fi
                ;;
            *)
                echo "Usage: bb.sh flows [list|get|create|update] <worker_id> [args]"
                ;;
        esac
        ;;
    deployments)
        case "${2:-}" in
            list)
                request GET "/workers/$3/deployments/voice"
                ;;
            get)
                request GET "/workers/$3/deployments/$4"
                ;;
            *)
                echo "Usage: bb.sh deployments [list|get] <worker_id> [deployment_id]"
                ;;
        esac
        ;;
    logs)
        case "${2:-}" in
            list)
                request GET "/deployment-logs/$3"
                ;;
            *)
                echo "Usage: bb.sh logs list <deployment_id>"
                ;;
        esac
        ;;
    help|*)
        cat <<EOF
Brainbase CLI

Usage: bb.sh <resource> <action> [args]

Resources:
  workers       list, get, create, delete
  flows         list, get, create, update
  deployments   list, get
  logs          list

Examples:
  bb.sh workers list
  bb.sh workers create "My Agent"
  bb.sh flows list <worker_id>
  bb.sh flows get <worker_id> <flow_id>
  bb.sh flows update <worker_id> <flow_id> --code-file path/to/flow.based
  bb.sh deployments list <worker_id>
  bb.sh logs list <deployment_id>

Environment:
  BRAINBASE_API_KEY   Your API key (required, set in .env)
  BRAINBASE_API_URL   API base URL (default: https://brainbase-monorepo-api.onrender.com)
EOF
        ;;
esac
