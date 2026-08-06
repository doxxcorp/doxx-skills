.PHONY: validate clawhub clawhub-check

validate:
	@./scripts/validate.sh

clawhub:
	@./clawhub/scripts/build.sh

clawhub-check: clawhub
	@if [ -n "$$(git status --porcelain clawhub/dist)" ]; then \
		git status --porcelain clawhub/dist; \
		echo "clawhub/dist is stale: run 'make clawhub' and commit the result"; \
		exit 1; \
	fi
