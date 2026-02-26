# AgentEval for NanoClaw (Alpha Quickstart)

This guide is for NanoClaw users who want to try `AgentEval` as a replay-first regression testing workflow.

## What You Can Try Today

`AgentEval` currently supports:

- replay-based agent regression tests (`test.yaml` + `replay.json`)
- passing/failing/error suites
- tool/process/output assertions
- scheduler assertions
- retry/failure messaging assertions
- replay validation error cases for malformed inputs

It does **not** require a live NanoClaw runtime to get started.

## 5-Minute Trial

From the `agent_eval` repo root:

```bash
ruby bin/agenteval run examples/nanoclaw
# or (short wrapper)
./bin/aeval run examples/nanoclaw
# expected exit: 0

ruby bin/agenteval run examples/nanoclaw-failing
# expected exit: 1

ruby bin/agenteval run examples/nanoclaw-error
# expected exit: 2

ruby bin/agenteval-smoke
# expected exit: 0
```

## What To Look At First

Good starter examples:

- `examples/nanoclaw/current-news/`
- `examples/nanoclaw/scheduler-digest-timeout-recovery/`
- `examples/nanoclaw/scheduler-digest-tool-failure-graceful/`
- `examples/nanoclaw-failing/scheduler-digest-tool-failure-misleading-success/`

## How To Create Your First NanoClaw Regression Case

1. Pick a real NanoClaw behavior you care about.
   - Example: “Daily digest should send once”
   - Example: “Tool timeout should not produce fake success message”

2. Copy the closest example directory.

3. Edit `test.yaml`
   - change `id`, `title`, `description`
   - keep only the assertions you want

4. Edit `replay.json`
   - simulate the tool calls/results/errors you expect (or the regression you want to catch)

5. Run just that scenario:

```bash
./bin/aeval run examples/nanoclaw/<your-scenario-dir>
```

## Current High-Value Assertion Areas for NanoClaw

- tool usage and ordering (`must_call_tool`, `tool_call_order`)
- scheduler behavior (`scheduler_task_runs`, `scheduler_outbound_count`)
- retry behavior (`retry_policy_respected`)
- failure messaging (`graceful_failure_output`)
- groundedness (`claims_supported_by_fixtures`)

## Contributing a Real NanoClaw Regression Example

The most helpful contributions are:

- one replay scenario from a real failure mode
- one assertion-focused failing variant that proves the regression is caught
- clear expected exit behavior (`0`, `1`, or `2`)

See also:

- `README.md`
- `docs/nanoclaw/replay-input.md`
- `context.md`
