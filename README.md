# AgentEval

Open-source regression testing framework for tool-using agents, with a first-pass `NanoClaw` replay adapter.

`AgentEval` checks both:

- what the agent answered (output assertions)
- how it got there (tool/process assertions)

This repo currently ships a minimal replay-mode runner plus example NanoClaw scenarios (passing and intentionally failing), plus error-path examples for runner/replay validation behavior.

## Current Status (Prototype)

Working today:

- replay-mode prototype (`test.yaml` + `replay.json`) with deterministic example suites
- CLI runner + JSON artifacts for traces/results
- replay validation and error-path handling for malformed inputs
- partial assertion coverage, including scheduler checks and retry policy checks

Not built yet:

- live NanoClaw execution mode
- full assertion catalog from the spec
- packaging/distribution

## What Works Today / What’s Experimental

What works today:

- deterministic replay-mode runs from `test.yaml` + `replay.json`
- passing, failing, and error-path example suites
- assertion reporting with pass/fail/error summaries and artifact output
- scheduler assertions (`scheduler_task_runs`, `scheduler_outbound_count`)
- retry policy assertion (`retry_policy_respected`)
- versioned JSON schema files for test cases, traces, and results (`schemas/`)
- schema smoke check (`bin/agenteval-schema-smoke`, `make schema-smoke`)
- privacy smoke check for local path/email leakage (`bin/agenteval-privacy-smoke`, `make privacy-smoke`)

What’s experimental:

- replay bundle validation coverage is still expanding
- groundedness checking is heuristic/rule-based (`claims_supported_by_fixtures`)
- assertion catalog coverage is partial relative to `SPEC.md`
- full instance validation against JSON Schemas is not wired into the runner/CI yet

## Known Limitations

- Groundedness checks are heuristic and can produce false positives/negatives.
- Replay-first mode is the primary path and does not cover all runtime-specific behavior.
- Live NanoClaw execution mode is not implemented yet.

## Why This Exists

Agent demos are easy. Regression testing agents is not.

This project is focused on a practical question:

- "If I change prompts/tools/skills/runtime logic, did my agent get worse?"

The v1 direction is CI-friendly, deterministic replay tests with explicit assertions over traces and outputs.

## Quick Start

### Requirements

- Ruby (tested with the system Ruby in this environment)

No external gems are required for the current prototype.

## Demo in 60 Seconds

Run from the repo root:

```bash
ruby bin/agenteval run examples/nanoclaw
# expected exit code: 0

ruby bin/agenteval run examples/nanoclaw-failing
# expected exit code: 1

ruby bin/agenteval run examples/nanoclaw-error
# expected exit code: 2

ruby bin/agenteval-smoke
# expected exit code: 0

make privacy-smoke
# expected exit code: 0
```

## Command Reference

Common suite commands (same as the demo block above):

- `./bin/aeval run examples/nanoclaw` -> expected exit `0` (thin wrapper for `bin/agenteval`)
- `ruby bin/agenteval run examples/nanoclaw` -> expected exit `0`
- `ruby bin/agenteval run examples/nanoclaw-failing` -> expected exit `1`
- `ruby bin/agenteval run examples/nanoclaw-error` -> expected exit `2`
- `ruby bin/agenteval-smoke` -> expected exit `0` (runs pass + fail + error suites)
- `make privacy-smoke` -> expected exit `0` (scans tracked files for local path/email/hostname leakage)

Current suite summaries (observed):

- passing suite (`examples/nanoclaw`): `6 passed, 0 failed, 0 errors`
- failing suite (`examples/nanoclaw-failing`): `0 passed, 8 failed, 0 errors`
- error-path suite (`examples/nanoclaw-error`): `0 passed, 0 failed, 6 errors`

## Example Test Structure

Each scenario is defined by:

- `test.yaml`: scenario + assertions
- `replay.json`: replayed NanoClaw execution transcript (adapter input)

Examples:

- `examples/nanoclaw/current-news/test.yaml`
- `examples/nanoclaw/current-news/replay.json`
- `examples/nanoclaw/memory-same-group/test.yaml`
- `examples/nanoclaw/memory-same-group/replay.json`
- `examples/nanoclaw/scheduler-digest-timeout-recovery/test.yaml`
- `examples/nanoclaw/scheduler-digest-timeout-recovery/replay.json`
- `examples/nanoclaw/scheduler-digest-tool-failure-graceful/test.yaml`
- `examples/nanoclaw/scheduler-digest-tool-failure-graceful/replay.json`
- `examples/nanoclaw-failing/scheduler-retry-policy-exceeds-max/test.yaml`
- `examples/nanoclaw-failing/scheduler-digest-tool-failure-misleading-success/test.yaml`

## Assertions Implemented (Current Prototype)

Implemented now:

- `must_call_tool`
- `must_not_call_tool`
- `tool_call_order`
- `tool_args_match`
- `max_tool_calls`
- `stop_after_success`
- `output_contains`
- `output_matches_format`
- `output_omits`
- `claims_supported_by_fixtures` (heuristic)
- `memory_recall_same_group`
- `no_cross_group_memory_use`
- `scheduler_task_runs`
- `scheduler_outbound_count`
- `retry_policy_respected`
- `graceful_failure_output`

Planned next (from the v1 cut / broader spec):

- additional retry/failure-policy assertions (beyond `graceful_failure_output`)

## NanoClaw Replay Adapter (V1)

The current adapter path is replay-first:

- `test.yaml` defines what should happen
- `replay.json` defines what happened
- the runner normalizes replay steps into a trace and evaluates assertions

Replay input format:

- `docs/nanoclaw/replay-input.md`

## Project Docs

- Spec (v1 draft): `SPEC.md`
- First coded v1 assertion cut: `docs/v1-cut.md`
- NanoClaw replay adapter input: `docs/nanoclaw/replay-input.md`
- NanoClaw alpha quickstart: `docs/nanoclaw/getting-started.md`
- NanoClaw PR/discussion blurb (copy/paste): `docs/nanoclaw/pr-blurb.md`
- JSON Schemas: `schemas/test-case.schema.json`, `schemas/trace.schema.json`, `schemas/result.schema.json`
- Contributor guide: `CONTRIBUTING.md`
- Roadmap: `ROADMAP.md`

## Repo Layout (Current)

```text
bin/        CLI + smoke script
lib/        runner, replay normalizer, assertions, reporting
examples/   NanoClaw passing and failing scenarios
docs/       v1 cut + NanoClaw replay contract
schemas/    JSON schemas for test case / trace / result artifacts
skills/     Shareable Codex skill(s), including `agent-eval`
SPEC.md     product + schema spec (v1 draft)
```

## Codex Skill (Included)

This repo now includes a shareable Codex skill for creating/debugging AgentEval replay scenarios:

- `skills/agent-eval/`

It is designed for:

- authoring `test.yaml` + `replay.json` scenarios
- adding failing regression variants
- adding malformed replay error-path cases
- validating expected suite exits (`0` / `1` / `2`)

## Contributing (Early)

Good next contributions:

- add failing regression cases for new behaviors
- improve groundedness checks in `claims_supported_by_fixtures`
- wire JSON schema instance validation into CI / validation scripts

## Roadmap (Short)

1. Expand assertion coverage (additional retry/failure and scheduler checks)
2. Add more NanoClaw examples (memory recall, scheduler failure recovery variants)
3. Add more retry/failure-policy assertions (beyond `graceful_failure_output`, plus richer retry checks)
4. Add live local NanoClaw mode
5. Add multi-agent/swarm trace support
