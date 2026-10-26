#!/usr/bin/env bash
# Debug builds only: sends a command to the running app, e.g. `scripts/drive.sh tab calendar`.
set -euo pipefail
swift -e 'import Foundation; DistributedNotificationCenter.default().postNotificationName(Notification.Name("com.fillx.zenotch.debug"), object: CommandLine.arguments.dropFirst().joined(separator: " "), userInfo: nil, deliverImmediately: true)' -- "$@" 2>/dev/null \
  || { cat > /tmp/zenotch-drive.swift <<'SWIFT'
import Foundation
DistributedNotificationCenter.default().postNotificationName(Notification.Name("com.fillx.zenotch.debug"), object: CommandLine.arguments.dropFirst().joined(separator: " "), userInfo: nil, deliverImmediately: true)
SWIFT
swift /tmp/zenotch-drive.swift "$@"; }
