.PHONY: all install-dotfiles install-brew clean check check-extra deploy-load-secrets

# Default target
all: install-dotfiles install-brew 

# Deploy the shell-based load-secrets tool
deploy-load-secrets:
	@echo "Deploying shell-based load-secrets tool..."
	@mkdir -p home/.local/bin
	@cp tools/load-secrets-secure.sh home/.local/bin/load-secrets-secure.sh
	@cp tools/load-secrets-macos.sh home/.local/bin/load-secrets-macos.sh
	@chmod +x home/.local/bin/load-secrets-secure.sh
	@chmod +x home/.local/bin/load-secrets-macos.sh

# Install dotfiles to home directory
install-dotfiles: deploy-load-secrets
	@echo "Installing dotfiles..."
	rsync -avhc --no-perms home/ ~/

# Install Homebrew if not present
install-brew:
	@echo "Checking for Homebrew installation..."
	@if [ -d /opt/homebrew/bin ]; then \
		export PATH=$$PATH:/opt/homebrew/bin; \
	fi
	@if ! command -v brew 2>&1 >/dev/null; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi

# Check for differences between source and destination
check:
	@echo "Checking for differences between source and destination files..."
	@echo "Source: $(PWD)/home/"
	@echo "Target: $(HOME)/"
	@echo "----------------------------------------"
	@if rsync -avhc --no-perms --dry-run home/ ~/ | grep -q "^\."; then \
		echo "Found differences:"; \
		rsync -avhc --no-perms --dry-run home/ ~/ | grep -v "^sending" | while read -r line; do \
			if [[ $$line == *"->"* ]]; then \
				echo "$$line"; \
			elif [[ $$line == *"deleting"* ]]; then \
				echo "$$line (will be removed from target)"; \
			elif [[ $$line == *"created directory"* ]]; then \
				echo "$$line (will be created in target)"; \
			else \
				echo "$$line (will be updated in target)"; \
			fi; \
		done; \
	else \
		echo "No differences found. All files are in sync."; \
	fi

# Check for extra files in target that don't exist in source
check-extra:
	@echo "Checking for extra files in target directory..."
	@echo "Source: $(PWD)/home/"
	@echo "Target: $(HOME)/"
	@echo "----------------------------------------"
	@if rsync -avhc --no-perms --dry-run --delete ~/ home/ | grep -q "^\."; then \
		echo "Found extra files in target:"; \
		rsync -avhc --no-perms --dry-run --delete ~/ home/ | grep -v "^sending" | while read -r line; do \
			if [[ $$line == *"deleting"* ]]; then \
				echo "$$line (exists in target but not in source)"; \
			fi; \
		done; \
	else \
		echo "No extra files found in target directory."; \
	fi

# Clean up any temporary files and build artifacts
clean:
	@echo "Cleaning up..."
	@rm -f home/.local/bin/load-secrets-secure.sh
	@rm -f home/.local/bin/load-secrets-macos.sh

# Force installation without confirmation
force: install-dotfiles install-brew

# Help target
help:
	@echo "Available targets:"
	@echo "  all            - Install dotfiles and Homebrew (default)"
	@echo "  install-dotfiles - Install dotfiles to home directory"
	@echo "  install-brew   - Install Homebrew if not present"
	@echo "  check          - Check for differences between source and destination files"
	@echo "  check-extra    - Check for extra files in target that don't exist in source"
	@echo "  clean          - Clean up temporary files"
	@echo "  force          - Force installation without confirmation"
	@echo "  deploy-load-secrets - Deploy the shell-based load-secrets tool" 
