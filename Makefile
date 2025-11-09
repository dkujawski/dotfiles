.PHONY: all install-dotfiles clean check check-extra install-packages force help

SHELL := /bin/bash

# Default target
all: install-dotfiles

# Install dotfiles to home directory
install-dotfiles:
	@echo "Installing dotfiles..."
	rsync -avhc --no-perms home/ ~/
	@mkdir -p ~/.local/bin

install-packages:
	@echo "Installing Ubuntu packages..."
	@bash os/ubuntu/apt.sh

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

# Force installation without confirmation
force: install-dotfiles

# Help target
help:
	@echo "Available targets:"
	@echo "  all              - Install dotfiles (default)"
	@echo "  install-dotfiles - Install dotfiles to home directory"
	@echo "  install-packages - Install Ubuntu packages defined in os/ubuntu"
	@echo "  check            - Check for differences between source and destination files"
	@echo "  check-extra      - Check for extra files in target that don't exist in source"
	@echo "  clean            - Clean up temporary files"
	@echo "  force            - Force installation without confirmation"
