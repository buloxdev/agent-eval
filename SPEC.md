# AgentEval SPEC (V1 Draft)

## Table of Contents

1. Overview
2. Problem Statement
3. V1 Goals
4. V1 Non-Goals
5. Primary User and Job
6. Design Principles
7. Core Concepts
8. Architecture (V1)
9. Execution Modes
10. Evaluation Categories
11. Pass / Fail Rules
12. Adapter Contract
13. Test Case Schema (V1)
14. Assertion Catalog (V1)
15. Assertion Parameter Conventions (V1)
16. Normalized Trace Schema (V1)
17. Test Result / Report Schema (V1)
18. Repository Structure (Recommended)
19. Naming Conventions
20. Author Workflow (V1)
21. Initial NanoClaw Example Suite (V1)
22. NanoClaw Adapter Roadmap (V1 -> V2)
23. Open Source Positioning
24. Versioning and Compatibility (V1)
25. Known Limitations (V1)
26. V1 Acceptance Criteria
27. Open Questions Before Implementation

## 1. Overview

`AgentEval` is an open-source regression testing framework for tool-using agents, with a first-party `NanoClaw` adapter.

V1 runs deterministic test scenarios using mocked or replayed fixtures, captures a normalized behavior trace, and evaluates both:

- final output quality
- process correctness (tool calls, ordering, constraints)

The primary use case is catching regressions after changing prompts, tools, skills, or agent logic in a NanoClaw-based agent system.

## 2. Problem Statement

Agent builders can often demo an agent, but cannot reliably answer:

- Is it actually working?
- Did it use tools correctly?
- Did it hallucinate?
- Did it forget or leak memory?
- Did a recent change regress behavior?

`AgentEval` addresses this by making agent behavior testable and repeatable in CI.

## 3. V1 Goals

- Provide a runtime-agnostic core for agent regression testing.
- Ship a first-party `NanoClaw` adapter.
- Support deterministic `replay` mode with mocked or replayed fixtures.
- Evaluate both final output and behavior trace.
- Produce actionable failure reports with assertion evidence and trace references.
- Support NanoClaw-relevant checks for memory recall, group isolation, and scheduler behavior when adapter metadata is available.

## 4. V1 Non-Goals

- Universal runtime support across all agent frameworks
- Benchmarking models or vendors
- Perfect hallucination detection
- LLM-as-judge scoring as a dependency
- Production observability dashboards
- Full swarm or multi-agent evaluation (single-agent first)

## 5. Primary User and Job

### Primary User

NanoClaw fork maintainers and advanced users customizing agent behavior with prompts, tools, or skills.

### Primary Job-to-Be-Done

When I change my NanoClaw customization, tell me if I broke agent behavior.

## 6. Design Principles

- Deterministic first: replay + fixtures before live integration
- Trace-first debugging: every failure should point to evidence
- Assertions over snapshots: avoid brittle exact-string matching
- Runtime-agnostic core: NanoClaw first, not NanoClaw only
- Capability-gated checks: skip or downgrade assertions when adapters lack metadata
- CI-friendly outputs: machine-readable results plus human-readable summaries

## 7. Core Concepts

### Test Case

A scenario with setup, fixtures, and assertions.

### Fixture

Deterministic tool responses, errors, prior messages, memory snapshots, and scheduler context.

### Normalized Trace

A runtime-agnostic execution record (messages, tool calls/results, optional memory events, final output).

### Assertion

A rule that checks the trace and/or final output.

### Result Report

A pass or fail outcome with assertion results, evidence, and failure categories.

## 8. Architecture (V1)

### Core Components

- test spec parser
- runner
- assertion engine
- reporter
- trace normalization helpers

### Adapter Layer

- `adapters/nanoclaw` maps NanoClaw execution or replay data into the normalized trace schema

### Outputs

- CLI summary
- per-test JSON result
- optional stored trace artifact

## 9. Execution Modes

### V1 Default

- `replay`

### Future

- `live` (local NanoClaw execution with trace capture)

## 10. Evaluation Categories

V1 uses a scorecard instead of a single opaque score.

- Outcome correctness
- Tool/process correctness
- Groundedness or hallucination
- Memory behavior
- Group isolation
- Scheduler behavior
- Recovery behavior
- Efficiency (tracked, optional for gating in v1)

## 11. Pass / Fail Rules

- A test `fails` if any `critical` assertion fails.
- A test `passes` if no `critical` assertions fail.
- `warning` assertions do not fail the test.
- Capability-gated assertions may be `skip` depending on adapter capabilities and test policy.
- Framework or adapter execution problems produce `error` (not pass or fail).

## 12. Adapter Contract

The adapter must emit a normalized trace and declare capabilities.

### Required Adapter Metadata

- adapter name
- adapter version
- capability flags

### Capability Flags (V1)

- `supports_tool_trace`
- `supports_memory_events`
- `supports_scheduler_context`
- `supports_container_metadata`
- `supports_live_run`
- `supports_replay`

### NanoClaw-Specific Context To Preserve (If Available)

- `group_id`
- `session_id`
- `task_id`
- scheduler trigger metadata
- per-group memory source (for example `CLAUDE.md`)
- container and mount metadata (optional v2)

## 13. Test Case Schema (V1)

Each test spec file describes one scenario.

### Required Top-Level Fields

- `schema_version`
- `id`
- `title`
- `adapter`
- `mode`
- `scenario`
- `tools`
- `assertions`

### Recommended Top-Level Fields

- `description`
- `tags`
- `expected`
- `reporting`

### `scenario` Fields

- `group_id`
- `session_id` (optional)
- `trigger` (`user_message` or `scheduler`)
- `input_messages`
- `prior_messages` (optional)
- `memory_snapshot` (optional)
- `mounts` (optional)
- `scheduler_context` (optional)

### `tools` Fields

- `available`
- `fixtures`
- `policy` (optional)

### `assertions` Fields

- `id`
- `type`
- `severity` (`critical` or `warning`)
- `params`
- `requires_capabilities` (optional)

### `expected` Fields (Human-Oriented)

- `outcome`
- `failure_categories`

### `reporting` Fields (Optional)

- `save_trace`
- `redact_fields`

## 14. Assertion Catalog (V1)

This section is the target v1 assertion catalog (spec scope), not a statement that every assertion is implemented in the current alpha code. See `README.md` and `context.md` for the current implemented subset.

### Process and Tool Assertions

- `must_call_tool`
- `must_not_call_tool`
- `tool_call_order`
- `tool_args_match`
- `max_tool_calls`
- `stop_after_success`

### Output and Correctness Assertions

- `output_contains`
- `output_matches_format`
- `output_omits`
- `ask_clarifying_when_ambiguous`

### Groundedness and Hallucination Assertions

- `claims_supported_by_fixtures`
- `no_fabricated_source_or_citation`

### Memory and Isolation Assertions

- `memory_recall_same_group`
- `memory_update_on_correction`
- `no_cross_group_memory_use`

### Recovery and Scheduler Assertions (Capability-Dependent)

- `retry_policy_respected`
- `graceful_failure_output`
- `scheduler_task_runs`
- `scheduler_outbound_count`

## 15. Assertion Parameter Conventions (V1)

### Common Assertion Envelope

- `id`: stable assertion identifier
- `type`: assertion type
- `severity`: `critical` or `warning`
- `requires_capabilities`: optional capability list
- `params`: assertion-specific configuration

### Event Selector Convention

Used by ordering and trace-based assertions:

- `event_type`
- `tool` (for tool events)
- `call_id` (optional)
- `success` (optional for tool results)

### Defaults (Recommended)

- Use `critical` by default unless noted otherwise.
- Use partial-order checks instead of exact full sequence checks.
- Treat output string matching as case-insensitive unless explicitly configured.
- Gate adapter-dependent assertions with `requires_capabilities`.

## 16. Normalized Trace Schema (V1)

The normalized trace is the core data model consumed by the assertion engine.

### Top-Level Trace Fields (Required)

- `schema_version`
- `trace_id`
- `test_case_id`
- `test_run_id`
- `adapter`
- `capabilities`
- `scenario`
- `input_messages`
- `events`
- `final_output`
- `status` (`success`, `partial`, `failed`, `blocked`)
- `metrics.timing_ms_total`

### Recommended Trace Fields

- `scenario.group_id`
- `scenario.session_id`
- `scenario.task_id`
- `metrics.tool_call_count`
- `metrics.retry_count`
- `metrics.token_usage`
- `artifacts`

### Event Common Fields

Each `events[]` entry should include:

- `event_id`
- `seq`
- `ts`
- `type`
- `actor`
- `group_id` (if known)
- `session_id` (if known)
- `task_id` (if known)
- `agent_id`
- `parent_event_id` (optional)
- `data`

### Event Types (V1)

- `message_received`
- `tool_call`
- `tool_result`
- `memory_read` (optional)
- `memory_write` (optional)
- `error`
- `final_output`

### Trace Normalization Rules

- `events[]` must be ordered by `seq`.
- `tool_result` and `error` should link to a `tool_call` via `call_id` and/or `parent_event_id`.
- The framework may synthesize a `final_output` event if the adapter only supplies top-level `final_output`.
- Unsupported event families must be reflected in capability flags.

## 17. Test Result / Report Schema (V1)

Each test execution produces one result object.

### Top-Level Result Fields

- `schema_version`
- `result_id`
- `test_case_id`
- `test_run_id`
- `adapter`
- `status` (`pass`, `fail`, `error`, `skipped`)
- `started_at`
- `finished_at`
- `duration_ms`
- `summary`
- `failure_categories`
- `assertions`
- `trace_summary`
- `evidence`
- `artifacts`

### Assertion Result Fields

Each configured assertion should produce one assertion result entry with:

- `id`
- `type`
- `severity`
- `status` (`pass`, `fail`, `warn`, `skip`)
- `message`
- `params`
- `observed`
- `evidence.event_refs`
- `capability_check`

### CLI Output Requirements (Human-Readable)

CLI output should show:

- overall status
- test ID
- duration
- adapter and mode
- trace summary (tools, retries, trace status)
- assertion-by-assertion pass or fail
- failure categories
- artifact paths

### Exit Codes (Recommended)

- `0` all tests passed
- `1` at least one test failed
- `2` framework or adapter error
- `3` invalid test spec

## 18. Repository Structure (Recommended)

```text
/
├─ README.md
├─ LICENSE
├─ CONTRIBUTING.md
├─ ROADMAP.md
├─ docs/
├─ schemas/
├─ core/
├─ adapters/
│  └─ nanoclaw/
├─ examples/
│  └─ nanoclaw/
├─ tests/
├─ scripts/
└─ artifacts/   (gitignored)
```

## 19. Naming Conventions

### Test IDs

Format:

- `<adapter>.<area>.<behavior>.<expectation>`

Examples:

- `nanoclaw.memory.same-group-recall.brief-bullets`
- `nanoclaw.memory.isolation.no-cross-group-leak`
- `nanoclaw.scheduler.daily-digest.single-outbound`

### Test Files

Recommended path:

- `examples/nanoclaw/<slug>/test.yaml`

### Fixture Files

Use tool-oriented names:

- `fx.web_search.current_ai_news.json`
- `fx.web_fetch.article_a.json`
- `fx.outbound_send.success.json`

### Artifact Files

- `artifacts/<run_id>/<test_id>.trace.json`
- `artifacts/<run_id>/<test_id>.result.json`
- `artifacts/<run_id>/summary.json`

## 20. Author Workflow (V1)

### Primary Workflow

1. Identify a behavior to protect or a regression to prevent.
2. Define a minimal scenario that reproduces the behavior.
3. Create deterministic fixtures.
4. Write assertions for process and output.
5. Run the single test locally.
6. Fix the agent behavior.
7. Re-run the test and confirm pass.
8. Run a targeted suite.
9. Add or enforce in CI.

### Recommended Assertion Authoring Order

1. process checks (`must_call_tool`, `must_not_call_tool`)
2. ordering checks (`tool_call_order`)
3. format checks (`output_matches_format`)
4. content checks (`output_contains`, `output_omits`)
5. groundedness checks (`claims_supported_by_fixtures`)
6. memory, isolation, and scheduler checks

### Good Test Characteristics

- deterministic fixtures
- one primary behavior per test
- clear failure message
- minimal dependency on exact wording
- capability gating for adapter-dependent checks
- fast to debug

## 21. Initial NanoClaw Example Suite (V1)

Recommended first examples to ship in `examples/nanoclaw/`:

- `current-news` (requires web tool, no hallucinated sources)
- `memory-same-group` (preference recall)
- `memory-cross-group` (no cross-group leakage)
- `scheduler-daily-digest` (single outbound success path)
- `scheduler-digest-timeout-recovery` (timeout plus retry or graceful failure)

These examples establish immediate credibility for NanoClaw users.

## 22. NanoClaw Adapter Roadmap (V1 -> V2)

### Phase 0: Contract Alignment

Deliverables:

- finalize test spec shape
- finalize trace schema `0.1`
- finalize result schema `0.1`
- finalize capability flags
- finalize example test set

### Phase 1: Replay Adapter (V1 MVP)

Deliverables:

- `replay` mode
- normalized trace for `message_received`, `tool_call`, `tool_result`, `error`, `final_output`
- tool, process, output, and groundedness assertions functional
- CI-friendly deterministic runs

### Phase 1.1: Memory and Group Context Support

Deliverables:

- `group_id` and `session_id` propagation
- memory snapshot handling
- optional `memory_read` and `memory_write` mapping
- reliable `memory_recall_same_group` and `no_cross_group_memory_use`

### Phase 1.2: Scheduler Support

Deliverables:

- scheduler trigger context (`task_id`, `scheduled_for`, timezone if available)
- outbound send normalization
- `scheduler_task_runs` and `scheduler_outbound_count`

### Phase 1.3: Live Local Mode (Optional Late V1 / Early V2)

Deliverables:

- `live` mode trace capture against local NanoClaw
- clear adapter or runtime error reporting when trace capture is incomplete

### Phase 2: Richer NanoClaw Metadata

Potential additions:

- container metadata
- mounted path metadata
- retry and backoff introspection
- token and cost metrics
- streamed output events

### Phase 3: Swarm and Multi-Agent Evaluation (V2+)

Potential additions:

- multi-`agent_id` traces
- delegation and handoff events
- swarm-specific assertions

## 23. Open Source Positioning

### Project Thesis (Short)

`AgentEval` is a regression testing framework for agents that checks both what the agent answered and how it got there, with a first-party NanoClaw adapter.

### Why NanoClaw First

NanoClaw’s design (group isolation, per-group memory, scheduler, tool use) maps directly to high-value evaluation scenarios.

## 24. Versioning and Compatibility (V1)

- Spec, trace, and result schemas start at `0.1`.
- Breaking schema changes require a schema version bump.
- Adapter versions may evolve independently from core releases.
- Capability flags are the primary compatibility mechanism for partial adapter support.

## 25. Known Limitations (V1)

- Groundedness checks are rule-based and not semantically perfect.
- Replay mode is the default and may not expose all runtime-specific behavior.
- Live local NanoClaw execution mode is not part of v1 alpha yet.
- Memory and scheduler assertions depend on adapter metadata availability.
- Swarm evaluation is out of scope for v1.

## 26. V1 Acceptance Criteria

V1 is considered successful when:

- A developer can write a new test without changing framework code.
- A failed test identifies the specific failed assertion and supporting trace evidence.
- Replay tests are deterministic in CI.
- NanoClaw users can validate at least these behaviors:
- required tool usage for a current-info scenario
- same-group memory recall
- cross-group memory isolation
- scheduler single-run outbound behavior (when supported by adapter metadata)

## 27. Open Questions Before Implementation

- Which assertion types are in the first coded release (start with 8 to 12)?
- What exact replay input format will the NanoClaw adapter accept?
- What capability flags can NanoClaw expose immediately versus later?
