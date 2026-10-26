#!/usr/bin/env bash
# Command Line Tools ship the Swift Testing macro plugin but SwiftPM does not find it
# when the package sets a platform; point the compiler at it directly.
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing"
exec swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
