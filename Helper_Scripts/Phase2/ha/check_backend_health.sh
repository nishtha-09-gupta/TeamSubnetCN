#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need curl
status=0
for spec in "$BACKEND_A_IP $BACKEND_A_PORT A" "$BACKEND_B_IP $BACKEND_B_PORT B"; do set -- $spec; echo "Backend $3 ($1:$2)"; if curl -fsS --connect-timeout 3 --max-time 5 "http://$1:$2/api/status"; then echo; else echo 'UNAVAILABLE'; status=1; fi; done
exit "$status"
