# frozen_string_literal: true

module AgentEval
  class AssertionEngine
    STOPWORDS = %w[
      the a an and or but if then than for with without from into onto over under by of on in to at
      is are was were be been being this that these those it its they them their there here as not no
      today latest short exactly useful help helps using used use more less earlier later can will should
      after before one two three
    ].freeze

    def evaluate(spec, trace)
      assertions = Array(spec["assertions"])
      results = assertions.map { |a| evaluate_assertion(a, spec, trace) }
      {
        assertions: results,
        critical_failures: results.count { |r| r["status"] == "fail" && r["severity"] == "critical" }
      }
    end

    private

    def evaluate_assertion(assertion, spec, trace)
      missing_caps = missing_capabilities(assertion["requires_capabilities"], trace["capabilities"])
      if missing_caps.any?
        return assertion_result(assertion, "skip", "Missing adapter capabilities: #{missing_caps.join(", ")}")
      end

      type = assertion["type"]
      params = assertion["params"] || {}
      method_name = "check_#{type}"
      unless respond_to?(method_name, true)
        return assertion_result(assertion, "fail", "Unsupported assertion type: #{type}")
      end

      send(method_name, assertion, params, spec, trace)
    rescue StandardError => e
      assertion_result(assertion, "fail", "Assertion error (#{type}): #{e.class}: #{e.message}")
    end

    def missing_capabilities(required, caps)
      Array(required).reject { |flag| caps[flag] }
    end

    def check_must_call_tool(assertion, params, _spec, trace)
      tool = params.fetch("tool")
      min_calls = (params["min_calls"] || 1).to_i
      matches = tool_calls(trace, tool)
      status = matches.size >= min_calls ? "pass" : "fail"
      assertion_result(assertion, status, "Expected #{tool} >= #{min_calls}, got #{matches.size}",
                       observed: { "matches" => matches.size }, event_refs: matches.map { |e| e["event_id"] })
    end

    def check_must_not_call_tool(assertion, params, _spec, trace)
      tool = params.fetch("tool")
      matches = tool_calls(trace, tool)
      status = matches.empty? ? "pass" : "fail"
      assertion_result(assertion, status, "Expected no #{tool} calls, got #{matches.size}",
                       observed: { "matches" => matches.size }, event_refs: matches.map { |e| e["event_id"] })
    end

    def check_tool_call_order(assertion, params, _spec, trace)
      before_sel = params.fetch("before")
      after_sel = params.fetch("after")
      before_event = trace["events"].find { |e| event_matches_selector?(e, before_sel) }
      after_event = trace["events"].find { |e| event_matches_selector?(e, after_sel) }

      if before_event.nil? || after_event.nil?
        return assertion_result(assertion, "fail", "Missing required events for ordering check",
                                observed: { "before_found" => !before_event.nil?, "after_found" => !after_event.nil? })
      end

      status = before_event["seq"] < after_event["seq"] ? "pass" : "fail"
      assertion_result(assertion, status, "Expected #{selector_label(before_sel)} before #{selector_label(after_sel)}",
                       event_refs: [before_event["event_id"], after_event["event_id"]])
    end

    def check_max_tool_calls(assertion, params, _spec, trace)
      if params["tool"]
        tool = params["tool"]
        max = params.fetch("max").to_i
        matches = tool_calls(trace, tool)
        status = matches.size <= max ? "pass" : "fail"
        assertion_result(assertion, status, "Expected #{tool} calls <= #{max}, got #{matches.size}",
                         observed: { "matches" => matches.size, "max" => max },
                         event_refs: matches.map { |e| e["event_id"] })
      else
        max_total = params.fetch("max_total").to_i
        matches = trace["events"].select { |e| e["type"] == "tool_call" }
        status = matches.size <= max_total ? "pass" : "fail"
        assertion_result(assertion, status, "Expected total tool calls <= #{max_total}, got #{matches.size}",
                         observed: { "matches" => matches.size, "max_total" => max_total },
                         event_refs: matches.map { |e| e["event_id"] })
      end
    end

    def check_tool_args_match(assertion, params, _spec, trace)
      tool = params.fetch("tool")
      match_cfg = params.fetch("match", {})
      calls = tool_calls(trace, tool)

      if calls.empty?
        return assertion_result(assertion, "fail", "No #{tool} tool_call events found",
                                observed: { "tool" => tool, "calls_seen" => 0 })
      end

      matched_event = nil
      failure_reasons = []

      calls.each do |event|
        args = event.dig("data", "args") || {}
        reasons = []

        Array(match_cfg["required_keys"]).each do |key|
          reasons << "missing required key #{key}" unless args.key?(key)
        end

        (match_cfg["args_contains"] || {}).each do |key, expected|
          actual = nested_value(args, key) || args[key]
          if actual.nil?
            reasons << "missing key #{key} for args_contains"
            next
          end

          if actual.is_a?(String) && expected.is_a?(String)
            reasons << "args_contains mismatch for #{key}" unless actual.downcase.include?(expected.downcase)
          else
            reasons << "args_contains mismatch for #{key}" unless actual == expected
          end
        end

        (match_cfg["regex"] || {}).each do |key, pattern|
          actual = nested_value(args, key) || args[key]
          if actual.nil?
            reasons << "missing key #{key} for regex"
            next
          end
          reasons << "regex mismatch for #{key}" unless Regexp.new(pattern, Regexp::IGNORECASE).match?(actual.to_s)
        end

        if reasons.empty?
          matched_event = event
          break
        else
          failure_reasons << { "event_id" => event["event_id"], "reasons" => reasons }
        end
      end

      if matched_event
        assertion_result(assertion, "pass", "Found matching #{tool} tool_call args",
                         observed: {
                           "tool" => tool,
                           "matched_event_id" => matched_event["event_id"],
                           "matched_args" => matched_event.dig("data", "args") || {}
                         },
                         event_refs: [matched_event["event_id"]])
      else
        msg = failure_reasons.map { |r| "#{r["event_id"]}: #{r["reasons"].join(", ")}" }.join(" | ")
        assertion_result(assertion, "fail", "No #{tool} calls matched args constraints (#{msg})",
                         observed: {
                           "tool" => tool,
                           "calls_seen" => calls.size,
                           "match_rules" => match_cfg,
                           "per_event_failures" => failure_reasons
                         },
                         event_refs: calls.map { |e| e["event_id"] })
      end
    end

    def check_stop_after_success(assertion, params, _spec, trace)
      success_sel = params.fetch("success_event")
      forbid_sel = params.fetch("forbid_following")
      allowed_tools = Array(params["allowed_following_tools"])

      success_event = trace["events"].find { |e| event_matches_selector?(e, success_sel) }
      if success_event.nil?
        return assertion_result(assertion, "fail", "No success_event matched #{selector_label(success_sel)}",
                                observed: {
                                  "success_event_selector" => success_sel,
                                  "forbid_following_selector" => forbid_sel
                                })
      end

      violating_events = trace["events"].select do |e|
        next false unless e["seq"] > success_event["seq"]
        next false unless event_matches_selector?(e, forbid_sel)
        next false if allowed_tools.include?(e.dig("data", "tool"))

        true
      end

      if violating_events.any?
        tools = violating_events.map { |e| e.dig("data", "tool") || e["type"] }.uniq
        return assertion_result(assertion, "fail",
                                "Found forbidden events after success_event: #{tools.join(", ")}",
                                observed: {
                                  "success_event_id" => success_event["event_id"],
                                  "success_event_seq" => success_event["seq"],
                                  "forbid_following_selector" => forbid_sel,
                                  "allowed_following_tools" => allowed_tools,
                                  "violations" => violating_events.map do |e|
                                    {
                                      "event_id" => e["event_id"],
                                      "seq" => e["seq"],
                                      "type" => e["type"],
                                      "tool" => e.dig("data", "tool")
                                    }
                                  end
                                },
                                event_refs: [success_event["event_id"]] + violating_events.map { |e| e["event_id"] })
      end

      assertion_result(assertion, "pass", "No forbidden events after success_event",
                       observed: {
                         "success_event_id" => success_event["event_id"],
                         "success_event_seq" => success_event["seq"],
                         "allowed_following_tools" => allowed_tools
                       },
                       event_refs: [success_event["event_id"]])
    end

    def check_output_contains(assertion, params, _spec, trace)
      text = final_output_text(trace)
      case_sensitive = params.fetch("case_sensitive", false)
      haystack = case_sensitive ? text : text.downcase

      failures = []
      any_of = Array(params["any_of"])
      all_of = Array(params["all_of"])
      regexes = Array(params["regex"])

      if any_of.any?
        any_match = any_of.any? do |needle|
          (case_sensitive ? haystack.include?(needle) : haystack.include?(needle.downcase))
        end
        failures << "none of any_of matched" unless any_match
      end

      all_of.each do |needle|
        ok = case_sensitive ? haystack.include?(needle) : haystack.include?(needle.downcase)
        failures << "missing #{needle.inspect}" unless ok
      end

      regexes.each do |pattern|
        re = Regexp.new(pattern, case_sensitive ? nil : Regexp::IGNORECASE)
        failures << "regex #{pattern.inspect} did not match" unless re.match?(text)
      end

      status = failures.empty? ? "pass" : "fail"
      matched_any_of = any_of.select do |needle|
        case_sensitive ? haystack.include?(needle) : haystack.include?(needle.downcase)
      end
      matched_all_of = all_of.select do |needle|
        case_sensitive ? haystack.include?(needle) : haystack.include?(needle.downcase)
      end
      matched_regexes = regexes.select do |pattern|
        Regexp.new(pattern, case_sensitive ? nil : Regexp::IGNORECASE).match?(text)
      end

      assertion_result(assertion, status, failures.empty? ? "Output contains expected content" : failures.join("; "),
                       observed: {
                         "case_sensitive" => case_sensitive,
                         "any_of_count" => any_of.size,
                         "all_of_count" => all_of.size,
                         "regex_count" => regexes.size,
                         "matched_any_of" => matched_any_of,
                         "matched_all_of" => matched_all_of,
                         "matched_regexes" => matched_regexes,
                         "final_output_excerpt" => text[0, 200]
                       })
    end

    def check_output_matches_format(assertion, params, _spec, trace)
      text = final_output_text(trace)
      format = params.fetch("format")

      case format
      when "bullet_list"
        bullet_lines = text.lines.map(&:rstrip).select { |l| l.match?(/^\s*[-*]\s+/) }
        failures = []
        failures << "no bullet lines found" if bullet_lines.empty?
        if params["min_bullets"] && bullet_lines.size < params["min_bullets"].to_i
          failures << "bullet count #{bullet_lines.size} < #{params["min_bullets"]}"
        end
        if params["max_bullets"] && bullet_lines.size > params["max_bullets"].to_i
          failures << "bullet count #{bullet_lines.size} > #{params["max_bullets"]}"
        end
        if params["max_sentences_per_bullet"]
          max_sent = params["max_sentences_per_bullet"].to_i
          bullet_lines.each_with_index do |line, idx|
            sentence_count = line.scan(/[.!?](?:\s|$)/).size
            sentence_count = 1 if sentence_count.zero? && line.strip.length.positive?
            if sentence_count > max_sent
              failures << "bullet #{idx + 1} has #{sentence_count} sentences > #{max_sent}"
            end
          end
        end
        status = failures.empty? ? "pass" : "fail"
        assertion_result(assertion, status, failures.empty? ? "Output matches bullet_list" : failures.join("; "),
                         observed: {
                           "bullet_count" => bullet_lines.size,
                           "format" => "bullet_list",
                           "sample_bullets" => bullet_lines.first(2),
                           "final_output_excerpt" => text[0, 200]
                         })
      when "paragraphs"
        paragraphs = split_paragraphs(text)
        failures = []
        if params["exact_paragraphs"] && paragraphs.size != params["exact_paragraphs"].to_i
          failures << "paragraph count #{paragraphs.size} != #{params["exact_paragraphs"]}"
        end
        status = failures.empty? ? "pass" : "fail"
        assertion_result(assertion, status, failures.empty? ? "Output matches paragraphs" : failures.join("; "),
                         observed: {
                           "paragraph_count" => paragraphs.size,
                           "format" => "paragraphs",
                           "sample_paragraphs" => paragraphs.first(2)
                         })
      when "json"
        begin
          parsed = JSON.parse(text)
          failures = []
          Array(params["required_keys"]).each do |k|
            failures << "missing key #{k}" unless parsed.is_a?(Hash) && parsed.key?(k)
          end
          status = failures.empty? ? "pass" : "fail"
          assertion_result(assertion, status, failures.empty? ? "Output matches json" : failures.join("; "),
                           observed: {
                             "format" => "json",
                             "parsed_type" => parsed.class.name,
                             "parsed_keys" => parsed.is_a?(Hash) ? parsed.keys : [],
                             "required_keys" => Array(params["required_keys"])
                           })
        rescue JSON::ParserError => e
          assertion_result(assertion, "fail", "Invalid JSON output: #{e.message}",
                           observed: { "format" => "json", "final_output_excerpt" => text[0, 200] })
        end
      else
        assertion_result(assertion, "fail", "Unsupported format: #{format}",
                         observed: { "format" => format, "supported_formats" => %w[bullet_list paragraphs json] })
      end
    end

    def check_output_omits(assertion, params, _spec, trace)
      text = final_output_text(trace)
      patterns = Array(params["patterns"])
      regex_mode = params.fetch("regex", false)
      case_sensitive = params.fetch("case_sensitive", false)

      matches = patterns.map do |pattern|
        if regex_mode
          re = Regexp.new(pattern, case_sensitive ? nil : Regexp::IGNORECASE)
          pattern if re.match?(text)
        else
          haystack = case_sensitive ? text : text.downcase
          needle = case_sensitive ? pattern : pattern.downcase
          pattern if haystack.include?(needle)
        end
      end.compact

      status = matches.empty? ? "pass" : "fail"
      assertion_result(assertion, status, matches.empty? ? "Output omits forbidden patterns" : "Matched forbidden patterns: #{matches.join(", ")}",
                       observed: {
                         "regex_mode" => regex_mode,
                         "case_sensitive" => case_sensitive,
                         "patterns_checked" => patterns.size,
                         "matched_patterns" => matches,
                         "final_output_excerpt" => text[0, 200]
                       })
    end

    def check_claims_supported_by_fixtures(assertion, params, _spec, trace)
      allowed_tools = Array(params["allowed_sources"])
      tool_results = trace["events"].select do |e|
        e["type"] == "tool_result" && allowed_tools.include?(e.dig("data", "tool")) && e.dig("data", "success") != false
      end

      if tool_results.empty?
        return assertion_result(assertion, "fail", "No successful tool_result events for allowed_sources",
                                observed: { "allowed_sources" => allowed_tools, "tool_results_seen" => 0 })
      end

      output = final_output_text(trace)
      urls_in_output = output.scan(%r{https?://[^\s)]+})
      fixture_urls = tool_results.flat_map { |e| collect_values(e.dig("data", "result")).grep(String) }
                              .grep(%r{\Ahttps?://})
                              .uniq
      unsupported_urls = urls_in_output.reject { |u| fixture_urls.include?(u) }
      unless unsupported_urls.empty?
        return assertion_result(assertion, "fail", "Unsupported URLs in output: #{unsupported_urls.join(", ")}",
                                observed: {
                                  "allowed_sources" => allowed_tools,
                                  "output_urls" => urls_in_output,
                                  "fixture_urls" => fixture_urls,
                                  "unsupported_urls" => unsupported_urls
                                },
                                event_refs: tool_results.map { |e| e["event_id"] })
      end

      corpus_tokens = tool_results.flat_map { |e| collect_values(e.dig("data", "result")) }
                                .grep(String)
                                .flat_map { |s| normalized_tokens(s) }
                                .uniq

      unsupported_lines = content_units(output).map do |unit|
        tokens = normalized_tokens(unit)
        next if tokens.empty?

        required_overlap = [2, [1, tokens.size / 3].max].min
        overlap = (tokens & corpus_tokens)
        unit if overlap.size < required_overlap
      end.compact

      status = unsupported_lines.empty? ? "pass" : "fail"
      msg = if status == "pass"
              "Output claims are supported by fixture content (heuristic)"
            else
              "Unsupported content units: #{unsupported_lines.join(" | ")}"
            end
      assertion_result(assertion, status, msg,
                       observed: {
                         "allowed_sources" => allowed_tools,
                         "tool_result_events" => tool_results.map { |e| e["event_id"] },
                         "content_units_checked" => content_units(output).size,
                         "unsupported_units" => unsupported_lines
                       },
                       event_refs: tool_results.map { |e| e["event_id"] })
    end

    def check_memory_recall_same_group(assertion, params, _spec, trace)
      expected_fact = params["expected_memory_fact"].to_s
      group_id = params["group_id"] || trace.dig("scenario", "group_id")
      memory_events = trace["events"].select do |e|
        %w[memory_read memory_write].include?(e["type"]) && e["group_id"] == group_id
      end

      output = final_output_text(trace)
      heuristic_ok = true
      if expected_fact.downcase.include?("bullet")
        heuristic_ok &&= output.lines.any? { |l| l.match?(/^\s*[-*]\s+/) }
      end

      if expected_fact.downcase.include?("brief")
        bullet_lines = output.lines.select { |l| l.match?(/^\s*[-*]\s+/) }
        heuristic_ok &&= bullet_lines.all? { |l| l.length <= 220 } unless bullet_lines.empty?
      end

      status = (!memory_events.empty? || heuristic_ok) ? "pass" : "fail"
      assertion_result(assertion, status,
                       status == "pass" ? "Same-group memory recall appears honored" : "No same-group memory evidence or matching output behavior",
                       observed: {
                         "group_id" => group_id,
                         "expected_memory_fact" => expected_fact,
                         "memory_event_count" => memory_events.size,
                         "heuristic_ok" => heuristic_ok,
                         "final_output_excerpt" => output[0, 200]
                       },
                       event_refs: memory_events.map { |e| e["event_id"] })
    end

    def check_no_cross_group_memory_use(assertion, params, _spec, trace)
      forbidden_groups = Array(params["forbidden_group_ids"])
      require_proof = params.fetch("require_event_level_proof", false)
      memory_events = trace["events"].select { |e| %w[memory_read memory_write].include?(e["type"]) }

      forbidden_events = memory_events.select { |e| forbidden_groups.include?(e["group_id"]) }
      if forbidden_events.any?
        return assertion_result(assertion, "fail", "Accessed forbidden group memory: #{forbidden_events.map { |e| e["group_id"] }.uniq.join(", ")}",
                                observed: {
                                  "forbidden_group_ids" => forbidden_groups,
                                  "memory_event_count" => memory_events.size,
                                  "forbidden_event_count" => forbidden_events.size
                                },
                                event_refs: forbidden_events.map { |e| e["event_id"] })
      end

      if require_proof && memory_events.empty?
        return assertion_result(assertion, "fail", "Event-level proof requested but no memory events available",
                                observed: {
                                  "forbidden_group_ids" => forbidden_groups,
                                  "require_event_level_proof" => require_proof,
                                  "memory_event_count" => 0
                                })
      end

      assertion_result(assertion, "pass", "No forbidden group memory access observed",
                       observed: {
                         "forbidden_group_ids" => forbidden_groups,
                         "require_event_level_proof" => require_proof,
                         "memory_event_count" => memory_events.size
                       },
                       event_refs: memory_events.map { |e| e["event_id"] })
    end

    def check_scheduler_outbound_count(assertion, params, _spec, trace)
      trigger = trace.dig("scenario", "trigger")
      unless trigger == "scheduler"
        return assertion_result(assertion, "fail", "scheduler_outbound_count requires scheduler-triggered trace",
                                observed: { "trigger" => trigger })
      end

      tool = params["tool"] || "outbound_send"
      calls = tool_calls(trace, tool)
      count = calls.size

      min = params.key?("min") ? params["min"].to_i : nil
      max = params.key?("max") ? params["max"].to_i : nil
      exact = params.key?("exact") ? params["exact"].to_i : nil

      failures = []
      failures << "count #{count} != exact #{exact}" if !exact.nil? && count != exact
      failures << "count #{count} < min #{min}" if !min.nil? && count < min
      failures << "count #{count} > max #{max}" if !max.nil? && count > max

      status = failures.empty? ? "pass" : "fail"
      assertion_result(assertion, status,
                       failures.empty? ? "Scheduler outbound count matched" : failures.join("; "),
                       observed: {
                         "trigger" => trigger,
                         "tool" => tool,
                         "count" => count,
                         "exact" => exact,
                         "min" => min,
                         "max" => max
                       },
                       event_refs: calls.map { |e| e["event_id"] })
    end

    def check_scheduler_task_runs(assertion, params, _spec, trace)
      trigger = trace.dig("scenario", "trigger")
      required_trigger = params["trigger_must_equal"] || "scheduler"
      task_id = trace.dig("scenario", "task_id") || trace.dig("scenario", "scheduler_context", "task_id")
      expected_task_id = params["task_id"]

      failures = []
      failures << "trigger #{trigger.inspect} != #{required_trigger.inspect}" unless trigger == required_trigger
      if expected_task_id && task_id != expected_task_id
        failures << "task_id #{task_id.inspect} != #{expected_task_id.inspect}"
      end

      scheduler_events = trace["events"].select { |e| e["task_id"] == task_id && !task_id.nil? }
      if required_trigger == "scheduler" && task_id && scheduler_events.empty?
        failures << "no events scoped to scheduler task_id #{task_id.inspect}"
      end

      status = failures.empty? ? "pass" : "fail"
      assertion_result(assertion, status,
                       failures.empty? ? "Scheduler task context is present and matches" : failures.join("; "),
                       observed: {
                         "trigger" => trigger,
                         "required_trigger" => required_trigger,
                         "task_id" => task_id,
                         "expected_task_id" => expected_task_id,
                         "task_scoped_event_count" => scheduler_events.size
                       },
                       event_refs: scheduler_events.map { |e| e["event_id"] })
    end

    def check_retry_policy_respected(assertion, params, _spec, trace)
      tool = params.fetch("tool")
      max_retries = params.fetch("max_retries").to_i
      retry_on_error_types = Array(params["retry_on_error_types"])

      tool_error_events = trace["events"].select do |e|
        e["type"] == "error" && e.dig("data", "tool") == tool
      end

      if tool_error_events.empty?
        return assertion_result(assertion, "fail", "No error events found for tool #{tool}",
                                observed: { "tool" => tool, "error_events" => 0 })
      end

      disallowed_error_events = tool_error_events.select do |e|
        next false if retry_on_error_types.empty?
        !retry_on_error_types.include?(e.dig("data", "error_type"))
      end

      if disallowed_error_events.any?
        return assertion_result(assertion, "fail",
                                "Found error types outside retry policy: #{disallowed_error_events.map { |e| e.dig("data", "error_type") }.uniq.join(", ")}",
                                observed: {
                                  "tool" => tool,
                                  "retry_on_error_types" => retry_on_error_types,
                                  "error_types_seen" => tool_error_events.map { |e| e.dig("data", "error_type") }.uniq
                                },
                                event_refs: tool_error_events.map { |e| e["event_id"] })
      end

      call_events = tool_calls(trace, tool)
      retry_count = [call_events.size - 1, 0].max
      if retry_count > max_retries
        return assertion_result(assertion, "fail",
                                "Retry count #{retry_count} exceeds max_retries #{max_retries} for #{tool}",
                                observed: {
                                  "tool" => tool,
                                  "tool_call_count" => call_events.size,
                                  "retry_count" => retry_count,
                                  "max_retries" => max_retries
                                },
                                event_refs: (call_events + tool_error_events).map { |e| e["event_id"] }.uniq)
      end

      assertion_result(assertion, "pass", "Retry policy respected for #{tool}",
                       observed: {
                         "tool" => tool,
                         "tool_call_count" => call_events.size,
                         "retry_count" => retry_count,
                         "max_retries" => max_retries,
                         "error_types_seen" => tool_error_events.map { |e| e.dig("data", "error_type") }.uniq
                       },
                       event_refs: (call_events + tool_error_events).map { |e| e["event_id"] }.uniq)
    end

    def check_graceful_failure_output(assertion, params, _spec, trace)
      text = final_output_text(trace)
      down = text.downcase
      allowed_failure_phrases = Array(params["allowed_failure_phrases"])
      must_not_claim_success = params.fetch("must_not_claim_success", true)

      errors = trace["events"].select { |e| e["type"] == "error" }
      if errors.empty?
        return assertion_result(assertion, "fail", "No error events found; graceful failure check requires a failure scenario",
                                observed: { "error_events" => 0, "final_output_excerpt" => text[0, 200] })
      end

      matched_failure_phrase = allowed_failure_phrases.find { |p| down.include?(p.downcase) }
      unless matched_failure_phrase
        return assertion_result(assertion, "fail",
                                "Output does not contain an allowed failure phrase",
                                observed: {
                                  "allowed_failure_phrases" => allowed_failure_phrases,
                                  "final_output_excerpt" => text[0, 200]
                                },
                                event_refs: errors.map { |e| e["event_id"] })
      end

      if must_not_claim_success
        success_patterns = Array(params["forbidden_success_phrases"])
        success_patterns = ["sent successfully", "completed successfully", "successfully sent", "all set"] if success_patterns.empty?
        matched_success = success_patterns.find { |p| down.include?(p.downcase) }
        if matched_success
          return assertion_result(assertion, "fail",
                                  "Output claims success despite error events (matched #{matched_success.inspect})",
                                  observed: {
                                    "matched_success_phrase" => matched_success,
                                    "allowed_failure_phrase_matched" => matched_failure_phrase,
                                    "error_events" => errors.size
                                  },
                                  event_refs: errors.map { |e| e["event_id"] })
        end
      end

      assertion_result(assertion, "pass", "Output communicates failure clearly",
                       observed: {
                         "allowed_failure_phrase_matched" => matched_failure_phrase,
                         "error_events" => errors.size,
                         "final_output_excerpt" => text[0, 200]
                       },
                       event_refs: errors.map { |e| e["event_id"] })
    end

    def tool_calls(trace, tool)
      trace["events"].select { |e| e["type"] == "tool_call" && e.dig("data", "tool") == tool }
    end

    def final_output_text(trace)
      trace.dig("final_output", "content").to_s
    end

    def event_matches_selector?(event, selector)
      return false unless event["type"] == selector["event_type"]
      return false if selector["tool"] && event.dig("data", "tool") != selector["tool"]
      return false if selector.key?("success") && event.dig("data", "success") != selector["success"]
      return false if selector["call_id"] && event.dig("data", "call_id") != selector["call_id"]

      true
    end

    def selector_label(selector)
      return "unknown" unless selector
      selector["tool"] ? "#{selector["event_type"]}(#{selector["tool"]})" : selector["event_type"]
    end

    def nested_value(obj, dotted_key)
      return nil unless dotted_key.to_s.include?(".")
      parts = dotted_key.to_s.split(".")
      parts.reduce(obj) do |memo, part|
        break nil unless memo.is_a?(Hash)
        memo[part]
      end
    end

    def assertion_result(assertion, status, message, observed: nil, event_refs: nil)
      {
        "id" => assertion["id"],
        "type" => assertion["type"],
        "severity" => assertion["severity"] || "critical",
        "status" => status,
        "message" => message,
        "params" => assertion["params"] || {},
        "observed" => observed || {},
        "evidence" => { "event_refs" => event_refs || [] },
        "capability_check" => {
          "required" => assertion["requires_capabilities"] || [],
          "available" => [],
          "status" => "not_applicable"
        }
      }
    end

    def split_paragraphs(text)
      text.to_s.split(/\n\s*\n+/).map(&:strip).reject(&:empty?)
    end

    def content_units(text)
      bullets = text.lines.map(&:strip).select { |l| l.match?(/^[-*]\s+/) }.map { |l| l.sub(/^[-*]\s+/, "") }
      return bullets unless bullets.empty?

      split_paragraphs(text)
    end

    def collect_values(value)
      case value
      when Hash
        value.values.flat_map { |v| collect_values(v) }
      when Array
        value.flat_map { |v| collect_values(v) }
      else
        [value]
      end
    end

    def normalized_tokens(str)
      str.downcase
         .scan(/[a-z0-9]+/)
         .map { |t| stem_token(t) }
         .reject { |t| t.length < 3 || STOPWORDS.include?(t) }
         .uniq
    end

    def stem_token(token)
      t = token.dup
      t = t.sub(/ies\z/, "y")
      t = t.sub(/(ing|ed)\z/, "") if t.length > 5
      t = t.sub(/s\z/, "") if t.length > 4
      t
    end
  end
end
