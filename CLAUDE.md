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

# Update checksums in PKGBUILD (after version change)
./ap-dev updpkgsums <package-name>

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
- .SRCINFO files are auto-generated for AUR compatibility
- Code quality maintained with Makefile (format/lint)

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
4. Update checksums with `ap-dev updpkgsums <name>`
5. Validate with `ap-dev check`
6. Test build with `ap-dev test <name>`
7. Run `namcap` on both the PKGBUILD and the built `.pkg.tar.zst` to catch issues
8. The `ap` tool will download both PKGBUILD and local source files when installing

### Package Quality Checks (namcap)

Always run `namcap` after building a package to verify correctness:

```bash
# Check the PKGBUILD
namcap pkgbuilds/<package-name>/PKGBUILD

# Check the built package
namcap pkgbuilds/<package-name>/<package-name>-<ver>-<rel>-<arch>.pkg.tar.zst
```

namcap catches: missing/redundant dependencies, bad file ownership, incorrect permissions, missing license files, non-FHS paths, and security issues (RELRO/PIE).

For npm-based packages, these namcap warnings are expected and acceptable:
- RELRO/PIE/unstripped on upstream prebuilt binaries (we don't compile these)
- Implicitly satisfied deps (glibc, bash, libgcc) — transitive, no need to list
- Cross-directory hardlinks from npm (e.g. esbuild)

### npm CLI Package Pattern

For packaging npm CLI tools, follow the established pattern in existing packages (e.g. `quicktype-angelsen`, `orval-angelsen`):

- Use `_npmname` for scoped packages (e.g. `@forge/cli`), `_pkgname` for the tarball name
- Source from `https://registry.npmjs.org/${_npmname}/-/${_pkgname}-${pkgver}.tgz` with `noextract`
- Set `arch=('x86_64')` if the package includes native addons/prebuilts, `'any'` if pure JS
- Use `ldd` on `.node` files to identify native library deps (e.g. `libsecret` for keytar)
- Clean up: remove non-linux-x64 prebuilds, fix ownership, scrub `$pkgdir`/`$srcdir` refs from package.json
- Ensure license files are installed to `/usr/share/licenses/${pkgname}/`
