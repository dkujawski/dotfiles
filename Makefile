.PHONY: all install-dotfiles install-brew clean check check-extra build-load-secrets build-load-secrets-go deploy-load-secrets deploy-load-secrets-go

# Default target
all: install-dotfiles install-brew 

# Install build dependencies
install-deps-rust:
	@if ! command -v cargo 2>&1 >/dev/null; then \
		/bin/bash -c "$$(curl https://sh.rustup.rs -sSf)"; \
	fi

install-deps-go:
	@if ! command -v go 2>&1 >/dev/null; then \
		echo "Go is not installed. Please install Go 1.21 or later."; \
		exit 1; \
	fi

# Build the Rust version of load-secrets tool (default)
build-load-secrets: install-deps-rust
	@echo "Building load-secrets tool..."
	@cd tools/load-secrets && cargo build --release

# Build the Go version of load-secrets tool (alternative)
build-load-secrets-go: install-deps-go
	@echo "Building Go version of load-secrets tool..."
	@cd tools/load-secrets-go && go mod download && go build -o load-secrets-go

# Deploy the Rust version of load-secrets tool (default)
deploy-load-secrets: build-load-secrets
	@echo "Deploying load-secrets tool..."
	@mkdir -p home/.local/bin
	@cp tools/load-secrets/target/release/load-secrets home/.local/bin/load-secrets
	@chmod +x home/.local/bin/load-secrets

# Deploy the Go version of load-secrets tool (alternative)
deploy-load-secrets-go: build-load-secrets-go
	@echo "Deploying Go version of load-secrets tool..."
	@mkdir -p home/.local/bin
	@cp tools/load-secrets-go/load-secrets-go home/.local/bin/load-secrets-go
	@cp tools/load-secrets-go/config.yaml home/.local/bin/
	@chmod +x home/.local/bin/load-secrets-go

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
	@rm -f tools/load-secrets-go/load-secrets-go
	@rm -f home/.local/bin/load-secrets-go
	@rm -f home/.local/bin/config.yaml
	@rm -f home/.local/bin/load-secrets
	@cd tools/load-secrets && cargo clean

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
	@echo "  build-load-secrets - Build the load-secrets tool (Rust version)"
	@echo "  build-load-secrets-go - Build the Go version of load-secrets tool"
	@echo "  deploy-load-secrets - Deploy the load-secrets tool (Rust version)"
	@echo "  deploy-load-secrets-go - Deploy the Go version of load-secrets tool" 
