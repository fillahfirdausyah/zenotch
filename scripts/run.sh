#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-debug}" scripts/bundle.sh
pkill -x Zenotch && while pgrep -x Zenotch >/dev/null; do sleep 0.1; done || true
open build/Zenotch.app
