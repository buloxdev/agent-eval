# Contributing to AgentEval

Thanks for contributing to `AgentEval`.

This project is early-stage and intentionally small. The current goal is to make the replay-mode prototype genuinely useful and easy to extend.

## Current Priorities

High-value contributions right now:

- new assertions (especially scheduler/retry assertions and richer memory assertions)
- replay validation and error handling improvements
- better example scenarios (passing + failing)
- groundedness check improvements (`claims_supported_by_fixtures`)
- docs that improve onboarding and clarity

Lower priority right now:

- packaging/release automation
- live NanoClaw integration
- multi-agent/swarm support

## Before You Start

Read these first:

- `README.md`
- `docs/v1-cut.md`
- `docs/nanoclaw/replay-input.md`
- `SPEC.md` (as needed)

## Development Setup

Current prototype requirements:

- Ruby (no external gems required for the current implementation)

Run from repo root:

```bash
ruby bin/agenteval run examples/nanoclaw
ruby bin/agenteval run examples/nanoclaw-failing
ruby bin/agenteval run examples/nanoclaw-error
ruby bin/agenteval-smoke
make privacy-smoke
```

Expected exit codes:

- passing suite: `0`
- failing suite: `1`
- error-path suite: `2`
- smoke script: `0`
- privacy smoke: `0`

## Contribution Types

## 1. Add a New Assertion

Typical files:

- `lib/agenteval/assertion_engine.rb`
- example specs under `examples/` (to prove it works)
- docs (`README.md`, `docs/v1-cut.md`, or `SPEC.md`) if behavior or scope changes

Recommended process:

1. Add a passing example or reuse an existing one
2. Add a failing example that should trigger the new assertion
3. Implement the assertion
4. Run passing and failing suites
5. Improve failure messages (important)

Please include in your change:

- clear assertion ID(s) in examples
- readable failure messages
- note any limitations (e.g., exact shape supported in v1)

## 2. Add a New Example Regression Scenario

Each example should generally include:

- `test.yaml` (scenario + assertions)
- `replay.json` (replayed execution transcript)

Guidelines:

- keep fixtures deterministic
- test one primary behavior per scenario
- avoid exact-string output checks unless formatting is the contract
- prefer assertions over snapshots

If adding a failing example:

- make the failure intentional and obvious
- document what should fail (assertion ID or behavior)

### How to Add a Failing Regression Variant

Use `examples/nanoclaw-failing/` for intentionally failing scenarios that prove the framework catches a regression.

Recommended workflow:

1. Copy the closest passing scenario directory into `examples/nanoclaw-failing/<new-variant-name>/`
2. Update `test.yaml`:
   - keep `mode: replay`
   - change `id` / `title` to clearly mark it as failing / negative control
   - make the failing assertion explicit in `assertions[]`
   - set `expected.outcome` and `failure_categories` to describe the intentional regression
3. Reuse or modify `replay.json` so the failure is deterministic
4. Run:
   - `ruby bin/agenteval run examples/nanoclaw-failing`
5. Confirm:
   - suite exits `1`
   - your scenario shows `FAIL` (not `ERROR`)
   - failure message points to the intended assertion and evidence

Tips:

- Prefer one primary failure behavior per variant.
- Negative controls should fail for the reason named in the assertion ID.
- Avoid changing multiple assertions unless the scenario is specifically about combined regressions.

### How to Add an Error-Path Replay Validation Case

Use `examples/nanoclaw-error/` for framework/adapter validation failures and malformed replay bundle handling.

Recommended workflow:

1. Create `examples/nanoclaw-error/<case-name>/`
2. Add a `test.yaml` that points at the malformed or missing replay input via `adapter_input.replay_file`
3. Make the case deterministic:
   - missing file path
   - malformed replay JSON
   - replay missing required fields (for example `scenario.trigger`)
   - invalid linkage or invariants
4. Run:
   - `ruby bin/agenteval run examples/nanoclaw-error`
5. Confirm:
   - suite exits `2`
   - your scenario reports `ERROR` (not `FAIL`)
   - the error message is clear and names the invalid field/invariant when possible

Tips:

- Keep each error-path case focused on one validation failure.
- Prefer readable fixture names that describe the malformed condition.
- Update docs if a new validation rule becomes part of the documented replay contract.

## 3. Improve Replay Adapter / Validation

Typical files:

- `lib/agenteval/replay_normalizer.rb`
- `lib/agenteval/runner.rb`
- `docs/nanoclaw/replay-input.md` (only if format expectations change)

Focus on:

- clear error messages
- validation for malformed replay bundles
- preserving deterministic behavior

## 4. Documentation Improvements

Good docs contributions:

- clarify current prototype status
- improve quickstart
- add examples
- tighten wording around non-goals / roadmap

Please avoid documenting features that are not implemented yet without clearly marking them as planned.

## Pull Request / Change Checklist

Before submitting a change:

- [ ] Scope is focused (one feature/fix/docs topic)
- [ ] Passing suite still exits `0`
- [ ] Failing suite still exits `1`
- [ ] Error-path suite still exits `2` (when replay validation / error handling changed)
- [ ] Smoke script exits `0` (when applicable)
- [ ] Privacy smoke exits `0` (`make privacy-smoke`)
- [ ] README/docs updated if user-facing behavior changed
- [ ] Failure messages are useful (for assertion/reporting changes)

## Parallel Agent Handoffs (If Working In Agent Threads)

If you are contributing through a parallel agent workflow, leave a handoff note in:

- `docs/handoffs/`

Use:

- `docs/handoffs/_TEMPLATE.md`

This prevents work from being lost across threads.

### Handoff File Creation Checklist (`docs/handoffs/...`)

When finishing a parallel agent task, create a handoff file in `docs/handoffs/` using the template and include:

- [ ] Agent name and task packet / goal
- [ ] Final status (`completed`, `partial`, or `blocked`)
- [ ] Allowed files and files actually changed
- [ ] Short summary of changes
- [ ] Validation commands run and exit codes
- [ ] Expected behavior change (what should now pass/fail/error)
- [ ] Known limitations / follow-ups
- [ ] Merge notes (conflict risk, suggested merge order, post-merge checks)

Recommended filename pattern:

- `docs/handoffs/<agent-or-branch>-<short-topic>.md`

## Scope Boundaries (Important)

This repository is for `AgentEval`.

Do not make changes to unrelated nested projects in this directory (for example `roast_landingpage*`) as part of AgentEval contributions.
