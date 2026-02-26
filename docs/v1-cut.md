# V1 Cut: First 10 Assertions

This document narrows the assertion catalog in `./SPEC.md` to a practical first implementation set.

## Goal

Ship a useful v1 with enough coverage to catch real regressions in NanoClaw workflows without building the full assertion catalog up front.

## Included in First Coded Release (10)

These 10 assertions cover the highest-value failure modes: wrong tool usage, bad sequencing, output shape regressions, hallucinations, and core NanoClaw memory/isolation behavior.

1. `must_call_tool`
- Why: foundational process check; many regressions are "tool was skipped".

2. `must_not_call_tool`
- Why: catches forbidden or expensive tool usage and policy violations.

3. `tool_call_order`
- Why: enables partial-order checks like "search before final output".

4. `max_tool_calls`
- Why: catches loops and unnecessary retries early.

5. `output_contains`
- Why: simple correctness signal without exact snapshots.

6. `output_matches_format`
- Why: validates contract-like response requirements (bullets, JSON, paragraph count).

7. `output_omits`
- Why: protects against forbidden phrases, stale facts, and leakage symptoms.

8. `claims_supported_by_fixtures`
- Why: core groundedness/hallucination coverage for fixture-backed tests.

9. `memory_recall_same_group`
- Why: directly tests a major NanoClaw trust issue (remembering within a group).

10. `no_cross_group_memory_use`
- Why: directly tests NanoClaw’s group isolation promise.

## Deferred to V1.x (After Core Is Stable)

- `tool_args_match`
- `stop_after_success`
- `ask_clarifying_when_ambiguous`
- `no_fabricated_source_or_citation`
- `memory_update_on_correction`
- `retry_policy_respected`
- `graceful_failure_output`
- `scheduler_task_runs`
- `scheduler_outbound_count`

## Why Scheduler Assertions Are Deferred (Even Though NanoClaw Supports Scheduling)

Scheduler coverage is still important, but the first coded release can test scheduler behavior using the core assertions above:

- `must_call_tool` for `outbound_send`
- `tool_call_order` for `web_search -> outbound_send`
- `max_tool_calls` to prevent duplicate sends
- `claims_supported_by_fixtures` for grounded summaries

This lets the replay adapter and trace pipeline stabilize before adding scheduler-specific assertion types.

## Minimal Milestone Sequence

1. Implement process + output assertions (`must_call_tool`, `must_not_call_tool`, `tool_call_order`, `max_tool_calls`, `output_contains`, `output_matches_format`, `output_omits`)
2. Implement `claims_supported_by_fixtures` for rule-based groundedness
3. Implement memory/isolation assertions (`memory_recall_same_group`, `no_cross_group_memory_use`)
4. Add deferred assertions incrementally based on example suite gaps

## Exit Criteria for This V1 Cut

The first release is good enough to ship when these example tests can pass/fail correctly:

- `./examples/nanoclaw/current-news/test.yaml`
- `./examples/nanoclaw/memory-cross-group/test.yaml`
- `./examples/nanoclaw/scheduler-daily-digest/test.yaml`

