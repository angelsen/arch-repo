#!/bin/bash
# Wrapper for Google Chrome that adds support for chrome-flags.conf
# This chains to Google's official wrapper which handles the environment setup

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

# Allow users to override command-line options
# Read flags from chrome-flags.conf, strip comments, and join into single line
if [[ -f $XDG_CONFIG_HOME/chrome-flags.conf ]]; then
    CHROME_USER_FLAGS="$(grep -v '^#' "$XDG_CONFIG_HOME/chrome-flags.conf" | tr '\n' ' ')"
fi

# Call Google's wrapper which will set up the environment and launch Chrome
# The Google wrapper handles:
# - Setting CHROME_WRAPPER and CHROME_VERSION_EXTRA
# - XDG utilities path management
# - Crash dialog settings
# - Sanitizing stdin/stdout/stderr
# - Finally calling the actual Chrome binary
exec /opt/google/chrome/google-chrome $CHROME_USER_FLAGS "$@"
