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
            tags)
                case "${3:-list}" in
                    list)
                        if [ -z "${4:-}" ]; then
                            echo "Usage: bb.sh workers tags list <worker_id>" >&2
                            exit 1
                        fi
                        request GET "/workers/$4/tags"
                        ;;
                    assign)
                        if [ -z "${4:-}" ] || [ -z "${5:-}" ]; then
                            echo "Usage: bb.sh workers tags assign <worker_id> <tag_id>" >&2
                            exit 1
                        fi
                        request POST "/workers/$4/tags" -d "$(jq -n --arg tagId "$5" '{tagId: $tagId}')"
                        ;;
                    remove)
                        if [ -z "${4:-}" ] || [ -z "${5:-}" ]; then
                            echo "Usage: bb.sh workers tags remove <worker_id> <tag_id>" >&2
                            exit 1
                        fi
                        request DELETE "/workers/$4/tags/$5"
                        ;;
                    *)
                        echo "Usage: bb.sh workers tags [list|assign|remove] <worker_id> [tag_id]"
                        ;;
                esac
                ;;
            *)
                echo "Usage: bb.sh workers [list|get|create|delete|tags] [args]"
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
                # Usage: bb.sh flows update <worker_id> <flow_id> --code-file <path> [--commit-message <msg>]
                local worker_id="$3"
                local flow_id="$4"
                shift 4
                local code_file=""
                local commit_message=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --code-file) code_file="$2"; shift 2 ;;
                        --commit-message) commit_message="$2"; shift 2 ;;
                        *) echo "Unknown flag: $1" >&2; exit 1 ;;
                    esac
                done
                if [ -z "$code_file" ]; then
                    echo "Usage: bb.sh flows update <worker_id> <flow_id> --code-file <path> [--commit-message <msg>]" >&2
                    exit 1
                fi
                local code
                code=$(cat "$code_file")
                if [ -n "$commit_message" ]; then
                    request PATCH "/workers/$worker_id/flows/$flow_id" -d "$(jq -n --arg code "$code" --arg msg "$commit_message" '{code: $code, commitMessage: $msg}')"
                else
                    request PATCH "/workers/$worker_id/flows/$flow_id" -d "$(jq -n --arg code "$code" '{code: $code}')"
                fi
                ;;
            *)
                echo "Usage: bb.sh flows [list|get|create|update] <worker_id> [args]"
                ;;
        esac
        ;;
    tags)
        case "${2:-list}" in
            list)
                request GET "/team/tags"
                ;;
            create)
                # Usage: bb.sh tags create <label> <color>
                if [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                    echo "Usage: bb.sh tags create <label> <color>" >&2
                    exit 1
                fi
                request POST "/team/tags" -d "$(jq -n --arg label "$3" --arg color "$4" '{label: $label, color: $color}')"
                ;;
            update)
                # Usage: bb.sh tags update <tag_id> [--label <label>] [--color <color>]
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh tags update <tag_id> [--label <label>] [--color <color>]" >&2
                    exit 1
                fi
                local tag_id="$3"
                shift 3
                local json="{}"
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --label) json=$(echo "$json" | jq --arg v "$2" '. + {label: $v}'); shift 2 ;;
                        --color) json=$(echo "$json" | jq --arg v "$2" '. + {color: $v}'); shift 2 ;;
                        *) echo "Unknown flag: $1" >&2; exit 1 ;;
                    esac
                done
                request PATCH "/team/tags/$tag_id" -d "$json"
                ;;
            delete)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh tags delete <tag_id>" >&2
                    exit 1
                fi
                request DELETE "/team/tags/$3"
                ;;
            *)
                echo "Usage: bb.sh tags [list|create|update|delete] [args]"
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
  workers       list, get, create, delete, tags
  flows         list, get, create, update
  deployments   list, get
  logs          list
  tags          list, create, update, delete (team-level)

Examples:
  bb.sh workers list
  bb.sh workers create "My Agent"
  bb.sh workers tags list <worker_id>
  bb.sh workers tags assign <worker_id> <tag_id>
  bb.sh workers tags remove <worker_id> <tag_id>
  bb.sh flows list <worker_id>
  bb.sh flows get <worker_id> <flow_id>
  bb.sh flows update <worker_id> <flow_id> --code-file path/to/flow.based --commit-message "fix confirmation loop"
  bb.sh deployments list <worker_id>
  bb.sh logs list <deployment_id>
  bb.sh tags list
  bb.sh tags create "priority" "#ff0000"
  bb.sh tags update <tag_id> --label "urgent" --color "#ff6600"
  bb.sh tags delete <tag_id>

Environment:
  BRAINBASE_API_KEY   Your API key (required, set in .env)
  BRAINBASE_API_URL   API base URL (default: https://brainbase-monorepo-api.onrender.com)
EOF
        ;;
esac
