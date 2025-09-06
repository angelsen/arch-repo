# Angelsen's Arch Repository

Custom Arch Linux packages built from source using `ap` (Angelsen's Package manager).

## Quick Setup

```bash
curl -fsSL https://angelsen.github.io/arch-repo/setup.sh | bash
```

## Usage

```bash
ap list                   # List available packages
ap search chrome          # Search for packages  
ap install google-chrome-stable-angelsen  # Install a package
ap update                 # Update ap itself
```

## Available Packages

- **google-chrome-stable-angelsen** - Google Chrome (Stable) with debug wrapper

## Structure

```
arch-repo/
├── ap                    # Package manager tool
├── setup.sh             # Installation script
├── packages.json        # Package metadata
├── index.html           # GitHub Pages site
└── pkgbuilds/           # Package build scripts
    └── google-chrome-stable-angelsen/
        ├── PKGBUILD
        └── (source files)
```

## Manual Installation

```bash
git clone https://github.com/angelsen/arch-repo.git
cd arch-repo/pkgbuilds/google-chrome-stable-angelsen
makepkg -si
```

## Adding to Your System

The `ap` tool is a lightweight AUR-like helper that:
- Downloads PKGBUILDs from this repository
- Fetches required source files
- Builds and installs packages using makepkg
- Self-updates when needed

No binary hosting required - everything builds from source!