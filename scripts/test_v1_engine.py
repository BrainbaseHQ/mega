#!/usr/bin/env python3
"""
test_v1_engine.py — Test a Based flow on the v1 engine over WebSocket.

Connects to the v1 engine, initializes a session, sends a sequence of user
messages, and prints the conversation in real time. Useful for verifying
flow behavior before deploying to a live channel.

Requires: pip install websockets

Environment (from .env):
  BRAINBASE_API_KEY     Team API key (required)
  V1_ENGINE_URL         Engine WebSocket base URL
                        (default: wss://brainbase-engine-python.onrender.com)

Usage:
  python scripts/test_v1_engine.py <worker_id> <flow_id> <message> [<message> ...]

Examples:
  # Simple greeting test
  python scripts/test_v1_engine.py worker_abc flow_def "Hello" "I'd like to book"

  # Multi-turn conversation
  python scripts/test_v1_engine.py worker_abc flow_def \\
    "I'd like to book a tee time" \\
    "My email is test@example.com" \\
    "Yes that's correct"

Options:
  --model MODEL         LLM model to use (default: gpt-4o)
  --state '{"key":"v"}' Initial state JSON to pass to the flow
  --no-streaming        Disable streaming (get full responses instead)
  --timeout SECONDS     Max seconds to wait for each agent response (default: 60)
"""
import argparse
import asyncio
import json
import os
import sys

try:
    import websockets
except ImportError:
    print("Missing dependency: pip install websockets", file=sys.stderr)
    sys.exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, "..", ".env")

DEFAULT_ENGINE_URL = "wss://brainbase-engine-python.onrender.com"


def load_env():
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, _, val = line.partition("=")
                    os.environ.setdefault(key.strip(), val.strip())


def parse_args():
    parser = argparse.ArgumentParser(
        description="Test a Based flow on the v1 engine via WebSocket.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage:")[0].strip(),
    )
    parser.add_argument("worker_id", help="Worker ID (worker_...)")
    parser.add_argument("flow_id", help="Flow ID (flow_...)")
    parser.add_argument("messages", nargs="+", help="User messages to send in order")
    parser.add_argument("--model", default="gpt-4o", help="LLM model (default: gpt-4o)")
    parser.add_argument("--state", default="{}", help="Initial state JSON (default: {})")
    parser.add_argument("--no-streaming", action="store_true", help="Disable streaming")
    parser.add_argument("--timeout", type=int, default=60, help="Response timeout in seconds (default: 60)")
    return parser.parse_args()


async def run_session(
    engine_url: str,
    worker_id: str,
    flow_id: str,
    api_key: str,
    messages: list[str],
    model: str = "gpt-4o",
    initial_state: dict = None,
    streaming: bool = True,
    timeout: int = 60,
):
    """Run a test session against the v1 engine. Prints conversation to stdout."""

    ws_url = (
        f"{engine_url}/{worker_id}/{flow_id}"
        f"?model={model}&api_key={api_key}&source=test&reset=1"
    )

    async with websockets.connect(
        ws_url,
        extra_headers={"Origin": "https://beta.usebrainbase.com"},
        ping_interval=20,
        ping_timeout=120,
    ) as ws:
        turn_done = asyncio.Event()
        flow_done = asyncio.Event()
        current_stream: list[str] = []
        transcript: list[dict] = []

        async def listen():
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                action = msg.get("action")
                data = msg.get("data", {})
                if isinstance(data, str):
                    try:
                        data = json.loads(data)
                    except (json.JSONDecodeError, TypeError):
                        pass

                if action == "initialized":
                    sid = data.get("sessionId") if isinstance(data, dict) else data
                    print(f"[session {sid}]", flush=True)

                elif action == "stream":
                    chunk = data.get("message", "") if isinstance(data, dict) else ""
                    end = data.get("end", False) if isinstance(data, dict) else False
                    print(chunk, end="", flush=True)
                    current_stream.append(chunk)
                    if end:
                        full = "".join(current_stream)
                        current_stream.clear()
                        print(flush=True)
                        transcript.append({"role": "agent", "text": full})
                        turn_done.set()

                elif action in ("message", "response"):
                    text = data.get("message", "") if isinstance(data, dict) else str(data)
                    print(text, flush=True)
                    transcript.append({"role": "agent", "text": text})
                    turn_done.set()

                elif action == "function_call":
                    fn = data.get("function", "") if isinstance(data, dict) else str(data)
                    print(f"  [tool: {fn}]", flush=True)

                elif action == "return_to_context":
                    val = str(msg.get("message", ""))[:300]
                    print(f"  [context: {val}]", flush=True)

                elif action == "done":
                    print("[flow ended]", flush=True)
                    flow_done.set()
                    turn_done.set()

                elif action == "error":
                    err = data.get("message", "") if isinstance(data, dict) else str(data)
                    print(f"[error: {err}]", flush=True)
                    turn_done.set()

                else:
                    print(f"  [{action}]", flush=True)

        listener = asyncio.create_task(listen())

        # Initialize session
        await ws.send(json.dumps({
            "action": "initialize",
            "data": json.dumps({
                "streaming": streaming,
                "deploymentType": "production",
                "source": "client",
                "state": initial_state or {},
            }),
        }))

        # Wait for greeting
        try:
            await asyncio.wait_for(turn_done.wait(), timeout=timeout)
        except asyncio.TimeoutError:
            if current_stream:
                full = "".join(current_stream)
                current_stream.clear()
                print(flush=True)
                transcript.append({"role": "agent", "text": full})
        turn_done.clear()

        # Send each user message, wait for agent response
        for msg_text in messages:
            if flow_done.is_set():
                break

            print(f"\n>>> {msg_text}", flush=True)
            transcript.append({"role": "user", "text": msg_text})

            await ws.send(json.dumps({
                "action": "message",
                "data": {"message": msg_text},
            }))

            try:
                await asyncio.wait_for(turn_done.wait(), timeout=timeout)
            except asyncio.TimeoutError:
                if current_stream:
                    full = "".join(current_stream)
                    current_stream.clear()
                    print(flush=True)
                    transcript.append({"role": "agent", "text": full})
                else:
                    print("[timeout — no response]", flush=True)
            turn_done.clear()

        # Wait for any trailing responses (API calls in progress)
        if not flow_done.is_set():
            try:
                await asyncio.wait_for(flow_done.wait(), timeout=min(timeout, 30))
            except asyncio.TimeoutError:
                pass

        listener.cancel()
        try:
            await listener
        except asyncio.CancelledError:
            pass

        return transcript


def main():
    load_env()
    args = parse_args()

    api_key = os.environ.get("BRAINBASE_API_KEY", "")
    if not api_key:
        print("Error: BRAINBASE_API_KEY is not set. Add it to .env", file=sys.stderr)
        sys.exit(1)

    engine_url = os.environ.get("V1_ENGINE_URL", DEFAULT_ENGINE_URL)

    try:
        initial_state = json.loads(args.state)
    except json.JSONDecodeError:
        print(f"Error: --state must be valid JSON, got: {args.state}", file=sys.stderr)
        sys.exit(1)

    transcript = asyncio.run(run_session(
        engine_url=engine_url,
        worker_id=args.worker_id,
        flow_id=args.flow_id,
        api_key=api_key,
        messages=args.messages,
        model=args.model,
        initial_state=initial_state,
        streaming=not args.no_streaming,
        timeout=args.timeout,
    ))


if __name__ == "__main__":
    main()
