.PHONY: lint test test-unit test-integration test-e2e catalog validate new-app help

SHELL := /bin/bash
APPS_DIR := apps
SCRIPTS_DIR := scripts
TESTS_DIR := tests
BOOTSTRAP_DIR := bootstrap

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: ## Run ShellCheck on all shell scripts
	@echo "==> Running ShellCheck..."
	@find $(BOOTSTRAP_DIR) $(SCRIPTS_DIR) $(APPS_DIR) -name '*.sh' -type f | \
		xargs shellcheck -x -S warning
	@echo "==> ShellCheck passed."

lint-charts: ## Run helm lint on all charts
	@$(SCRIPTS_DIR)/lint-charts.sh

test: test-unit ## Run all tests

test-unit: ## Run unit tests (bats)
	@echo "==> Running unit tests..."
	@bats $(TESTS_DIR)/unit/

test-integration: ## Run integration tests (requires Docker)
	@echo "==> Running integration tests..."
	@bats $(TESTS_DIR)/integration/

test-e2e: ## Run E2E test (usage: make test-e2e APP=wordpress [VERSION=6.8.3])
	@if [ -z "$(APP)" ]; then echo "Usage: make test-e2e APP=wordpress [VERSION=6.8.3]"; exit 1; fi
	@$(TESTS_DIR)/e2e/setup-k3d.sh
	@APP_NAME=$(APP) APP_VERSION=$(VERSION) $(TESTS_DIR)/e2e/run-e2e.sh; \
		exit_code=$$?; \
		$(TESTS_DIR)/e2e/teardown-k3d.sh; \
		exit $$exit_code

catalog: ## Generate catalog.json from all app.yaml files
	@$(SCRIPTS_DIR)/generate-catalog.sh

validate: ## Validate all app.yaml files
	@$(SCRIPTS_DIR)/validate-apps.sh

new-app: ## Create a new app from template (usage: make new-app NAME=myapp [METHOD=kustomize])
	@if [ -z "$(NAME)" ]; then echo "Usage: make new-app NAME=myapp [METHOD=helm|kustomize|manifest]"; exit 1; fi
	@$(SCRIPTS_DIR)/new-app.sh $(NAME) $(if $(METHOD),--method $(METHOD))
