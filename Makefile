.PHONY: all install-dotfiles install-brew clean check check-extra build-load-secrets deploy-load-secrets

# Default target
all: build-load-secrets deploy-load-secrets install-dotfiles install-brew 

# Install dotfiles to home directory
install-dotfiles:
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

# Build the load-secrets tool
build-load-secrets:
	@echo "Building load-secrets tool..."
	@cd tools/load-secrets && cargo build --release

# Deploy the load-secrets tool
deploy-load-secrets:
	@echo "Deploying load-secrets tool..."
	@cp tools/load-secrets/target/release/load-secrets home/.local/bin/
	@chmod +x home/.local/bin/load-secrets

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
	@echo "Cleaning Cargo build artifacts..."
	@cd tools/load-secrets && cargo clean
	@rm -f home/.local/bin/load-secrets

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
	@echo "  build-load-secrets - Build the load-secrets tool"
	@echo "  deploy-load-secrets - Deploy the load-secrets tool" 
