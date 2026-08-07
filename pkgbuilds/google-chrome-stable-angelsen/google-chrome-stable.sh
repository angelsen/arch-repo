#!/bin/bash
# Wrapper for Google Chrome that adds support for chrome-flags.conf
# This chains to Google's official wrapper which handles the environment setup

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

# Allow users to override command-line options.
# Strip comments and blank lines, then split on whitespace into an array. Note
# the split is deliberate: a config line may carry several flags, matching
# Arch's own chromium wrapper. Reading line-per-element instead (mapfile) would
# pass "--foo --bar" through as one argument and break those configs.
CHROME_USER_FLAGS=()
if [[ -f "${XDG_CONFIG_HOME}/chrome-flags.conf" ]]; then
    read -ra CHROME_USER_FLAGS < <(
        grep -Ev '^\s*#|^\s*$' "${XDG_CONFIG_HOME}/chrome-flags.conf" | tr '\n' ' '
    )
fi

# Call Google's wrapper which will set up the environment and launch Chrome
# The Google wrapper handles:
# - Setting CHROME_WRAPPER and CHROME_VERSION_EXTRA
# - XDG utilities path management
# - Crash dialog settings
# - Sanitizing stdin/stdout/stderr
# - Finally calling the actual Chrome binary
exec /opt/google/chrome/google-chrome "${CHROME_USER_FLAGS[@]}" "$@"
