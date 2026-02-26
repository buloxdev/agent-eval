# frozen_string_literal: true

module AgentEval
  class CLI
    def initialize(argv)
      @argv = argv.dup
    end

    def run
      cmd = @argv.shift
      case cmd
      when "run"
        path = @argv.shift
        unless path
          warn "Usage: agenteval run <test.yaml|directory>"
          return 3
        end
        Runner.new.run(path)
      when nil, "-h", "--help", "help"
        puts "Usage:"
        puts "  agenteval run <test.yaml|directory>"
        0
      else
        warn "Unknown command: #{cmd}"
        warn "Usage: agenteval run <test.yaml|directory>"
        3
      end
    end
  end
end

