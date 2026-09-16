#!/usr/bin/env bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

cd "$(dirname "$0")/.."

DEVICE_ID="${1:-00008120-000505CE1E88C01E}"

echo "Starting Chkela on device: $DEVICE_ID"
echo "Hot reload: press r  |  Hot restart: press R  |  Quit: press q"
echo ""

flutter run -d "$DEVICE_ID"
