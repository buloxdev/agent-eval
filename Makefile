.PHONY: smoke schema-smoke privacy-smoke

smoke:
	./bin/agenteval-smoke

schema-smoke:
	./bin/agenteval-schema-smoke

privacy-smoke:
	./bin/agenteval-privacy-smoke
