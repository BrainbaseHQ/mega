#!/bin/bash
# bb.sh - Brainbase API CLI
# Thin wrapper for common Brainbase API operations.
# Requires BRAINBASE_API_KEY and optional BRAINBASE_API_URL in .env.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

API_URL="${BRAINBASE_API_URL:-https://brainbase-monorepo-api.onrender.com}"
API_URL="${API_URL%/}"
API_KEY="${BRAINBASE_API_KEY:-}"

if [ -z "$API_KEY" ] && [ "${1:-help}" != "help" ] && [ "${1:-}" != "--help" ] && [ "${1:-}" != "-h" ]; then
    echo "Error: BRAINBASE_API_KEY is not set. Add it to .env" >&2
    exit 1
fi

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for bb.sh" >&2
        exit 1
    fi
}

request() {
    local method="$1"
    local path="$2"
    shift 2
    curl -sS -X "$method" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        "$API_URL/api$path" \
        "$@"
}

json_add_string() {
    require_jq
    local json="$1"
    local key="$2"
    local value="$3"
    printf '%s' "$json" | jq --arg key "$key" --arg value "$value" '. + {($key): $value}'
}

json_add_string_or_null() {
    require_jq
    local json="$1"
    local key="$2"
    local value="$3"
    printf '%s' "$json" | jq --arg key "$key" --arg value "$value" '. + {($key): (if $value == "" then null else $value end)}'
}

json_add_bool() {
    require_jq
    local json="$1"
    local key="$2"
    local value="$3"
    printf '%s' "$json" | jq --arg key "$key" --argjson value "$value" '. + {($key): $value}'
}

json_add_object_file() {
    require_jq
    local json="$1"
    local key="$2"
    local file="$3"
    printf '%s' "$json" | jq --slurpfile value "$file" --arg key "$key" '. + {($key): $value[0]}'
}

urlencode() {
    require_jq
    jq -nr --arg value "$1" '$value | @uri'
}

add_query_param() {
    local current="$1"
    local key="$2"
    local value="$3"
    local encoded_value
    encoded_value="$(urlencode "$value")"
    if [ -z "$current" ]; then
        printf '%s=%s' "$key" "$encoded_value"
    else
        printf '%s&%s=%s' "$current" "$key" "$encoded_value"
    fi
}

usage() {
    cat <<'EOF'
Brainbase CLI

Usage: bb.sh <resource> <action> [args]

Resources:
  workers       list, get, create, update, delete, tags
  flows         list, get, create, update, versions
  deployments   list, get, create-voice
  logs          list, get
  tags          list, create, update, delete (team-level)

Examples:
  bb.sh workers list
  bb.sh workers create --name "My Agent" --description "Appointment booking"
  bb.sh workers update <worker_id> --name "New Name" --status "ACTIVE"
  bb.sh workers tags assign <worker_id> <tag_id>

  bb.sh flows create <worker_id> --name "Booking" --code-file booking.based
  bb.sh flows get <worker_id> <flow_id>
  bb.sh flows update <worker_id> <flow_id> --code-file booking.based --commit-message "fix confirmation loop"
  bb.sh flows versions list <worker_id> <flow_id>
  bb.sh flows versions commit <worker_id> <flow_id> --commit-message "ready for deployment"

  bb.sh deployments list <worker_id> --type voice
  bb.sh deployments get <deployment_id>
  bb.sh deployments create-voice <worker_id> --flow-id <flow_id> --phone +15551234567 --name "Main Line" --engine-version v2

  bb.sh logs list <worker_id> --type voice --deployment-id <deployment_id> --limit 20
  bb.sh logs get <log_id>

Environment:
  BRAINBASE_API_KEY   Your API key (required, set in .env)
  BRAINBASE_API_URL   API base URL (default: https://brainbase-monorepo-api.onrender.com)
EOF
}

case "${1:-help}" in
    workers)
        case "${2:-list}" in
            list)
                request GET "/workers"
                ;;
            get)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh workers get <worker_id>" >&2
                    exit 1
                fi
                request GET "/workers/$3"
                ;;
            create)
                shift 2
                name=""
                description=""
                status=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --name) name="${2:-}"; shift 2 ;;
                        --description) description="${2:-}"; shift 2 ;;
                        --status) status="${2:-}"; shift 2 ;;
                        --help) echo "Usage: bb.sh workers create --name <name> [--description <text>] [--status <status>]"; exit 0 ;;
                        *)
                            if [ -z "$name" ]; then
                                name="$1"
                                shift
                            else
                                echo "Unknown argument: $1" >&2
                                exit 1
                            fi
                            ;;
                    esac
                done
                if [ -z "$name" ]; then
                    echo "Usage: bb.sh workers create --name <name> [--description <text>] [--status <status>]" >&2
                    exit 1
                fi
                json='{}'
                json="$(json_add_string "$json" "name" "$name")"
                json="$(json_add_string_or_null "$json" "description" "$description")"
                json="$(json_add_string_or_null "$json" "status" "$status")"
                request POST "/workers" -d "$json"
                ;;
            update)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh workers update <worker_id> [--name <name>] [--description <text>] [--status <status>]" >&2
                    exit 1
                fi
                worker_id="$3"
                shift 3
                json='{}'
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --name) json="$(json_add_string "$json" "name" "${2:-}")"; shift 2 ;;
                        --description) json="$(json_add_string_or_null "$json" "description" "${2:-}")"; shift 2 ;;
                        --status) json="$(json_add_string_or_null "$json" "status" "${2:-}")"; shift 2 ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
                    esac
                done
                request PATCH "/workers/$worker_id" -d "$json"
                ;;
            delete)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh workers delete <worker_id>" >&2
                    exit 1
                fi
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
                        require_jq
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
                        echo "Usage: bb.sh workers tags [list|assign|remove] <worker_id> [tag_id]" >&2
                        exit 1
                        ;;
                esac
                ;;
            *)
                echo "Usage: bb.sh workers [list|get|create|update|delete|tags] [args]" >&2
                exit 1
                ;;
        esac
        ;;
    flows)
        case "${2:-}" in
            list)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh flows list <worker_id>" >&2
                    exit 1
                fi
                request GET "/workers/$3/flows"
                ;;
            get)
                if [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                    echo "Usage: bb.sh flows get <worker_id> <flow_id> [--version-id <version_id>] [--deployment-id <deployment_id>]" >&2
                    exit 1
                fi
                worker_id="$3"
                flow_id="$4"
                shift 4
                query=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --version-id) query="$(add_query_param "$query" "versionId" "${2:-}")"; shift 2 ;;
                        --deployment-id) query="$(add_query_param "$query" "deploymentId" "${2:-}")"; shift 2 ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
                    esac
                done
                path="/workers/$worker_id/flows/$flow_id"
                if [ -n "$query" ]; then
                    path="$path?$query"
                fi
                request GET "$path"
                ;;
            create)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh flows create <worker_id> --name <name> --code-file <path> [--label <label>] [--variables-file <json>] [--no-validate]" >&2
                    exit 1
                fi
                worker_id="$3"
                shift 3
                name=""
                label=""
                code_file=""
                variables_file=""
                validate="true"
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --name) name="${2:-}"; shift 2 ;;
                        --label) label="${2:-}"; shift 2 ;;
                        --code-file) code_file="${2:-}"; shift 2 ;;
                        --variables-file) variables_file="${2:-}"; shift 2 ;;
                        --no-validate) validate="false"; shift ;;
                        *)
                            if [ -z "$name" ]; then
                                name="$1"
                                shift
                            elif [ -z "$code_file" ]; then
                                code_file="$1"
                                shift
                            else
                                echo "Unknown argument: $1" >&2
                                exit 1
                            fi
                            ;;
                    esac
                done
                if [ -z "$name" ] || [ -z "$code_file" ]; then
                    echo "Usage: bb.sh flows create <worker_id> --name <name> --code-file <path> [--label <label>] [--variables-file <json>] [--no-validate]" >&2
                    exit 1
                fi
                code="$(cat "$code_file")"
                json='{}'
                json="$(json_add_string "$json" "name" "$name")"
                json="$(json_add_string_or_null "$json" "label" "$label")"
                json="$(json_add_string "$json" "code" "$code")"
                json="$(json_add_bool "$json" "validate" "$validate")"
                if [ -n "$variables_file" ]; then
                    json="$(json_add_object_file "$json" "variables" "$variables_file")"
                fi
                request POST "/workers/$worker_id/flows" -d "$json"
                ;;
            update)
                if [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                    echo "Usage: bb.sh flows update <worker_id> <flow_id> [--code-file <path>] [--name <name>] [--label <label>] [--variables-file <json>] [--commit-message <msg>] [--no-validate]" >&2
                    exit 1
                fi
                worker_id="$3"
                flow_id="$4"
                shift 4
                json='{}'
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --code-file)
                            code="$(cat "${2:-}")"
                            json="$(json_add_string "$json" "code" "$code")"
                            shift 2
                            ;;
                        --name) json="$(json_add_string "$json" "name" "${2:-}")"; shift 2 ;;
                        --label) json="$(json_add_string_or_null "$json" "label" "${2:-}")"; shift 2 ;;
                        --variables-file) json="$(json_add_object_file "$json" "variables" "${2:-}")"; shift 2 ;;
                        --commit-message) json="$(json_add_string "$json" "commitMessage" "${2:-}")"; shift 2 ;;
                        --no-validate) json="$(json_add_bool "$json" "validate" "false")"; shift ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
                    esac
                done
                request PATCH "/workers/$worker_id/flows/$flow_id" -d "$json"
                ;;
            versions)
                case "${3:-}" in
                    list)
                        if [ -z "${4:-}" ] || [ -z "${5:-}" ]; then
                            echo "Usage: bb.sh flows versions list <worker_id> <flow_id> [--limit <n>] [--offset <n>]" >&2
                            exit 1
                        fi
                        worker_id="$4"
                        flow_id="$5"
                        shift 5
                        query=""
                        while [ $# -gt 0 ]; do
                            case "$1" in
                                --limit) query="$(add_query_param "$query" "limit" "${2:-}")"; shift 2 ;;
                                --offset) query="$(add_query_param "$query" "offset" "${2:-}")"; shift 2 ;;
                                *) echo "Unknown argument: $1" >&2; exit 1 ;;
                            esac
                        done
                        path="/workers/$worker_id/flows/$flow_id/versions"
                        if [ -n "$query" ]; then
                            path="$path?$query"
                        fi
                        request GET "$path"
                        ;;
                    get)
                        if [ -z "${4:-}" ] || [ -z "${5:-}" ] || [ -z "${6:-}" ]; then
                            echo "Usage: bb.sh flows versions get <worker_id> <flow_id> <version_id>" >&2
                            exit 1
                        fi
                        request GET "/workers/$4/flows/$5/versions/$6"
                        ;;
                    commit)
                        if [ -z "${4:-}" ] || [ -z "${5:-}" ]; then
                            echo "Usage: bb.sh flows versions commit <worker_id> <flow_id> --commit-message <msg>" >&2
                            exit 1
                        fi
                        worker_id="$4"
                        flow_id="$5"
                        shift 5
                        commit_message=""
                        while [ $# -gt 0 ]; do
                            case "$1" in
                                --commit-message) commit_message="${2:-}"; shift 2 ;;
                                *) echo "Unknown argument: $1" >&2; exit 1 ;;
                            esac
                        done
                        if [ -z "$commit_message" ]; then
                            echo "Usage: bb.sh flows versions commit <worker_id> <flow_id> --commit-message <msg>" >&2
                            exit 1
                        fi
                        require_jq
                        request POST "/workers/$worker_id/flows/$flow_id/versions" -d "$(jq -n --arg commitMessage "$commit_message" '{commitMessage: $commitMessage}')"
                        ;;
                    *)
                        echo "Usage: bb.sh flows versions [list|get|commit] <worker_id> <flow_id> [args]" >&2
                        exit 1
                        ;;
                esac
                ;;
            *)
                echo "Usage: bb.sh flows [list|get|create|update|versions] <worker_id> [args]" >&2
                exit 1
                ;;
        esac
        ;;
    deployments)
        case "${2:-}" in
            list)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh deployments list <worker_id> [--type voice|chat|chat-embed|voicev1]" >&2
                    exit 1
                fi
                worker_id="$3"
                shift 3
                type="voice"
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --type) type="${2:-}"; shift 2 ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
                    esac
                done
                request GET "/workers/$worker_id/deployments/$type"
                ;;
            get)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh deployments get <deployment_id> [--include <relations>]" >&2
                    exit 1
                fi
                deployment_id="$3"
                shift 3
                query=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --include) query="$(add_query_param "$query" "include" "${2:-}")"; shift 2 ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
                    esac
                done
                path="/deployments/$deployment_id"
                if [ -n "$query" ]; then
                    path="$path?$query"
                fi
                request GET "$path"
                ;;
            create-voice)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh deployments create-voice <worker_id> --flow-id <flow_id> --phone <e164> --name <name> [--engine-version v2] [--create-sip-trunk]" >&2
                    exit 1
                fi
                worker_id="$3"
                shift 3
                flow_id=""
                phone=""
                name=""
                engine_version="v2"
                create_sip_trunk="false"
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --flow-id) flow_id="${2:-}"; shift 2 ;;
                        --phone|--phone-number) phone="${2:-}"; shift 2 ;;
                        --name) name="${2:-}"; shift 2 ;;
                        --engine-version) engine_version="${2:-}"; shift 2 ;;
                        --create-sip-trunk) create_sip_trunk="true"; shift ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
                    esac
                done
                if [ -z "$flow_id" ] || [ -z "$phone" ] || [ -z "$name" ]; then
                    echo "Usage: bb.sh deployments create-voice <worker_id> --flow-id <flow_id> --phone <e164> --name <name> [--engine-version v2] [--create-sip-trunk]" >&2
                    exit 1
                fi
                require_jq
                json="$(jq -n \
                    --arg name "$name" \
                    --arg phoneNumber "$phone" \
                    --arg flowId "$flow_id" \
                    --arg engineVersion "$engine_version" \
                    '{name: $name, phoneNumber: $phoneNumber, flowId: $flowId, externalConfig: {engineVersion: $engineVersion}}')"
                if [ "$create_sip_trunk" = "true" ]; then
                    json="$(json_add_bool "$json" "createSipTrunk" "true")"
                fi
                request POST "/workers/$worker_id/deployments/voice" -d "$json"
                ;;
            *)
                echo "Usage: bb.sh deployments [list|get|create-voice] [args]" >&2
                exit 1
                ;;
        esac
        ;;
    logs)
        case "${2:-}" in
            list)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh logs list <worker_id> [--type voice|chat|chat-embed|sms|whatsapp] [--deployment-id <id>] [--flow-id <id>] [--limit <n>] [--cursor <cursor>] [--fields <csv>]" >&2
                    exit 1
                fi
                worker_id="$3"
                shift 3
                type="voice"
                query=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --type) type="${2:-}"; shift 2 ;;
                        --deployment-id) query="$(add_query_param "$query" "deploymentId" "${2:-}")"; shift 2 ;;
                        --flow-id) query="$(add_query_param "$query" "flowId" "${2:-}")"; shift 2 ;;
                        --limit) query="$(add_query_param "$query" "limit" "${2:-}")"; shift 2 ;;
                        --page) query="$(add_query_param "$query" "page" "${2:-}")"; shift 2 ;;
                        --cursor) query="$(add_query_param "$query" "cursor" "${2:-}")"; shift 2 ;;
                        --fields) query="$(add_query_param "$query" "fields" "${2:-}")"; shift 2 ;;
                        --search) query="$(add_query_param "$query" "searchQuery" "${2:-}")"; shift 2 ;;
                        --start-time-after) query="$(add_query_param "$query" "startTimeAfter" "${2:-}")"; shift 2 ;;
                        --start-time-before) query="$(add_query_param "$query" "startTimeBefore" "${2:-}")"; shift 2 ;;
                        --status) query="$(add_query_param "$query" "status" "${2:-}")"; shift 2 ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
                    esac
                done
                path="/workers/$worker_id/deploymentLogs/$type"
                if [ -n "$query" ]; then
                    path="$path?$query"
                fi
                request GET "$path"
                ;;
            get)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh logs get <log_id>" >&2
                    exit 1
                fi
                request GET "/logs/$3"
                ;;
            *)
                echo "Usage: bb.sh logs [list|get] [args]" >&2
                exit 1
                ;;
        esac
        ;;
    tags)
        case "${2:-list}" in
            list)
                request GET "/team/tags"
                ;;
            create)
                if [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                    echo "Usage: bb.sh tags create <label> <color>" >&2
                    exit 1
                fi
                require_jq
                request POST "/team/tags" -d "$(jq -n --arg label "$3" --arg color "$4" '{label: $label, color: $color}')"
                ;;
            update)
                if [ -z "${3:-}" ]; then
                    echo "Usage: bb.sh tags update <tag_id> [--label <label>] [--color <color>]" >&2
                    exit 1
                fi
                tag_id="$3"
                shift 3
                json="{}"
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --label) json="$(json_add_string "$json" "label" "${2:-}")"; shift 2 ;;
                        --color) json="$(json_add_string "$json" "color" "${2:-}")"; shift 2 ;;
                        *) echo "Unknown argument: $1" >&2; exit 1 ;;
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
                echo "Usage: bb.sh tags [list|create|update|delete] [args]" >&2
                exit 1
                ;;
        esac
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
