# Angelsen's Arch Repository

Custom Arch Linux packages with `ap` package manager.

## Quick Setup

```bash
curl -fsSL https://angelsen.github.io/arch-repo/setup.sh | bash
```

## Usage

### For Users (ap)

```bash
ap list                   # List available packages
ap search chrome          # Search for packages
ap install google-chrome-stable-angelsen  # Install a package
ap update                 # Update ap itself
ap help                   # Show help
```

### For Maintainers (ap-dev)

```bash
ap-dev new <package>      # Create new package from template
ap-dev test [package]     # Build package locally
ap-dev list               # List all packages with versions
ap-dev check              # Validate all PKGBUILDs
ap-dev update             # Regenerate packages.json from PKGBUILDs
ap-dev publish            # Update packages.json, commit and push
ap-dev clean              # Remove all build artifacts
```

## Available Packages

See [packages.json](packages.json) or visit https://angelsen.github.io/arch-repo/

Current packages are automatically listed on the website and updated when new packages are added.

## Development

### Adding a New Package

```bash
# Create package template
./ap-dev new my-package-name

# Edit the PKGBUILD
cd pkgbuilds/my-package-name
vim PKGBUILD

# Test build locally
ap-dev test

# Publish to repository
ap-dev publish
```

### Repository Structure

```
arch-repo/
├── ap                    # User package manager (bash)
├── ap-dev               # Developer tool (python)
├── setup.sh             # Installation script
├── packages.json        # Auto-generated package list
├── index.html           # GitHub Pages website
├── .gitignore           # Ignores build artifacts
└── pkgbuilds/           # Package sources
    └── package-name/
        ├── PKGBUILD
        └── (source files)
```

## Manual Installation

```bash
git clone https://github.com/angelsen/arch-repo.git
cd arch-repo/pkgbuilds/google-chrome-stable-angelsen
makepkg -si
```

## How It Works

The `ap` tool downloads PKGBUILDs and source files from this repository, then builds and installs packages locally using makepkg.
