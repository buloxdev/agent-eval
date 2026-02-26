# Integration Ledger

Track incoming agent handoffs and merge decisions here so no work gets lost across parallel threads.

## Status Legend

- `received`
- `integrated`
- `deferred`
- `rejected`
- `needs-followup`

## Entries

| Date (UTC) | Agent | Task | Handoff File | Files Touched | Status | Validation | Notes |
|---|---|---|---|---|---|---|---|
| 2026-02-25 | Agent B | Failing regression variants expansion | `docs/handoffs/agent-b-failing-regression-variants.md` | `examples/nanoclaw-failing/**`, `examples/nanoclaw-error/**`, handoff doc | `integrated` | `pass=0`, `fail=1`, `error=2`, `smoke=0` | Added new failing cases for `claims_supported_by_fixtures`, `tool_args_match`, `max_tool_calls`, plus spec-validation error case |
| _TBD_ | _TBD_ | _TBD_ | `docs/handoffs/...` | `...` | `received` | _not run_ | |

## Integration Workflow (Orchestrator)

1. Confirm the handoff file exists and is complete.
2. Review changed files and compare with task packet ownership.
3. Merge one handoff at a time.
4. Run golden checks:
   - `ruby bin/agenteval run examples/nanoclaw` (expect `0`)
   - `ruby bin/agenteval run examples/nanoclaw-failing` (expect `1`)
   - `ruby bin/agenteval-smoke` (expect `0`)
5. Record results in this ledger.
6. Update `./context.md` when the change is integrated.
