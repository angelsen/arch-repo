# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a custom Arch Linux package repository that provides a lightweight AUR-like system for distributing packages via GitHub Pages. The repository consists of two main tools: `ap` (user package manager) and `ap-dev` (maintainer tool).

## Common Development Commands

### Package Management (ap-dev)
```bash
# Create new package from template
./ap-dev new <package-name>

# Build package locally for testing
./ap-dev test [package-name]  # In package dir or specify name

# Validate all PKGBUILDs
./ap-dev check

# Update packages.json from all PKGBUILDs
./ap-dev update

# Publish changes (update, commit, push)
./ap-dev publish

# Clean build artifacts
./ap-dev clean

# List all packages with versions
./ap-dev list
```

### Testing Package Installation (ap)
```bash
# Install a package locally
./ap install <package-name>

# Search for packages
./ap search <query>

# List available packages
./ap list
```

## Architecture

### Repository Structure
- **ap**: Bash script that downloads PKGBUILDs from GitHub Pages and builds packages locally using makepkg
- **ap-dev**: Python script for maintainers to manage packages, validate PKGBUILDs, and publish updates
- **pkgbuilds/**: Contains individual package directories with PKGBUILD files and source files
- **packages.json**: Auto-generated manifest of all available packages (used by website and ap tool)
- **index.html**: GitHub Pages website that displays available packages

### Package Distribution Flow
1. Maintainer creates/updates package in `pkgbuilds/<package-name>/`
2. `ap-dev publish` updates packages.json and pushes to GitHub
3. GitHub Pages serves the repository at https://angelsen.github.io/arch-repo/
4. Users install packages via `ap install` which:
   - Downloads PKGBUILD and source files from GitHub Pages
   - Builds package locally with makepkg
   - Installs with pacman

### Key Design Principles
- Packages are built locally on the user's machine using makepkg
- The repository is entirely static, served via GitHub Pages
- Package metadata is extracted directly from PKGBUILDs
- The `ap` tool requires no local repository clone - works entirely via HTTPS

### PKGBUILD Validation
The `ap-dev` tool validates PKGBUILDs by sourcing them in bash and extracting variables. Required fields:
- pkgname
- pkgver
- pkgrel
- pkgdesc

### Adding New Packages
When creating a new package:
1. Use `ap-dev new <name>` to create from template
2. Edit the PKGBUILD following Arch packaging standards
3. Place any local source files in the package directory
4. Test with `ap-dev test` before publishing
5. The `ap` tool will download both PKGBUILD and local source files when installing