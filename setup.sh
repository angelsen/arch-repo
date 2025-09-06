#!/bin/bash
# Setup script for ap - Angelsen's Package manager

echo "======================================"
echo "   ap - Angelsen's Package Manager   "
echo "======================================"
echo ""

# Check if already installed
if command -v ap &>/dev/null; then
    echo "✓ ap is already installed at $(which ap)"
    echo ""
    read -p "Reinstall/update? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo "Installing ap..."

# Download ap
echo "→ Downloading ap..."
if ! curl -fsL https://angelsen.github.io/arch-repo/ap -o /tmp/ap; then
    echo "Error: Failed to download ap"
    echo "The repository might not be deployed yet."
    echo "Using local file instead..."

    # Fallback to local file if available
    if [[ -f "./ap" ]]; then
        cp ./ap /tmp/ap
    else
        exit 1
    fi
fi

# Make executable
chmod +x /tmp/ap

# Install to system
echo "→ Installing to /usr/local/bin/ap (requires sudo)..."
sudo mv /tmp/ap /usr/local/bin/ap

# Verify installation
if command -v ap &>/dev/null; then
    echo ""
    echo "✓ Installation successful!"
    echo ""
    echo "Usage:"
    echo "  ap list                   # List available packages"
    echo "  ap search <query>         # Search packages"
    echo "  ap install <package>      # Install a package"
    echo "  ap update                 # Update ap itself"
    echo ""
    echo "Try: ap install google-chrome-stable-angelsen"
else
    echo "Error: Installation failed"
    exit 1
fi
