# Demo Wallet

A fictional mobile wallet whose real subject is in-app support built on
[ElevenLabs Agents](https://elevenlabs.io/docs/agents-platform/overview). The
customer reports a suspicious charge by chat or by voice, and the agent
verifies them, freezes the card, opens a dispute and secures the account by
calling tools that act on the app in real time. Anything it can't resolve
goes to a human with the conversation attached.

## Run

```bash
# 1. Create or update the agent (needs ELEVENLABS_API_KEY in .env)
python3 agent/create_agent.py
python3 agent/create_agent.py --check   # reports drift from dashboard edits

# 2. Run on an iPhone. Voice calls abort in the iOS Simulator: WebRTC's
#    voice-processing audio unit times out there (a known simulator issue).
#    Signing: put your team in ios/Flutter/Signing.xcconfig (git-ignored):
#      DEVELOPMENT_TEAM = YOUR_TEAM_ID
fvm flutter run --dart-define-from-file=config/dev.json

# 3. Checks
fvm flutter analyze    # strict casts, inference and raw types, plus extra lints
fvm flutter test
```

## Architecture

```
lib/
  wallet/      the account: immutable models, demo data, WalletState
  support/     everything the agent touches, free of UI
    support_hub.dart         the one conversation the app can have, above the navigator
    support_session.dart     a conversation's state machine (sealed states)
    support_transport.dart   voice (SDK, WebRTC) and chat (WebSocket) behind one interface
    chat_connection.dart     the Agents WebSocket protocol for text chat
    support_tools.dart       the client tools, with policy enforced in code
    identity_verifier.dart   card-digit check with a lockout that outlives conversations
    agent_context.dart       every string the app sends the agent
    diagnostics.dart         copyable, sanitised failure details
  screens/     home and support UI, split into small widgets
  theme.dart   colour tokens (ThemeExtension); widgets never hard-code colours
agent/         agent config, prompt and the script that deploys them
```

Data flows one way: the agent calls a tool, the tool changes `WalletState`,
and the home screen rebuilds. That is why a minimized call can show the card
turning "Frozen" while the agent is still talking.

## Decisions

- **Two transports.** Voice needs WebRTC for low latency and echo
  cancellation, so it uses the ElevenLabs Flutter SDK. Text chat uses the
  WebSocket API directly and never opens the microphone.
- **Conversations outlive screens.** The hub owns the conversation, so it can
  be minimized and resumed. Only one exists at a time, and follow-ups keep the
  first reference ID, so a customer never ends up with several.
- **Every attempt gets a fresh transport.** Events from an earlier attempt
  are ignored, so a late "connected" can't revive a conversation the customer
  already ended, and a double tap can't open two connections.
- **Policy lives in code, not in the prompt.** Account actions fail until
  identity is verified. Repeating an action is harmless. A throwing tool still
  answers the agent. Three wrong answers lock verification for 15 minutes,
  across conversations.
- **Evaluation judges tool calls, not words.** An early test call had the
  agent claim it froze the card without calling the tool, and the first
  evaluation criteria passed it. They now check the transcript's tool results.
- **Config as code.** The agent, its tools and its prompt live in `agent/`.
  The deploy script is idempotent, reads everything back, and `--check`
  reports drift. A contract test fails if tool or variable names differ
  between the config, the prompt and the app.
- **Consent first.** A recording notice is shown, and enforced by the hub,
  before any conversation starts. The agent really does record calls.

## What production would change

- Verification and account actions would be **server tools** calling the
  bank's backend. As client tools they run on the device, where a modified
  app could fake a successful check.
- A **private agent** with short-lived conversation tokens issued by the
  backend after login, rather than a public agent ID in the app.
- PII redaction and a retention period on conversations (redaction needs an
  enterprise plan), and background audio so a call survives leaving the app.
