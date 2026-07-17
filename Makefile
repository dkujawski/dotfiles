SHELL := /bin/bash

.PHONY: all agent-install agent-check agent-deploy agent-doctor human-deploy \
	install-brew install-agent-packages install-dotfiles deploy-load-secrets \
	check check-extra clear-secrets-cache clean force test help

all: agent-install

agent-install: install-brew install-agent-packages agent-deploy

agent-check:
	@./tools/deploy-agent.sh --dry-run --profile agent

agent-deploy:
	@./tools/deploy-agent.sh --profile agent

agent-doctor:
	@./tools/agent-doctor.sh

human-deploy:
	@./tools/deploy-agent.sh --profile human

install-brew:
	@echo "Checking for Homebrew..."
	@if ! command -v brew >/dev/null 2>&1; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi

install-agent-packages: install-brew
	@brew bundle --file="$(CURDIR)/Brewfile.agent"

# Compatibility targets retained for existing workflows.
install-dotfiles: human-deploy agent-deploy
deploy-load-secrets: human-deploy
check: agent-check
force: agent-install

check-extra:
	@echo "Broad home-directory deletion checks are intentionally disabled."
	@echo "Use 'make agent-check' for the targeted deployment preview."

clear-secrets-cache:
	@echo "Removing legacy plaintext secret caches, if present..."
	@for cache_dir in "$(HOME)/.cache/op-secrets-secure" "$(HOME)/.cache/op-secrets-macos"; do \
		if [[ -d "$$cache_dir" ]]; then rm -rf -- "$$cache_dir"; fi; \
	done

clean:
	@echo "No repository build artifacts to clean."

test:
	@bats tests
	@shellcheck --severity=warning home/.bash_profile home/.bashrc \
		home/.config/dotfiles/profiles/*.bash home/.local/share/bash/load-secrets.sh \
		tools/deploy-agent.sh tools/agent-doctor.sh
	@bash -n home/.bash_profile home/.bashrc home/.config/dotfiles/profiles/*.bash \
		home/.local/share/bash/load-secrets.sh tools/deploy-agent.sh tools/agent-doctor.sh \
		bootstrap.sh
	@./test-auth.sh

help:
	@echo "Local coding-agent dotfiles"
	@echo "  make agent-check       Preview targeted profile changes"
	@echo "  make agent-install     Install Homebrew dependencies and deploy (default)"
	@echo "  make agent-deploy      Deploy configuration without installing packages"
	@echo "  make agent-doctor      Validate tools, 1Password, and SSH integration"
	@echo "  make human-deploy      Install preserved human shell modules"
	@echo "  make test              Run deterministic shell tests"
