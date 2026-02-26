---
name: agent-eval
description: Use when creating, debugging, or expanding AgentEval replay tests (test.yaml + replay.json), especially for NanoClaw agent regressions, tool-call assertions, scheduler behavior, memory/isolation checks, and malformed replay validation cases.
---

# AgentEval

## Overview

Use this skill to create or debug AgentEval replay scenarios in this repo.

This skill is best for:

- writing `examples/**/test.yaml` + `replay.json` pairs
- adding passing/failing/error regression scenarios
- choosing assertions for NanoClaw behaviors (tool use, scheduler, retry/failure messaging, memory/isolation)
- validating expected exit behavior (`0` pass, `1` fail, `2` error)

## Quick Workflow

1. Read the current project state:
   - `README.md`
   - `context.md`
   - `docs/nanoclaw/replay-input.md`
2. Pick scenario type:
   - passing behavior (`examples/nanoclaw`)
   - failing regression variant (`examples/nanoclaw-failing`)
   - malformed replay / runner error case (`examples/nanoclaw-error`)
3. Copy a nearby example and modify the smallest number of fields needed.
4. Run validation:
   - `ruby bin/agenteval run <scenario-dir-or-suite>`
   - `ruby bin/agenteval-smoke`
5. If changing schemas/docs:
   - `make schema-smoke`

## Scenario Authoring Rules

- Prefer deterministic, minimal replays.
- Use existing fixture IDs and tool names when possible.
- Keep one primary behavior per scenario.
- For failing variants, target a specific assertion and make the failure obvious.
- For error-path cases, fail replay validation before assertion execution.

## Scenario Type Guide

### Passing scenario (`examples/nanoclaw`)

Use when adding supported/expected agent behavior.

Typical assertions:

- `must_call_tool`
- `tool_call_order`
- `tool_args_match`
- `claims_supported_by_fixtures`
- `scheduler_task_runs`
- `scheduler_outbound_count`
- `retry_policy_respected`
- `graceful_failure_output`

### Failing regression variant (`examples/nanoclaw-failing`)

Use when proving the framework catches a known bad behavior.

Typical patterns:

- wrong tool order
- duplicate outbound sends
- unsupported claims
- retry policy exceeded
- misleading success message after tool error

### Error-path replay validation case (`examples/nanoclaw-error`)

Use when testing runner/normalizer validation.

Typical patterns:

- missing `scenario.trigger`
- scheduler trigger missing `scheduler_context`
- `tool_result` unknown `call_id`
- `status=success` without `final_output.content`

## Validation Commands

From repo root:

```bash
ruby bin/agenteval run examples/nanoclaw
ruby bin/agenteval run examples/nanoclaw-failing
ruby bin/agenteval run examples/nanoclaw-error
ruby bin/agenteval-smoke
make schema-smoke
```

Expected exits:

- pass suite: `0`
- failing suite: `1`
- error suite: `2`
- smoke: `0`

## When To Read References

- For replay shape details and step field names: read `references/nanoclaw-replay-and-assertions.md`
- For assertion selection examples and scenario naming: read `references/nanoclaw-replay-and-assertions.md`
