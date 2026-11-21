#!/bin/sh
# JavaFX renders in software (the container has no GPU) and extracts its native libraries
# into the XDG cache instead of ~/.openjfx. Options passed by the user come last and win.
JAVA_TOOL_OPTIONS="-Dprism.order=sw -Djavafx.cachedir=${XDG_CACHE_HOME:-/config/xdg/cache}/openjfx${JAVA_TOOL_OPTIONS:+ ${JAVA_TOOL_OPTIONS}}"
export JAVA_TOOL_OPTIONS

# All Bisq data lives here: wallet, DAO state, logs and the configuration file bisq.properties.
exec /opt/bisq/bin/Bisq --appDataDir=/config/bisq
