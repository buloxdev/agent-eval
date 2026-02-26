# NanoClaw Replay Adapter Input (V1)

This document defines the exact input shape for the NanoClaw `replay` adapter in v1.

## Purpose

The replay adapter consumes a deterministic "replay bundle" and emits a normalized trace that the core assertion engine evaluates.

This is intentionally separate from the test case spec:

- `test.yaml` describes what to test and what should pass/fail
- `replay.json` describes what happened in a replayable NanoClaw run (or a scripted approximation of one)

## File Format

- Recommended filename: `replay.json`
- Location: same directory as `test.yaml` for examples

Example:
- `./examples/nanoclaw/current-news/replay.json`

## Top-Level Shape (V1)

```json
{
  "schema_version": "0.1",
  "adapter": "nanoclaw-replay",
  "scenario": {
    "group_id": "group-alpha",
    "session_id": "sess-001",
    "task_id": null,
    "trigger": "user_message",
    "scheduler_context": null
  },
  "capabilities": {
    "supports_tool_trace": true,
    "supports_memory_events": false,
    "supports_scheduler_context": false,
    "supports_container_metadata": false
  },
  "input_messages": [
    { "role": "user", "content": "..." }
  ],
  "script": [
    {
      "type": "tool_call",
      "tool": "web_search",
      "call_id": "call-1",
      "args": { "query": "..." }
    },
    {
      "type": "tool_result",
      "tool": "web_search",
      "call_id": "call-1",
      "success": true,
      "result": { "items": [] },
      "fixture_id": "fx-web-search-001"
    },
    {
      "type": "final_output",
      "content": "- ..."
    }
  ],
  "final_output": {
    "role": "assistant",
    "content": "- ..."
  },
  "status": "success",
  "metrics": {
    "timing_ms_total": 1200,
    "retry_count": 0,
    "token_usage": null
  }
}
```

## Field Definitions

### Required Top-Level Fields

- `schema_version`: replay input schema version (`"0.1"`)
- `adapter`: must be `"nanoclaw-replay"` for v1
- `scenario`
- `input_messages`
- `script`
- `final_output`
- `status`
- `metrics.timing_ms_total`

### `scenario`

- `group_id`: required for NanoClaw context and isolation checks
- `session_id`: optional but recommended
- `task_id`: optional; required for scheduler tests when known
- `trigger`: `user_message` or `scheduler`
- `scheduler_context`: required when `trigger = scheduler`

### `capabilities`

Capability flags declared by the replay bundle. These are passed through to the normalized trace.

Required flags (default `false` if omitted, except `supports_tool_trace` in replay mode should usually be `true`):

- `supports_tool_trace`
- `supports_memory_events`
- `supports_scheduler_context`
- `supports_container_metadata`

### `script` (Replay Steps)

The `script` array is a simplified NanoClaw run transcript. The adapter maps each step to normalized events.

Supported step types in v1:

- `message_received` (optional if already in `input_messages`)
- `tool_call`
- `tool_result`
- `memory_read` (optional)
- `memory_write` (optional)
- `error`
- `final_output`

## Replay Step Shapes (V1)

### `tool_call`

```json
{
  "type": "tool_call",
  "tool": "web_search",
  "call_id": "call-1",
  "args": { "query": "latest AI news today" },
  "ts": "2026-02-24T17:00:00.500Z"
}
```

### `tool_result`

```json
{
  "type": "tool_result",
  "tool": "web_search",
  "call_id": "call-1",
  "success": true,
  "result": { "items": [] },
  "fixture_id": "fx.web_search.current_ai_news",
  "ts": "2026-02-24T17:00:00.700Z"
}
```

### `error`

```json
{
  "type": "error",
  "scope": "tool",
  "tool": "web_fetch",
  "call_id": "call-2",
  "error_type": "timeout",
  "message": "Timed out after 5000ms",
  "retryable": true
}
```

### `memory_read` / `memory_write` (Optional)

```json
{
  "type": "memory_read",
  "group_id": "group-a",
  "source": "CLAUDE.md",
  "path": "groups/group-a/CLAUDE.md"
}
```

```json
{
  "type": "memory_write",
  "group_id": "group-a",
  "source": "CLAUDE.md",
  "path": "groups/group-a/CLAUDE.md",
  "change_summary": "Stored formatting preference"
}
```

### `final_output`

```json
{
  "type": "final_output",
  "role": "assistant",
  "content": "- Bullet one\n- Bullet two\n- Bullet three"
}
```

## Normalization Rules

The replay adapter should:

1. Assign sequential `seq` values in script order
2. Generate `event_id`s if missing
3. Copy scenario `group_id`, `session_id`, and `task_id` onto every event when absent in a step
4. Map `script[].ts` to normalized event timestamps; synthesize timestamps if missing
5. Emit a top-level normalized `final_output` from:
- explicit `final_output` field if present
- otherwise the last `script` step of type `final_output`
6. Preserve `call_id` links between `tool_call`, `tool_result`, and `error`

## Validation Rules (V1)

The replay bundle is invalid if:

- `schema_version` is missing
- `scenario.trigger` is missing or unsupported
- a `tool_result` references a `call_id` that never appeared in `tool_call`
- `final_output.content` is missing for `status = success`
- `scheduler_context` is missing when `scenario.trigger = scheduler`

## Relationship to `test.yaml`

Recommended `test.yaml` reference:

```yaml
adapter_input:
  replay_file: "./replay.json"
```

The core runner should treat `test.yaml` as the source of assertions and `replay.json` as the source of replayed execution behavior.

## Why This Shape (V1)

- Small enough to author by hand for examples
- Rich enough to test tool ordering, groundedness, and memory/isolation
- Close enough to a future captured trace format to allow tooling migration later

