#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
for name in "$APP_HOST" "$API_HOST"; do echo "Primary DNS $PRIMARY_DNS: $name"; dig +time=2 +tries=1 @"$PRIMARY_DNS" "$name" A; done
