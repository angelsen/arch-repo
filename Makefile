.PHONY: all format lint check format-python format-shell format-web lint-python lint-shell lint-json clean help

# find(1) prefix that skips makepkg's pkg/ and src/ working directories. Use as
# `find pkgbuilds $(BUILD_DIRS) -o <real predicates>` -- the -prune returns true
# for those dirs so the -o branch never runs on anything inside them.
BUILD_DIRS := \( -name pkg -o -name src \) -prune

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
# Prune makepkg's working dirs. They hold extracted upstream trees -- Kiro alone
# vendors a pile of VS Code extension scripts -- which are not ours to rewrite.
	@find pkgbuilds $(BUILD_DIRS) -o -type f \
		\( -name "PKGBUILD" -o -name "*.install" -o -name "*.sh" \) \
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
	@shellcheck ap setup.sh
	@echo "→ Checking PKGBUILDs with namcap..."
	@echo "  Note: 'Too many sha256sums' warnings are expected for dynamic sources"
# namcap keeps its '|| true': whole categories of its warnings are expected here
# (RELRO/PIE on upstream prebuilts, ELF outside opt/, unused shared libs), so
# failing on them would leave lint permanently red. See CLAUDE.md.
	@find pkgbuilds $(BUILD_DIRS) -o -type f -name "PKGBUILD" -exec namcap {} \; || true
# '-exec ... +' rather than '\;' is load-bearing, not a batching tweak: with '\;'
# find returns 0 no matter how the command exited, so shellcheck failures would
# be silently discarded and this lint could never fail.
	@find pkgbuilds $(BUILD_DIRS) -o -type f -name "*.install" -exec shellcheck {} +
	@find pkgbuilds $(BUILD_DIRS) -o -type f -name "*.sh" -exec shellcheck {} +

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