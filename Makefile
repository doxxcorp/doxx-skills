.PHONY: build build-check validate test clawhub clawhub-check check api-drift

build:
	@./scripts/build.sh

build-check: build
	@if [ -n "$$(git status --porcelain claude openclaw codex)" ]; then \
		git status --porcelain claude openclaw codex; \
		echo "generated skills are stale: edit src/, run 'make build' and commit the result"; \
		exit 1; \
	fi

validate:
	@./scripts/validate.sh

test: build
	@./tests/run.sh

clawhub: build
	@./clawhub/scripts/build.sh

clawhub-check: clawhub
	@if [ -n "$$(git status --porcelain clawhub/dist)" ]; then \
		git status --porcelain clawhub/dist; \
		echo "clawhub/dist is stale: run 'make clawhub' and commit the result"; \
		exit 1; \
	fi

# Everything offline a PR must pass: generated trees and the ClawHub bundle
# match src/, then validation (which also runs the Code Mode tests).
check: build-check clawhub-check validate

# Network: compare api/reference.md with the live Config API manifest.
# Offline: make api-drift MANIFEST=path/to/manifest.json
api-drift:
	@./scripts/api-drift.sh $(if $(MANIFEST),--manifest $(MANIFEST))
