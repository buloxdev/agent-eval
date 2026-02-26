# Handoffs Directory

Use this directory for agent-to-orchestrator handoffs so work is captured in the shared workspace (not only in chat threads).

## Purpose

Each agent should leave a short handoff note here after completing a task. This lets the orchestrator:

- discover completed work without copy/paste
- merge changes safely
- track validation status
- update `./context.md`

## Naming Convention

Recommended filename format:

- `agent-<name>-<task-slug>.md`

Examples:

- `agent-b-failing-regression-variants.md`
- `agent-assertions-tool-args-match.md`

## Required Handoff Contents

Use the template in `./docs/handoffs/_TEMPLATE.md`.

At minimum include:

- task name
- changed files
- summary of changes
- commands run + exit codes
- known limitations
- expected merge conflicts (if any)

## Rule

Do not rely on chat messages alone for handoff. If the work matters, write a handoff file here.

