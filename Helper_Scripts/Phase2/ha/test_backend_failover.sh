#!/bin/bash
set -u
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need curl
url=${1:-https://$APP_HOST/api/status}; count=${COUNT:-10}
echo 'Initial direct backend health:'; "$HERE/check_backend_health.sh" || echo 'At least one backend is unavailable.'
echo "Requests to $url (backend headers included). Stop/restart backend manually on its Mac; this script will not stop a process."
for ((i=1;i<=count;i++)); do printf '%02d ' "$i"; curl -skS --connect-timeout 3 --max-time 20 -D - "$url" -o /dev/null | awk 'BEGIN{IGNORECASE=1} /^HTTP\// || /^X-Backend:/ || /^X-Edge:/ {gsub("\r",""); print}'; done
