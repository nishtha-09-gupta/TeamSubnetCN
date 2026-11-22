#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
status=0
for name in "$APP_HOST" "$API_HOST"; do
  echo "Primary DNS $PRIMARY_DNS: $name"
  answer=$(dig +time=2 +tries=1 +short @"$PRIMARY_DNS" "$name" A) || { echo 'FAIL: DNS query failed'; status=1; continue; }
  printf '%s\n' "$answer"
  if [[ "$answer" != "$EDGE_IP" ]]; then echo "FAIL: expected only $EDGE_IP"; status=1; fi
done
exit "$status"
