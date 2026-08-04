#!/bin/bash
export LD_LIBRARY_PATH="/opt/bambu-studio/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Bambu Studio mis-parses floats under a comma-decimal LC_NUMERIC and crashes on
# locales it doesn't ship. C.UTF-8 avoids both without dropping to ASCII the way
# a bare LC_ALL=C would; it is built into glibc, so no locale-gen is needed.
export LC_ALL=C.UTF-8
exec /opt/bambu-studio/bin/bambu-studio "$@"
