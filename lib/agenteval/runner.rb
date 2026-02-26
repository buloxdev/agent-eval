# frozen_string_literal: true

module AgentEval
  class Runner
    RESULT_SCHEMA_VERSION = "0.1"

    def run(path)
      test_files = discover_test_files(path)
      if test_files.empty?
        warn "No test files found at #{path}"
        return 3
      end

      run_id = "run-#{Time.now.utc.strftime("%Y%m%d%H%M%S")}-#{SecureRandom.hex(4)}"
      started_at = Time.now.utc
      results = []

      test_files.each do |test_file|
        results << run_single(test_file, run_id)
      rescue StandardError => e
        result = error_result(test_file, run_id, e)
        Reporter.print_test_result(result)
        results << result
      end

      Reporter.print_run_summary(results, run_id, started_at)
      exit_code_for(results)
    end

    private

    def discover_test_files(path)
      p = Pathname(path)
      if p.file?
        [p.expand_path.to_s]
      elsif p.directory?
        Dir.glob(p.join("**", "test.yaml").to_s).sort
      else
        []
      end
    end

    def load_yaml(path)
      YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
    end

    def load_json(path)
      JSON.parse(File.read(path))
    end

    def run_single(test_file, run_id)
      spec = load_yaml(test_file)
      replay_path = resolve_replay_path(test_file, spec)
      replay = load_json(replay_path)
      test_file_display = display_path(test_file)
      replay_path_display = display_path(replay_path)

      trace = ReplayNormalizer.new.normalize(
        spec,
        replay,
        test_file: test_file_display,
        replay_file: replay_path_display,
        run_id: run_id
      )
      assertion_result = AssertionEngine.new.evaluate(spec, trace)

      result = build_result(spec, trace, assertion_result, run_id)
      persist_artifacts_if_needed(spec, trace, result, run_id)
      Reporter.print_test_result(result)
      result
    end

    def resolve_replay_path(test_file, spec)
      rel = spec.dig("adapter_input", "replay_file")
      raise "Missing adapter_input.replay_file in #{test_file}" unless rel

      Pathname(test_file).dirname.join(rel).expand_path.to_s
    end

    def build_result(spec, trace, assertion_result, run_id)
      started_at = Time.now.utc
      status = assertion_result[:critical_failures].positive? ? "fail" : "pass"
      finished_at = Time.now.utc

      base_result(
        test_case_id: spec["id"],
        run_id: run_id,
        adapter: trace["adapter"],
        status: status,
        started_at: started_at,
        finished_at: finished_at,
        duration_ms: trace.dig("metrics", "timing_ms_total"),
        failure_categories: status == "fail" ? Array(spec.dig("expected", "failure_categories")) : []
      ).merge(
        "summary" => build_summary(assertion_result[:assertions], assertion_result[:critical_failures]),
        "assertions" => assertion_result[:assertions],
        "trace_summary" => build_trace_summary(trace),
        "evidence" => {
          "final_output_excerpt" => trace.dig("final_output", "content").to_s[0, 240],
          "test_file" => trace.dig("artifacts", "test_file"),
          "replay_file" => trace.dig("artifacts", "replay_file")
        }
      )
    end

    def base_result(test_case_id:, run_id:, adapter:, status:, started_at:, finished_at:, duration_ms:, failure_categories:)
      {
        "schema_version" => RESULT_SCHEMA_VERSION,
        "result_id" => "result-#{SecureRandom.uuid}",
        "test_case_id" => test_case_id,
        "test_run_id" => run_id,
        "adapter" => adapter || { "name" => "unknown", "version" => AgentEval::VERSION },
        "status" => status,
        "started_at" => started_at.iso8601,
        "finished_at" => finished_at.iso8601,
        "duration_ms" => duration_ms || 0,
        "summary" => build_summary([], 0),
        "failure_categories" => Array(failure_categories),
        "assertions" => [],
        "trace_summary" => empty_trace_summary,
        "evidence" => {},
        "artifacts" => {}
      }
    end

    def build_summary(assertions, critical_failures)
      {
        "assertions_total" => assertions.size,
        "assertions_passed" => assertions.count { |a| a["status"] == "pass" },
        "assertions_failed" => assertions.count { |a| a["status"] == "fail" },
        "assertions_warned" => assertions.count { |a| a["status"] == "warn" },
        "assertions_skipped" => assertions.count { |a| a["status"] == "skip" },
        "critical_failures" => critical_failures
      }
    end

    def build_trace_summary(trace)
      return empty_trace_summary unless trace.is_a?(Hash)

      tool_calls = Array(trace["events"])
        .select { |e| e["type"] == "tool_call" }
        .group_by { |e| e.dig("data", "tool").to_s }
        .sort_by { |tool, _events| tool }
        .map { |tool, events| { "tool" => tool.empty? ? "unknown" : tool, "count" => events.size } }

      {
        "trace_id" => trace["trace_id"],
        "status" => trace["status"],
        "tool_calls" => tool_calls,
        "retry_count" => trace.dig("metrics", "retry_count") || 0,
        "timing_ms_total" => trace.dig("metrics", "timing_ms_total") || 0
      }
    end

    def empty_trace_summary
      {
        "trace_id" => nil,
        "status" => nil,
        "tool_calls" => [],
        "retry_count" => 0,
        "timing_ms_total" => 0
      }
    end

    def persist_artifacts_if_needed(spec, trace, result, run_id)
      return unless spec.dig("reporting", "save_trace")

      out_dir = Pathname("artifacts").expand_path.join(run_id)
      FileUtils.mkdir_p(out_dir)

      safe_id = spec["id"].gsub(/[^a-zA-Z0-9._-]/, "_")
      trace_path = out_dir.join("#{safe_id}.trace.json")
      result_path = out_dir.join("#{safe_id}.result.json")

      File.write(trace_path, JSON.pretty_generate(trace))
      File.write(result_path, JSON.pretty_generate(result))

      result["artifacts"]["result_path"] = display_path(result_path.to_s)
      result["artifacts"]["report_path"] = display_path(result_path.to_s)
      result["artifacts"]["trace_path"] = display_path(trace_path.to_s)
    end

    def error_result(test_file, run_id, err)
      error_case_id = begin
        path = Pathname(test_file)
        "unknown:#{path.dirname.basename}"
      rescue StandardError
        "unknown:#{File.basename(test_file)}"
      end

      now = Time.now.utc
      base_result(
        test_case_id: error_case_id,
        run_id: run_id,
        adapter: { "name" => "unknown", "version" => AgentEval::VERSION },
        status: "error",
        started_at: now,
        finished_at: now,
        duration_ms: 0,
        failure_categories: ["framework error"]
      ).merge(
        "evidence" => {
          "error" => sanitize_error_message(err),
          "test_file" => display_path(test_file)
        }
      )
    end

    def display_path(path)
      absolute = Pathname(path).expand_path
      cwd = Pathname(Dir.pwd).expand_path
      absolute.relative_path_from(cwd).to_s
    rescue StandardError
      path.to_s
    end

    def sanitize_error_message(err)
      msg = "#{err.class}: #{err.message}"
      root = Pathname(Dir.pwd).expand_path.to_s
      home = File.expand_path("~")

      msg = msg.gsub(root, ".")
      msg = msg.gsub(home, "~")
      msg = msg.gsub(%r{/Users/[^/]+}, "/Users/<user>")
      msg
    end

    def exit_code_for(results)
      return 2 if results.any? { |r| r["status"] == "error" }
      return 1 if results.any? { |r| r["status"] == "fail" }

      0
    end
  end
end
