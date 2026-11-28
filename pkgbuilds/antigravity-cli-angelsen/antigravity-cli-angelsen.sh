#!/bin/sh
# pacman owns the binary, so agy's self-updater is off. Only the value "true" works, not "1":
# https://github.com/google-antigravity/antigravity-cli/issues/1046
export AGY_CLI_DISABLE_AUTO_UPDATE=true
exec /opt/antigravity-cli/agy "$@"
