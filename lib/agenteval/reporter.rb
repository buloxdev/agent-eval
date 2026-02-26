# frozen_string_literal: true

module AgentEval
  class Reporter
    class << self
      def print_test_result(result)
        status_value = result["status"].to_s
        status = status_value.upcase.ljust(5)
        duration_ms = result["duration_ms"] || result.dig("trace_summary", "timing_ms_total") || 0
        puts "#{status} #{result["test_case_id"]} (#{duration_ms}ms)"
        puts "  Adapter: #{result.dig("adapter", "name")}@#{result.dig("adapter", "version")}"
        if status_value == "error"
          puts "  Error: #{result.dig("evidence", "error")}"
          if (test_file = result.dig("evidence", "test_file"))
            puts "  Test file: #{test_file}"
          end
        end

        trace = result["trace_summary"] || {}
        if trace.any?
          tools = Array(trace["tool_calls"])
            .map { |t| "#{t["tool"] || "unknown"}(#{t["count"] || 0})" }
            .join(", ")
          trace_status = trace["status"] || "-"
          retry_count = trace["retry_count"] || 0
          puts "  Trace: #{trace_status} | Tools: #{tools.empty? ? "-" : tools} | Retries: #{retry_count}"
        end

        Array(result["assertions"]).each do |a|
          label = a["status"].upcase
          puts "  [#{label}] #{a["id"]} (#{a["type"]})"
          next if a["status"] == "pass"
          puts "       #{a["message"]}"
          refs = Array(a.dig("evidence", "event_refs"))
          puts "       Event refs: #{refs.join(", ")}" unless refs.empty?
          observed = compact_observed(a["observed"] || {})
          puts "       Observed: #{observed}" unless observed.nil? || observed.empty?
        end

        if result["failure_categories"]&.any? && status_value == "fail"
          puts "  Failure categories: #{result["failure_categories"].join(", ")}"
        end
        artifact_path = result.dig("artifacts", "result_path") || result.dig("artifacts", "report_path")
        if artifact_path
          puts "  Artifacts: #{artifact_path}"
        end
        puts
      end

      def print_run_summary(results, run_id, started_at)
        finished_at = Time.now.utc
        pass_count = results.count { |r| r["status"] == "pass" }
        fail_count = results.count { |r| r["status"] == "fail" }
        err_count = results.count { |r| r["status"] == "error" }

        puts "Run #{run_id} finished in #{((finished_at - started_at) * 1000).round}ms"
        puts "Summary: #{pass_count} passed, #{fail_count} failed, #{err_count} errors"
      end

      private

      def compact_observed(observed)
        return nil unless observed.is_a?(Hash) && !observed.empty?

        keys = %w[
          tool calls_seen matched_event_id success_event_id unsupported_urls unsupported_units
          violations content_units_checked matched_patterns matched_any_of matched_all_of matched_regexes
          bullet_count paragraph_count parsed_keys required_keys retry_count max_retries error_types_seen
          memory_event_count forbidden_group_ids error_events matched_success_phrase
          allowed_failure_phrase_matched final_output_excerpt
        ]
        subset = observed.each_with_object({}) do |(k, v), out|
          next unless keys.include?(k)
          out[k] = truncate_value(v)
        end
        subset = observed.transform_values { |v| truncate_value(v) } if subset.empty?
        subset.to_json
      end

      def truncate_value(value)
        case value
        when String
          value.length > 140 ? "#{value[0, 137]}..." : value
        when Array
          value.first(3).map { |v| truncate_value(v) }.tap do |arr|
            arr << "...(#{value.length - 3} more)" if value.length > 3
          end
        when Hash
          value.each_with_object({}).with_index do |((k, v), out), idx|
            break out if idx >= 4
            out[k] = truncate_value(v)
          end
        else
          value
        end
      end
    end
  end
end
