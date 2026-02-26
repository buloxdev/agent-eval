# Sprint Checkpoint

Use this file at the start of a parallel work sprint to freeze the baseline and reduce drift.

## Checkpoint Metadata

- Checkpoint name:
- Created at (UTC):
- Orchestrator:
- Sprint goal:

## Contract Freeze (if applicable)

List docs/specs treated as frozen during this sprint:

- `./SPEC.md`
- `./docs/v1-cut.md`
- `./docs/nanoclaw/replay-input.md`

Notes / exceptions:

- 

## Active Agents and Ownership

| Agent | Task | Owned Files / Areas | Forbidden / No-touch Files |
|---|---|---|---|
| Orchestrator | Integration | `docs/integration-ledger.md`, `context.md` | _n/a_ |
| _TBD_ | _TBD_ | _TBD_ | _TBD_ |

## Baseline Validation (before parallel work)

Record the exact commands and exit codes.

```bash
ruby bin/agenteval run examples/nanoclaw
# exit code:

ruby bin/agenteval run examples/nanoclaw-failing
# exit code:

ruby bin/agenteval-smoke
# exit code:
```

## File Snapshot (optional but useful)

```bash
rg --files .
```

## Notes

- Keep merges one handoff at a time.
- Update `docs/integration-ledger.md` after each integration.

