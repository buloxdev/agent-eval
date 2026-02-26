# AgentEval Roadmap

This roadmap is intentionally short and practical. The goal is to ship a useful open-source tool early, then expand coverage.

## Guiding Principle

Prioritize:

- deterministic replay-based regression testing
- clear failure reports
- strong examples

Delay:

- complex integrations
- broad platform support
- advanced benchmarking features

## v0.1 (Current Alpha Focus)

Goal:

- publish a useful replay-mode prototype that demonstrates real value

Target scope:

- replay-mode runner (`test.yaml` + `replay.json`)
- normalized trace generation
- core assertion set (current alpha subset)
- passing and failing NanoClaw example suites
- basic CLI reporting
- README + spec/docs for contributors

Success criteria:

- `ruby bin/agenteval run examples/nanoclaw` exits `0`
- `ruby bin/agenteval run examples/nanoclaw-failing` exits `1`
- `ruby bin/agenteval-smoke` exits `0`
- a new contributor can add a replay example without changing core code

Current suite snapshot (observed):

- passing suite (`examples/nanoclaw`): `5 passed, 0 failed, 0 errors`
- failing suite (`examples/nanoclaw-failing`): `0 passed, 7 failed, 0 errors`
- error-path suite (`examples/nanoclaw-error`): `0 passed, 0 failed, 3 errors`

## v0.2 (Process + Coverage Expansion)

Goal:

- improve process correctness checks and replay robustness

Planned items:

- more examples:
  - `memory-same-group` passing case
  - `scheduler-digest-timeout-recovery` passing case (implemented)
  - additional hallucination regressions
- improved groundedness heuristics (still rule-based)

## v0.3 (NanoClaw Depth)

Goal:

- strengthen NanoClaw-specific behavior coverage while staying replay-first by default

Planned items:

- additional scheduler assertions beyond `scheduler_task_runs` / `scheduler_outbound_count`
- additional retry/failure assertions (beyond `retry_policy_respected` and `graceful_failure_output`)
- richer trace/result metadata
- schema instance validation in CI using `schemas/test-case.schema.json`, `schemas/trace.schema.json`, and `schemas/result.schema.json`

## v0.4 (Live Local Mode - Optional)

Goal:

- support local live execution against NanoClaw for debugging and validation

Planned items:

- `mode: live` (local runtime integration)
- live trace capture -> normalized trace
- clear runtime/instrumentation error handling

Notes:

- replay remains the default CI path
- live mode is additive, not a replacement

## v0.5+ (Beyond MVP)

Possible directions:

- multi-agent / swarm trace support
- adapter plugins for other runtimes
- richer reporting formats and dashboards
- baseline comparisons and regression diff tooling

## Out of Scope for Now

- model benchmarking leaderboards
- LLM-judge-first architecture
- production observability platform features
- perfect hallucination detection

## How To Use This Roadmap

When choosing the next task, prefer work that:

1. improves deterministic replay reliability
2. increases confidence in failure output quality
3. expands examples using existing assertions
4. adds narrowly scoped assertions with clear examples
