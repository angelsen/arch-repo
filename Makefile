.PHONY: all format lint check format-python format-shell format-web lint-python lint-shell lint-json clean help

# Default target
all: format lint

# Help target
help:
	@echo "arch-repo Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make format    - Format all code"
	@echo "  make lint      - Lint all code"
	@echo "  make check     - Format and lint (same as 'make')"
	@echo "  make clean     - Remove backup files"
	@echo "  make help      - Show this help"

# Combined check
check: format lint

# Format everything
format: format-python format-shell format-web
	@echo "✓ Formatting complete"

# Lint everything
lint: lint-python lint-shell lint-json
	@echo "✓ Linting complete"

# Python formatting
format-python:
	@echo "→ Formatting Python..."
	@ruff format ap-dev --quiet

# Shell script formatting
format-shell:
	@echo "→ Formatting shell scripts..."
	@shfmt -w -i 4 -bn -ci ap setup.sh
	@find pkgbuilds -type f \( -name "PKGBUILD" -o -name "*.install" -o -name "*.sh" \) \
		-exec shfmt -w -i 4 -bn -ci {} \;

# Web files formatting (HTML, JSON, Markdown)
format-web:
	@echo "→ Formatting web files..."
	@prettier --write --log-level error "*.html" "*.json" "*.md" "**/*.md"

# Python linting
lint-python:
	@echo "→ Linting Python..."
	@ruff check ap-dev

# Shell script linting
lint-shell:
	@echo "→ Linting shell scripts..."
	@shellcheck ap setup.sh || true
	@echo "→ Checking PKGBUILDs with namcap..."
	@echo "  Note: 'Too many sha256sums' warnings are expected for dynamic sources"
	@find pkgbuilds -type f -name "PKGBUILD" -exec namcap {} \; || true
	@find pkgbuilds -type f -name "*.install" -exec shellcheck {} \; || true
	@find pkgbuilds -type f -name "*.sh" -exec shellcheck {} \; || true

# JSON validation
lint-json:
	@echo "→ Validating JSON..."
	@jq . packages.json > /dev/null
	@echo "  ✓ packages.json is valid"

# Clean backup files
clean:
	@echo "→ Cleaning backup files..."
	@find . -name "*.bak" -delete
	@find . -name "*~" -delete
	@echo "✓ Cleaned"