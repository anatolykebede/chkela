#!/usr/bin/env bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

cd "$(dirname "$0")/.."
DEVICE_ID="${1:-00008120-000505CE1E88C01E}"

(
  sleep 6
  printf '%s\n' '{"id":1,"command":"reload"}'
  sleep 2
  printf '%s\n' '{"id":2,"command":"detach"}'
) | flutter attach --machine -d "$DEVICE_ID"
