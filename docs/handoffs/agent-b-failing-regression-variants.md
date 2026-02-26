# Agent Handoff Template

## Agent

- Name: Agent B
- Task packet / goal: Expand failing/error example coverage using existing assertions and replay validation only (no core runtime/assertion changes)
- Status: `completed`

## Scope

- Allowed files:
  - `./examples/nanoclaw-failing/**`
  - `./examples/nanoclaw-error/**`
  - `./docs/handoffs/agent-b-failing-regression-variants.md`
- Files actually changed:
  - `./examples/nanoclaw-failing/current-news-claims-unsupported/test.yaml`
  - `./examples/nanoclaw-failing/current-news-tool-args-mismatch/test.yaml`
  - `./examples/nanoclaw-failing/scheduler-duplicate-outbound-send/test.yaml`
  - `./examples/nanoclaw-failing/scheduler-duplicate-outbound-send/replay.json`
  - `./examples/nanoclaw-error/missing-adapter-input-replay-file-field/test.yaml`
  - `./docs/handoffs/agent-b-failing-regression-variants.md`

## Summary of Changes

- Added failing variant for `claims_supported_by_fixtures` by restricting `allowed_sources` to `web_fetch` only while reusing the existing current-news replay.
- Added failing variant for `tool_args_match` by imposing intentionally wrong `web_search` arg constraints (`finance earnings`, `stock|market`) against the current-news replay.
- Added failing variant for `max_tool_calls` with a new replay that duplicates `outbound_send`, then asserts `max: 1`.
- Added error variant spec that omits `adapter_input.replay_file`, targeting runner/spec validation before replay load.

## Validation Run

List commands run and exit codes.

```bash
# jq . examples/nanoclaw-failing/scheduler-duplicate-outbound-send/replay.json >/dev/null
# exit code: 0

# ruby bin/agenteval run examples/nanoclaw-failing
# exit code: 1

# ruby bin/agenteval run examples/nanoclaw-error
# exit code: 2

# ruby bin/agenteval-smoke
# exit code: 0
```

## Expected Behavior Change

- `nanoclaw.current-news.failing.claims-unsupported-by-fixtures`
  - should fail `claims-must-be-supported-by-web-fetch-only-negative-control` (`claims_supported_by_fixtures`)
- `nanoclaw.current-news.failing.tool-args-mismatch`
  - should fail `incorrect-query-constraints-negative-control` (`tool_args_match`)
- `nanoclaw.scheduler.daily-digest.failing.duplicate-outbound-send`
  - should fail `single-send-negative-control` (`max_tool_calls`)
- `nanoclaw.error.missing-adapter-input-replay-file-field`
  - should produce an `error` result (runner validation) and contribute to suite exit code `2`

## Known Limitations / Follow-ups

- The error suite now mixes replay-validation/spec-validation cases. If desired, split into subfolders by error source (`spec-parse`, `replay-validate`, `io`) for easier triage.
- Diagnostics for error cases are good at the CLI level, but there is still no assertion-style evidence object because errors happen before assertions run.

## Merge Notes (for Orchestrator)

- Conflict risk: low (example fixtures/specs + handoff doc only)
- Suggested merge order: after any concurrent changes to example directories are reconciled
- Anything that must be checked after merge: rerun `ruby bin/agenteval-smoke` to confirm suite exit expectations remain `0/1/2`
