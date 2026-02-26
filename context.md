# AgentEval Context (Working Summary)

This file captures the current state of the project so work can continue in a new thread without reloading the full conversation history.

## What This Project Is

`AgentEval` is an open-source regression testing framework for tool-using agents, with a first-pass `NanoClaw` adapter.

Core idea:

- test both the final answer and the behavior trace (tool use, ordering, groundedness, memory/isolation behavior)

Primary initial target:

- NanoClaw users/fork maintainers who need confidence that prompt/tool/skill/runtime changes did not regress behavior

## Why These Product Decisions Were Made

### 1. Replay-first (not live-first)

Decision:

- Start with deterministic `replay` mode using `test.yaml` + `replay.json`

Why:

- easier CI adoption
- less setup friction
- deterministic failures
- faster iteration on assertions and trace schema before integrating with a live runtime

### 2. Runtime-agnostic core + NanoClaw adapter

Decision:

- Design a generic core (runner, assertions, trace schema) and a first-party NanoClaw adapter

Why:

- keeps the project useful beyond NanoClaw
- avoids baking NanoClaw-specific assumptions into the engine
- lets NanoClaw still be the first practical use case

### 3. Rule-based assertions first (no LLM judge dependency)

Decision:

- Use deterministic rule-based assertions in v1

Why:

- easier debugging
- stable CI results
- lower cost and fewer moving parts
- better fit for process/tool checks than LLM judging

### 4. Assertions over exact output snapshots

Decision:

- Prefer structural/behavioral assertions (format, required facts, forbidden claims, tool order) over exact-string matching

Why:

- agent outputs are variable
- exact snapshots become brittle quickly
- keeps tests focused on meaningful regressions

### 5. Partial-order process checks

Decision:

- Support checks like “A must happen before B” instead of full strict trace sequence matching

Why:

- agents may legitimately vary in intermediate steps
- still catches the important regressions (e.g., answering before searching)

## Key Specs and Design Docs Created

### Core Spec

- `SPEC.md`

Contains:

- product scope and non-goals
- test case schema
- assertion catalog
- normalized trace schema
- result/report schema
- repo structure and roadmap

### V1 Assertion Cut

- `docs/v1-cut.md`

Purpose:

- narrows the full assertion catalog to a practical first 10 assertions to implement

### NanoClaw Replay Adapter Input Contract

- `docs/nanoclaw/replay-input.md`

Purpose:

- defines the v1 `replay.json` shape that the NanoClaw replay adapter consumes

## V1 Assertion Scope (Current Implemented Subset)

Implemented assertions:

- `must_call_tool`
- `must_not_call_tool`
- `tool_call_order`
- `tool_args_match`
- `max_tool_calls`
- `stop_after_success`
- `output_contains`
- `output_matches_format`
- `output_omits`
- `claims_supported_by_fixtures` (heuristic groundedness check)
- `memory_recall_same_group`
- `no_cross_group_memory_use`
- `scheduler_task_runs`
- `scheduler_outbound_count`
- `retry_policy_respected`
- `graceful_failure_output`

Deferred (planned):

- additional retry/failure assertions (beyond `graceful_failure_output`)
- more memory lifecycle assertions (`memory_update_on_correction`)

## What Has Been Built So Far (Code)

### Minimal Runnable Prototype (Ruby, no external gems)

Reason for Ruby choice:

- system Ruby + built-in YAML/JSON available with zero setup
- Python `PyYAML` was missing in the environment
- goal was fast prototype iteration with low dependency overhead

Core files:

- `bin/agenteval` - CLI entrypoint
- `bin/aeval` - thin wrapper alias for `bin/agenteval`
- `bin/agenteval-smoke` - smoke runner for passing + failing suites
- `bin/aeval-smoke` - thin wrapper alias for `bin/agenteval-smoke`
- `bin/agenteval-schema-smoke` - schema file smoke check (`schemas/` parse + basic shape keys)
- `lib/agenteval.rb` - load entry / version
- `lib/agenteval/cli.rb` - command parsing
- `lib/agenteval/runner.rb` - test discovery, load spec/replay, execute assertions, persist artifacts
- `lib/agenteval/replay_normalizer.rb` - converts `replay.json` into normalized trace
- `lib/agenteval/assertion_engine.rb` - assertion implementations
- `lib/agenteval/reporter.rb` - CLI reporting

### Important Implementation Choices

- Replay normalizer emits a normalized trace with:
  - scenario metadata
  - capabilities
  - ordered events
  - final output
  - metrics
- Artifacts are written when `reporting.save_trace: true` is set in test specs
- Results include assertion-level pass/fail with messages and event refs
- Assertion diagnostics were expanded for several assertions to include richer `observed` context (matched patterns, excerpts, counts, memory evidence)
- Replay normalizer validates replay bundle shape and common invariants (for example `scenario.trigger`, tool call/result linkage, and success output presence)

### Compatibility Fix Applied

The assertion engine was updated for compatibility with the installed Ruby (2.6) by removing use of `filter_map` and replacing it with `map.compact`.

## Example Suites Added

### Passing Examples (`examples/nanoclaw`)

1. `current-news`
- validates tool use + ordering + groundedness for a current-info style task

2. `memory-cross-group`
- validates group isolation and output format behavior

3. `memory-same-group`
- validates same-group memory recall behavior and formatting preference adherence

4. `scheduler-daily-digest`
- validates scheduler-path behavior including scheduler-specific assertions (`scheduler_task_runs`, `scheduler_outbound_count`)

5. `scheduler-digest-timeout-recovery`
- validates scheduler recovery behavior (timeout + retry + single outbound send), including scheduler assertion coverage and `retry_policy_respected`

6. `scheduler-digest-tool-failure-graceful`
- validates scheduler failure-path messaging (`graceful_failure_output`) and no-outbound-send behavior after a tool timeout

Files are structured as:

- `test.yaml` (scenario + assertions)
- `replay.json` (replayed execution transcript)

### Failing Examples (`examples/nanoclaw-failing`)

A parallel set of intentionally failing regression variants was added to prove the framework catches known bad behavior.

Examples currently present (by directory name, observed):

- `current-news-claims-unsupported`
- `current-news-tool-args-mismatch`
- `current-news-unexpected-fetch`
- `memory-cross-group-bullet-format`
- `scheduler-duplicate-outbound-send`
- `scheduler-digest-tool-failure-misleading-success`
- `scheduler-retry-policy-exceeds-max`
- `scheduler-send-before-final-output`

Purpose:

- verify non-zero exit behavior for regression suites
- verify failures point to specific assertions

### Error-Path Examples (`examples/nanoclaw-error`)

Examples currently present (by directory name, observed):

- `invalid-replay-missing-final-output-on-success`
- `missing-replay-file`
- `invalid-replay-missing-trigger`
- `invalid-replay-scheduler-missing-context`
- `invalid-replay-unknown-tool-result-call-id`
- `missing-adapter-input-replay-file-field`

Purpose:

- verify framework/adapter error handling
- verify malformed replay bundles return clear `error` results

## Parallel Agent Contributions (Integrated Into Current State)

This `context.md` includes work added by at least one parallel agent/thread and reflects the combined project state as observed in the workspace.

### Agent B - failing regression variants (integrated)

Primary contributions attributed to Agent B:

1. Failing regression example suite (`examples/nanoclaw-failing`)
- `current-news-unexpected-fetch`
- `memory-cross-group-bullet-format`
- `scheduler-send-before-final-output`

2. Smoke validation script
- `bin/agenteval-smoke`

3. Additional validation runs and generated artifacts
- Multiple `artifacts/run-*` directories for both passing and failing suites

Integration status:

- Handoff received at `docs/handoffs/agent-b-failing-regression-variants.md`
- Validated and recorded in `docs/integration-ledger.md`

Why this matters:

- confirms both positive and negative test paths were exercised
- avoids losing parallel work in future handoffs
- makes this file a combined source of truth, not a single-thread summary

## Validation / What Has Been Proven

### Proven Working

- Passing example suite runs and exits `0`
- Failing regression suite runs and exits `1`
- Smoke script verifies both expectations (`bin/agenteval-smoke`)
- Error-path suite runs and exits `2`
- Replay JSON example files parse successfully
- Passing suite currently includes 6 scenarios (including `scheduler-digest-tool-failure-graceful`)
- Current suite summaries (observed):
  - passing suite (`examples/nanoclaw`): `6 passed, 0 failed, 0 errors`
  - failing suite (`examples/nanoclaw-failing`): `0 passed, 8 failed, 0 errors`
  - error-path suite (`examples/nanoclaw-error`): `0 passed, 0 failed, 6 errors`
- Error-path suite returns `error` results with readable messages (including replay validation failures)

Verification note:

- These checks cover both the original passing examples and the later-added failing regression variants from parallel work.

### Standard Validation Commands (Current)

From repo root:

```bash
ruby bin/agenteval run examples/nanoclaw-error
ruby bin/agenteval run examples/nanoclaw
ruby bin/agenteval run examples/nanoclaw-failing
ruby bin/agenteval-smoke
make schema-smoke
```

Expected exit codes:

- error-path suite: `2`
- passing suite: `0`
- failing suite: `1`
- smoke script: `0`
- schema smoke: `0`

## Artifacts / Output Behavior

- Trace and result artifacts are written to `artifacts/<run_id>/...` when enabled in the test spec
- `.gitignore` includes `artifacts/` to avoid polluting the repo

## Schema Artifacts (Productization)

Versioned JSON Schema files are now present for core data shapes:

- `schemas/test-case.schema.json`
- `schemas/trace.schema.json`
- `schemas/result.schema.json`

Schema smoke command added:

- `bin/agenteval-schema-smoke`
- `make schema-smoke`

Current status:

- schema files are parseable and versioned (`0.1`-aligned)
- schema smoke is wired into local and CI checks (`make schema-smoke`, GitHub workflow)
- full runtime instance validation against these schemas is not yet wired into the runner itself

## Public Docs Added

### README

- `README.md`

Covers:

- project overview
- current prototype status
- quickstart commands
- implemented assertions
- doc links
- short roadmap

### NanoClaw Outreach Docs (new)

- `docs/nanoclaw/getting-started.md`
  - NanoClaw alpha quickstart for replay-mode AgentEval usage
- `docs/nanoclaw/pr-blurb.md`
  - copy/paste text for a NanoClaw PR/discussion post

### Codex Skill (new)

- `skills/agent-eval/`
  - shareable skill for authoring/debugging AgentEval replay scenarios and regression variants
- `skills/agent-eval/references/nanoclaw-replay-and-assertions.md`
  - quick reference for replay shapes, assertion selection, and example patterns

Validation note:

- `skill-creator` quick validation script could not run in this environment because Python `yaml` (`PyYAML`) is missing
- skill files were created successfully and are repo-local/shareable

## GitHub Push / Auth Notes (Today)

GitHub pushes over HTTPS failed when commits included workflow changes because the Personal Access Token in use did not have `workflow` scope:

- blocked file: `.github/workflows/smoke.yml`
- example rejected commit observed: `3f070ff` (`ci: add smoke workflow`)

Resolution path used:

- configured SSH keypair locally
- added public key to GitHub
- prepared to use SSH remote (`git@github.com:buloxdev/agent-eval.git`) to avoid PAT workflow-scope issues

Security note:

- only the public key (`~/.ssh/id_ed25519.pub`) was added to GitHub
- private key remains local (`~/.ssh/id_ed25519`)

## Multi-Agent Parallelization Guidance (Now Partially Materialized In Files)

A parallel work plan was defined to reduce merge conflicts:

- one agent for assertion engine work
- one agent for replay validation / errors
- one agent for examples
- one agent for docs
- one integration owner to merge and run golden checks

Key guardrails decided:

- file ownership per sprint
- structured handoff packets
- contract freeze for `SPEC.md`, `docs/v1-cut.md`, and `docs/nanoclaw/replay-input.md`
- standard validation commands after each merge

Scaffolding files now added:

- `docs/handoffs/README.md`
- `docs/handoffs/_TEMPLATE.md`
- `docs/integration-ledger.md`
- `docs/sprint-checkpoint.md`

These are intended to reduce lost work across parallel agent threads by keeping handoffs and integration state in the repo.

## Git Worktree Setup (Orchestrator Baseline)

Git worktrees have now been created for parallel agent work.

### Baseline Repository State

- Git repository initialized in `.`
- Baseline checkpoint commit created:
  - `fe3e4e8` - `Initial AgentEval workspace checkpoint`

### Worktree Layout (Current)

- Orchestrator / integration workspace (root):
  - `.` on `main`

- Agent A (assertions):
  - `./.worktrees/agent-a-assertions`
  - branch: `codex/agent-a-assertions`

- Agent B (failing regression variants):
  - `./.worktrees/agent-b-failing-regression-variants`
  - branch: `codex/agent-b-failing-regression-variants`

- Agent C (replay validation):
  - `./.worktrees/agent-c-replay-validation`
  - branch: `codex/agent-c-replay-validation`

- Agent D (docs):
  - `./.worktrees/agent-d-docs`
  - branch: `codex/agent-d-docs`

### Worktree-Related Repo Hygiene

- `.gitignore` includes `.worktrees/`
- `artifacts/` remains ignored

### Important Note About Embedded Repositories

During the initial checkpoint commit, several `roast_landingpage*` directories were detected as embedded git repositories and were committed as gitlinks (mode `160000`) in the new parent repo.

Status update:

- This was a repo-scoping mistake and is being corrected so `AgentEval` and `roast_landingpage*` remain completely separate projects.

Separation rule (current intent):

- The AgentEval parent repo should not track `roast_landingpage*` directories at all.
- `roast_landingpage*` repos remain independent nested projects in the filesystem.

## Current Limitations / Known Gaps

- Replay mode only (no live NanoClaw integration yet)
- Groundedness check is heuristic, not semantic proof
- Full instance validation against JSON schemas is not wired into the runner yet (schema files + schema smoke + CI schema-smoke step exist)
- No package/release setup yet
- Some core files are becoming merge hotspots (`assertion_engine.rb`, `runner.rb`)

## Recommended Next Steps (Priority Order)

### A. Stabilize Core Behavior (high priority)

1. Continue improving failure messages and assertion diagnostics (especially richer observed payloads across all assertions)
2. Add more replay validation cases (for example malformed `metrics`, invalid script step shape, unsupported step type edge cases)

Why first:

- improves confidence in process correctness
- increases failure quality before adding more coverage

### B. Expand Example Coverage (high value, low risk)

1. Add more failing variants for hallucination/tool-order/scheduler duplication cases
2. Add more scheduler negative controls and failure modes (non-timeout errors, misleading retry messaging)
3. Add assertion-specific examples for recently added checks (`retry_policy_respected`, `graceful_failure_output`)

### C. Strengthen OSS Contributor Experience (mostly done, next polish)

1. Add issue templates / contribution templates (optional)
2. Add a release checklist / first GitHub release notes draft
3. Extend schema validation from smoke-level checks to full instance validation in runner/CI
4. Add a short "How to use the included `skills/agent-eval` skill" note to outreach posts/docs if needed

### D. Next Adapter/Engine Milestones

1. Additional scheduler-specific assertions and richer scheduler diagnostics
2. Additional retry/failure assertions beyond `retry_policy_respected` and `graceful_failure_output`
3. Result/trace/test-case schema instance validation and CI integration
4. Live local NanoClaw mode (later)

## If Resuming In A New Thread

Recommended resume prompt:

- "Continue implementing AgentEval in this repo. Start with `<one concrete task>` and preserve the replay-first spec and example suites."

Good concrete tasks to choose from:

- improve assertion failure messages / evidence
- add replay validation error cases
- add scheduler failure variants / negative controls
- add retry/failure assertions beyond the current set
- wire schema validation into CI (using `schemas/` + `bin/agenteval-schema-smoke`)
- finalize NanoClaw outreach post and publish a discussion/docs PR using `docs/nanoclaw/pr-blurb.md`

## Files Most Important To Read First (Low Context Resume)

If someone is resuming work and wants minimal context, start with:

1. `README.md`
2. `docs/v1-cut.md`
3. `docs/nanoclaw/replay-input.md`
4. `SPEC.md` (as needed)
5. `lib/agenteval/assertion_engine.rb` or the specific file for the current task

## Updating This File After Parallel Work (Checklist)

When another agent contributes changes, update this file by:

1. listing the exact added/changed files
2. noting whether the change is docs, core runtime, assertions, examples, or validation tooling
3. recording what behavior it proves (for example, "failing suite exits 1")
4. confirming whether it is already integrated and validated
