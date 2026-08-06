.PHONY: validate clawhub

validate:
	@./scripts/validate.sh

clawhub:
	@./scripts/build-clawhub.sh
