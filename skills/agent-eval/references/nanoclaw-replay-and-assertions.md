# NanoClaw Replay + Assertion Reference (AgentEval)

Use this reference when building or debugging `AgentEval` scenarios in this repo.

## Directory Conventions

- Passing scenarios: `examples/nanoclaw/<scenario>/`
- Failing variants: `examples/nanoclaw-failing/<scenario>/`
- Error-path variants: `examples/nanoclaw-error/<scenario>/`

Each scenario typically contains:

- `test.yaml`
- `replay.json` (except `missing-replay-file` by design)

## Naming Patterns

Good IDs:

- `nanoclaw.current-news.requires-web-search`
- `nanoclaw.scheduler.daily-digest.timeout-recovery`
- `nanoclaw.scheduler.daily-digest.failing.retry-policy-exceeds-max`

## Replay Shape (Quick)

Top-level replay keys commonly used:

- `schema_version`
- `adapter`
- `scenario`
- `capabilities`
- `input_messages`
- `script`
- `final_output`
- `status`
- `metrics`

Important validation rules already enforced:

- `scenario.trigger` must be `user_message` or `scheduler`
- scheduler trigger requires `scenario.scheduler_context`
- `tool_result.call_id` must match a prior `tool_call.call_id`
- success status requires `final_output.content` (or a `final_output` script step with content)
- `metrics.timing_ms_total` required

## Common Script Step Types

- `tool_call`
- `tool_result`
- `error`
- `final_output`
- `memory_read` / `memory_write` (optional)

## Assertion Selection Cheatsheet

### Tool/process behavior

- `must_call_tool`
- `must_not_call_tool`
- `tool_call_order`
- `tool_args_match`
- `max_tool_calls`
- `stop_after_success`

### Output/groundedness

- `output_contains`
- `output_matches_format`
- `output_omits`
- `claims_supported_by_fixtures`

### Memory/isolation

- `memory_recall_same_group`
- `no_cross_group_memory_use`

### Scheduler/retry/failure

- `scheduler_task_runs`
- `scheduler_outbound_count`
- `retry_policy_respected`
- `graceful_failure_output`

## Failure Variant Design Tips

- Make exactly one behavior wrong when possible.
- Reuse a passing replay with stricter or inverted assertions for clean negative controls.
- If targeting `graceful_failure_output`, include:
  - at least one `error` step
  - a final output that either clearly reports failure (passing) or misleadingly claims success (failing)

## Commands

Run one scenario:

```bash
ruby bin/agenteval run examples/nanoclaw/<scenario>
```

Run suites:

```bash
ruby bin/agenteval run examples/nanoclaw
ruby bin/agenteval run examples/nanoclaw-failing
ruby bin/agenteval run examples/nanoclaw-error
ruby bin/agenteval-smoke
make schema-smoke
```
