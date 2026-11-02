#!/usr/bin/env python3
"""Create or update the Demo Wallet support agent from agent/agent_config.json.

Standard library only (Python 3.9+), so it runs on a stock Mac.

    export ELEVENLABS_API_KEY=...          # or put it in .env at the repo root
    python3 agent/create_agent.py          # first run: creates tools + agent
    python3 agent/create_agent.py          # later runs: updates them in place
    python3 agent/create_agent.py --check  # reports drift (e.g. edits made in
                                           # the dashboard), changes nothing

The API key needs the ElevenAgents permission (Agents: write).
Created IDs are stored in agent/.state.json (git-ignored) and the agent ID is
written to config/dev.json for `flutter run --dart-define-from-file`.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.elevenlabs.io"
ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "agent" / "agent_config.json"
PROMPT = ROOT / "agent" / "system_prompt.md"  # kept separate so it reads like a document
STATE = ROOT / "agent" / ".state.json"
DART_DEFINES = ROOT / "config" / "dev.json"


class ApiError(Exception):
    pass


def load_api_key():
    key = os.environ.get("ELEVENLABS_API_KEY")
    env_file = ROOT / ".env"
    if not key and env_file.exists():
        for line in env_file.read_text().splitlines():
            name, _, value = line.partition("=")
            if name.strip() == "ELEVENLABS_API_KEY":
                key = value.strip().strip('"').strip("'")
    if not key:
        sys.exit("ELEVENLABS_API_KEY is not set (environment or .env).")
    return key


def call(method, path, key, body=None):
    """Sends a request and returns parsed JSON, or raises ApiError with the
    details a support engineer would ask for."""
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={"xi-api-key": key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raw = error.read().decode(errors="replace")
        try:
            detail = json.loads(raw).get("detail", raw)
        except ValueError:
            detail = raw
        # Some errors (e.g. model_not_found) carry the ID only in x-trace-id.
        request_id = (error.headers.get("request-id") or error.headers.get("x-request-id")
                      or error.headers.get("x-trace-id"))
        if isinstance(detail, dict):
            request_id = request_id or detail.get("request_id")
        raise ApiError(
            "{} {} -> HTTP {}\nrequest_id: {}\ndetail: {}".format(
                method, path, error.code, request_id,
                json.dumps(detail, indent=2, ensure_ascii=False),
            )
        )
    except urllib.error.URLError as error:
        raise ApiError("{} {} -> network error: {}".format(method, path, error.reason))


def load_state():
    return json.loads(STATE.read_text()) if STATE.exists() else {"tools": {}}


def save_state(state):
    STATE.write_text(json.dumps(state, indent=2) + "\n")


def sync_tools(config, state, key):
    tool_ids = []
    for tool in config["tools"]:
        name = tool["name"]
        existing = state["tools"].get(name)
        if existing:
            call("PATCH", "/v1/convai/tools/" + existing, key, {"tool_config": tool})
            print("  updated tool  {:<26} {}".format(name, existing))
            tool_ids.append(existing)
        else:
            created = call("POST", "/v1/convai/tools", key, {"tool_config": tool})
            state["tools"][name] = created["id"]
            save_state(state)
            print("  created tool  {:<26} {}".format(name, created["id"]))
            tool_ids.append(created["id"])
    return tool_ids


def agent_payload(config, tool_ids):
    """The agent exactly as it should exist remotely: config plus prompt file."""
    agent = json.loads(json.dumps(config["agent"]))  # deep copy
    prompt = agent["conversation_config"]["agent"]["prompt"]
    prompt["prompt"] = PROMPT.read_text().strip()
    prompt["tool_ids"] = tool_ids
    return agent


def sync_agent(config, state, tool_ids, key):
    agent = agent_payload(config, tool_ids)
    agent_id = state.get("agent_id")
    if agent_id:
        call("PATCH", "/v1/convai/agents/" + agent_id, key, agent)
        print("  updated agent {}".format(agent_id))
    else:
        agent_id = call("POST", "/v1/convai/agents/create", key, agent)["agent_id"]
        state["agent_id"] = agent_id
        save_state(state)
        print("  created agent {}".format(agent_id))
    return agent_id


def drift(local, remote, path=""):
    """Paths where the remote value differs from what we manage locally.
    Only keys present locally are compared: the server adds many defaults."""
    if isinstance(local, dict):
        if not isinstance(remote, dict):
            return [path or "/"]
        found = []
        for key, value in local.items():
            found += drift(value, remote.get(key), "{}.{}".format(path, key).lstrip("."))
        return found
    if isinstance(local, list):
        if not isinstance(remote, list) or len(local) != len(remote):
            return [path]
        found = []
        for i, (a, b) in enumerate(zip(local, remote)):
            found += drift(a, b, "{}[{}]".format(path, i))
        return found
    return [] if local == remote else [path]


def check(config, state, key):
    """Exit code 1 if the live agent or tools no longer match the files."""
    if "agent_id" not in state:
        sys.exit("No agent yet. Run without --check to create it.")
    problems = []
    for tool in config["tools"]:
        tool_id = state["tools"].get(tool["name"])
        if not tool_id:
            problems.append("tool {}: not created yet".format(tool["name"]))
            continue
        remote = call("GET", "/v1/convai/tools/" + tool_id, key).get("tool_config", {})
        problems += ["tool {}: {}".format(tool["name"], p) for p in drift(tool, remote)]
    tool_ids = [state["tools"][t["name"]] for t in config["tools"] if t["name"] in state["tools"]]
    remote_agent = call("GET", "/v1/convai/agents/" + state["agent_id"], key)
    problems += ["agent: " + p for p in drift(agent_payload(config, tool_ids), remote_agent)]
    if problems:
        print("Drift found (run without --check to overwrite with the files):")
        for problem in problems:
            print("  " + problem)
        sys.exit(1)
    print("In sync: the live agent and tools match the files.")


def warn_orphans(config, state):
    configured = {tool["name"] for tool in config["tools"]}
    for name, tool_id in state["tools"].items():
        if name not in configured:
            print("  warning: tool {} ({}) is no longer in the config. It is detached "
                  "from the agent but still exists; delete it in the dashboard.".format(name, tool_id))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="report differences between the files and the live agent, change nothing")
    args = parser.parse_args()
    key = load_api_key()
    config = json.loads(CONFIG.read_text())
    state = load_state()
    if args.check:
        try:
            check(config, state, key)
        except ApiError as error:
            sys.exit("\nRequest failed:\n{}".format(error))
        return
    try:
        print("Syncing tools…")
        tool_ids = sync_tools(config, state, key)
        warn_orphans(config, state)
        print("Syncing agent…")
        agent_id = sync_agent(config, state, tool_ids, key)
    except ApiError as error:
        sys.exit("\nRequest failed:\n{}".format(error))

    DART_DEFINES.parent.mkdir(exist_ok=True)
    DART_DEFINES.write_text(json.dumps({"ELEVENLABS_AGENT_ID": agent_id}, indent=2) + "\n")
    print("\nDone. Agent ID written to config/dev.json")
    print("Dashboard: https://elevenlabs.io/app/agents/agents/" + agent_id)


if __name__ == "__main__":
    main()
