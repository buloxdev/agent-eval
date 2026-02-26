# NanoClaw PR / Discussion Blurb (AgentEval Alpha)

## Short version

I built an open-source replay-first regression testing framework for tool-using agents called `AgentEval`, with NanoClaw as the first target use case.

It lets you write deterministic test scenarios (`test.yaml` + `replay.json`) and validate:

- tool calls and ordering
- scheduler behavior
- retry policy behavior
- failure messaging (no misleading success after errors)
- groundedness / unsupported claims
- malformed replay validation

## Why this might be useful for NanoClaw users

NanoClaw makes it easy to customize agent behavior, but that creates regression risk when changing prompts, tools, skills, or runtime logic.

`AgentEval` is meant to answer:

- “Did this change break behavior?”
- “Did the agent call the right tools?”
- “Did it retry correctly?”
- “Did it hallucinate or misreport failures?”

## Current status (alpha)

- replay-first (no live NanoClaw runtime integration required yet)
- passing / failing / error-path suites included
- scheduler + retry/failure assertions implemented
- schema files for test/trace/result artifacts included

## Quick try

```bash
./bin/aeval run examples/nanoclaw             # exit 0 (short wrapper)
ruby bin/agenteval run examples/nanoclaw        # exit 0
ruby bin/agenteval run examples/nanoclaw-failing # exit 1
ruby bin/agenteval run examples/nanoclaw-error   # exit 2
ruby bin/agenteval-smoke                         # exit 0
```

## What I’m looking for from NanoClaw users

- real regression cases (tool use, scheduler, retries, memory/isolation)
- examples of failure modes worth turning into assertions
- feedback on what a NanoClaw replay capture format should look like for easier authoring

## Optional: Codex skill included

The repo also includes a shareable `agent-eval` Codex skill for authoring/debugging replay scenarios:

- `skills/agent-eval/`

That can help contributors add tests faster without learning the whole repo structure first.
