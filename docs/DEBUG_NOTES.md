# Debugging notes

Four issues I hit while building this demo.

| # | Issue | Cause |
|---|---|---|
| 1 | The AI agent said it froze the card, but didn't | It never called the tool |
| 2 | Calls fail instantly with "error" | The agent's daily call limit |
| 3 | Follow-up chat closed with 1008 | First-message overrides aren't on the Free plan |
| 4 | 400 when changing the model | `PATCH` kept the old `reasoning_effort` |

---

## 1. The AI agent said it froze the card, but didn't

**What happened:** On a real call the agent said "I've gone ahead and frozen
your card… I've also opened a dispute." The card in the app stayed Active, yet
all three evaluation criteria passed.

**Steps:**
1. Open the call's transcript and look at the tool calls: `verify_identity` and
   `secure_account`, but no `freeze_card` and no `dispute_transaction`.
2. Compare the timelines: the agent promised 5 and 90 days; the dispute tool
   returns 1 and 10.

**Cause:** The prompt described the flow as a story, so the model narrated it
instead of calling the tools. The evaluations are judged by an LLM reading the
transcript, so it believed the agent too.

**Fix:**
1. Actions only happen through tools, and the app shows an action only after
   its tool succeeds.
2. Prompt rule: nothing is done until its tool result is back, and timelines
   come only from tool results.
3. Evaluations judge tool calls, not words.

**Takeaway:** When an AI agent says it did something, check the tool calls.

---

## 2. Calls fail instantly with "error"

**What happened:** Tapping Call immediately showed "Could not reach support".
The app only got `"error"`, with no code.

**Steps:**
1. The agent's daily call limit is 20.
2. After a day of testing (calls, chats and test scripts), the next call is
   refused.
3. The conversation list shows that attempt as failed with 4300: "Agent … has
   exceeded its daily call limit of 20."

**Cause:** The agent's daily call limit, which I had set to 20. The server
recorded the reason (code 4300 in the conversation list), but for voice the
Flutter SDK reports a dropped or refused connection only as `'error'`, so the
app never sees it.

**Fix:** Raised the limit to 50.

**Takeaway:** When calls fail, check the conversation list before the client.

---

## 3. Follow-up chat closed with 1008

**What happened:** "Still need help?" started a chat with a custom first message
("Welcome back…"). The server closed it with 1008: "Override for field
'first_message' is not allowed by config."

**Steps:**
1. On the Free plan, enable an agent's first-message override through the API.
   It reads back as `true`.
2. Start a conversation that overrides the first message.
3. The server accepts the connection, then closes it with 1008: "Override for
   field 'first_message' is not allowed by config."

**Cause:** First-message overrides aren't available on the Free plan. Only the
dashboard says so: the switch is locked, with the tooltip "First message
overrides are not available on the Free plan." The API still accepts the
setting, and the error blames the config.

**Fix:** Use a dynamic variable instead. The first message is the template
`{{opening}} I'm an AI assistant…`, and the app sends `opening`. It works on
the Free plan, and the AI disclosure stays in the agent's config.

**Takeaway:** For 1008 on an override that is switched on, check the plan.

---

## 4. 400 when changing the model

**What happened:** Switching an agent from `gemini-3.5-flash` (reasoning effort
`low`) to `gemini-2.5-flash` returned a 400: "Reasoning effort is not supported
for this LLM."

**Steps:**
1. Set the agent to `gemini-3.5-flash` with `"reasoning_effort": "low"`.
2. `PATCH` the model to `gemini-2.5-flash` without `reasoning_effort`.
3. The API returns 400 `invalid_parameters` with
   `"param": "conversation_config.agent.prompt"` and "Reasoning effort is not
   supported for this LLM." Nothing is changed.

**Cause:** `PATCH` only changes the fields you send, so the old
`reasoning_effort` stayed, and `gemini-2.5-flash` doesn't support it.

**Fix:** Send `"reasoning_effort": null` with the model change. Returns 200.

**Takeaway:** With `PATCH`, clear a field explicitly; leaving it out keeps it.
