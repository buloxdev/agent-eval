# frozen_string_literal: true

module AgentEval
  class ReplayNormalizer
    class ReplayValidationError < StandardError; end

    DEFAULT_CAPABILITIES = {
      "supports_tool_trace" => true,
      "supports_memory_events" => false,
      "supports_scheduler_context" => false,
      "supports_container_metadata" => false,
      "supports_live_run" => false,
      "supports_replay" => true
    }.freeze

    ACTOR_BY_TYPE = {
      "message_received" => "user",
      "tool_call" => "agent",
      "tool_result" => "tool",
      "memory_read" => "agent",
      "memory_write" => "agent",
      "error" => "system",
      "final_output" => "agent"
    }.freeze

    def normalize(spec, replay, test_file:, replay_file:, run_id:)
      validate_replay!(replay)

      scenario = replay["scenario"] || spec["scenario"] || {}
      capabilities = DEFAULT_CAPABILITIES.merge(replay["capabilities"] || {})
      events = normalize_events(replay["script"] || [], scenario)
      final_output = normalize_final_output(replay, events)

      {
        "schema_version" => "0.1",
        "trace_id" => "trace-#{SecureRandom.uuid}",
        "test_case_id" => spec["id"],
        "test_run_id" => run_id,
        "adapter" => {
          "name" => spec["adapter"] || "nanoclaw",
          "version" => AgentEval::VERSION
        },
        "capabilities" => capabilities,
        "scenario" => {
          "group_id" => scenario["group_id"] || spec.dig("scenario", "group_id"),
          "session_id" => scenario["session_id"] || spec.dig("scenario", "session_id"),
          "task_id" => scenario["task_id"] || spec.dig("scenario", "scheduler_context", "task_id"),
          "trigger" => scenario["trigger"] || spec.dig("scenario", "trigger"),
          "scheduler_context" => scenario["scheduler_context"] || spec.dig("scenario", "scheduler_context")
        },
        "input_messages" => replay["input_messages"] || spec.dig("scenario", "input_messages") || [],
        "events" => events,
        "final_output" => final_output,
        "status" => replay["status"] || "success",
        "metrics" => {
          "timing_ms_total" => replay.dig("metrics", "timing_ms_total") || 0,
          "tool_call_count" => events.count { |e| e["type"] == "tool_call" },
          "retry_count" => replay.dig("metrics", "retry_count") || 0,
          "token_usage" => replay.dig("metrics", "token_usage")
        },
        "artifacts" => {
          "source_replay_file" => replay_file,
          "source_test_file" => test_file
        }
      }
    end

    private

    def validate_replay!(replay)
      unless replay.is_a?(Hash)
        raise ReplayValidationError, "Replay bundle must be a JSON object"
      end

      required_top_level = %w[schema_version scenario input_messages script status metrics]
      missing = required_top_level.reject { |k| replay.key?(k) }
      unless missing.empty?
        raise ReplayValidationError, "Replay bundle missing required fields: #{missing.join(", ")}"
      end

      validate_scenario!(replay["scenario"])
      validate_script!(replay["script"])
      validate_success_output!(replay)
      validate_metrics!(replay["metrics"])
    end

    def validate_scenario!(scenario)
      unless scenario.is_a?(Hash)
        raise ReplayValidationError, "Replay scenario must be an object"
      end

      trigger = scenario["trigger"]
      unless %w[user_message scheduler].include?(trigger)
        raise ReplayValidationError, "Replay scenario.trigger must be 'user_message' or 'scheduler'"
      end

      if trigger == "scheduler" && scenario["scheduler_context"].nil?
        raise ReplayValidationError, "Replay scenario.scheduler_context is required when trigger is 'scheduler'"
      end
    end

    def validate_script!(script)
      unless script.is_a?(Array)
        raise ReplayValidationError, "Replay script must be an array"
      end

      seen_call_ids = {}
      script.each_with_index do |step, idx|
        unless step.is_a?(Hash)
          raise ReplayValidationError, "Replay script step #{idx} must be an object"
        end

        type = step["type"]
        if type.to_s.empty?
          raise ReplayValidationError, "Replay script step #{idx} missing required field: type"
        end

        case type
        when "tool_call"
          validate_tool_call_step!(step, idx)
          seen_call_ids[step["call_id"]] = true
        when "tool_result"
          validate_tool_result_step!(step, idx, seen_call_ids)
        when "error"
          if step["scope"] == "tool" || step["tool"] || step["call_id"]
            call_id = step["call_id"]
            if call_id && !seen_call_ids[call_id]
              raise ReplayValidationError, "Replay error step #{idx} references unknown tool call_id '#{call_id}'"
            end
          end
        when "message_received", "memory_read", "memory_write", "final_output"
          # valid v1 step types, no additional required fields for now
        else
          raise ReplayValidationError, "Replay script step #{idx} has unsupported type '#{type}'"
        end
      end
    end

    def validate_tool_call_step!(step, idx)
      %w[tool call_id].each do |field|
        next if step[field]
        raise ReplayValidationError, "Replay tool_call step #{idx} missing required field: #{field}"
      end
    end

    def validate_tool_result_step!(step, idx, seen_call_ids)
      %w[tool call_id success].each do |field|
        next if step.key?(field)
        raise ReplayValidationError, "Replay tool_result step #{idx} missing required field: #{field}"
      end

      call_id = step["call_id"]
      unless seen_call_ids[call_id]
        raise ReplayValidationError, "Replay tool_result step #{idx} references unknown tool call_id '#{call_id}'"
      end
    end

    def validate_success_output!(replay)
      return unless replay["status"] == "success"

      explicit = replay["final_output"]
      if explicit
        unless explicit.is_a?(Hash) && explicit.key?("content")
          raise ReplayValidationError, "Replay final_output.content is required when status is 'success'"
        end
        return
      end

      has_final_step = Array(replay["script"]).any? do |s|
        s.is_a?(Hash) && s["type"] == "final_output" && s.key?("content")
      end
      return if has_final_step

      raise ReplayValidationError, "Replay final_output.content is required when status is 'success'"
    end

    def validate_metrics!(metrics)
      unless metrics.is_a?(Hash)
        raise ReplayValidationError, "Replay metrics must be an object"
      end

      return if metrics.key?("timing_ms_total")

      raise ReplayValidationError, "Replay metrics.timing_ms_total is required"
    end

    def normalize_events(script, scenario)
      base_time = Time.now.utc
      script.each_with_index.map do |step, idx|
        type = step.fetch("type")
        {
          "event_id" => "evt-#{idx + 1}",
          "seq" => idx + 1,
          "ts" => (step["ts"] || (base_time + (idx * 0.001)).iso8601(3)),
          "type" => type,
          "actor" => ACTOR_BY_TYPE[type] || "system",
          "group_id" => step["group_id"] || scenario["group_id"],
          "session_id" => step["session_id"] || scenario["session_id"],
          "task_id" => step["task_id"] || scenario["task_id"],
          "agent_id" => step["agent_id"] || "agent-main",
          "parent_event_id" => nil,
          "data" => normalize_step_data(step)
        }.tap do |event|
          if %w[tool_result error].include?(type)
            event["parent_event_id"] = parent_event_for(script, idx, step["call_id"])
          end
        end
      end
    end

    def parent_event_for(script, idx, call_id)
      return nil unless call_id

      prior_idx = (0...idx).to_a.reverse.find do |i|
        s = script[i]
        s["type"] == "tool_call" && s["call_id"] == call_id
      end
      prior_idx ? "evt-#{prior_idx + 1}" : nil
    end

    def normalize_step_data(step)
      excluded = %w[type ts group_id session_id task_id agent_id]
      step.each_with_object({}) do |(k, v), out|
        out[k] = v unless excluded.include?(k)
      end
    end

    def normalize_final_output(replay, events)
      explicit = replay["final_output"]
      return explicit if explicit

      last_final = events.reverse.find { |e| e["type"] == "final_output" }
      if last_final
        {
          "role" => last_final.dig("data", "role") || "assistant",
          "content" => last_final.dig("data", "content").to_s
        }
      else
        { "role" => "assistant", "content" => "" }
      end
    end
  end
end
