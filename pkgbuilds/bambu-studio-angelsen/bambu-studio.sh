#!/bin/bash
export LD_LIBRARY_PATH="/opt/bambu-studio/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LC_ALL=C
exec /opt/bambu-studio/bin/bambu-studio "$@"
