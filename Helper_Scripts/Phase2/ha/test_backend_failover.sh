#!/bin/bash
set -u
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need curl
url=${1:-https://$APP_HOST/api/status}
count=${COUNT:-10}
[[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo 'FAIL: COUNT must be a positive integer' >&2; exit 2; }
printf 'Initial direct backend health:\n'
"$HERE/check_backend_health.sh" || echo 'At least one backend is unavailable; observe which backend remains in the edge responses.'
printf 'Requests to %s; stop or restart a backend manually on its Mac. This script does not stop remote services.\n' "$url"
seen_a=0
seen_b=0
failures=0
http_errors=0
header_errors=0
for ((i=1;i<=count;i++)); do
  printf '%02d ' "$i"
  if headers=$(curl -sS --connect-timeout 3 --max-time 20 -D - -o /dev/null -w '\nHTTP_STATUS:%{http_code}' "$url"); then
    printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^HTTP\// || /^X-Backend:/ || /^X-Edge:/ || /^HTTP_STATUS:/ {gsub("\r",""); print}'
    backend=$(printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^X-Backend:/ {gsub("\r",""); sub(/^[^:]*:[[:space:]]*/,""); print; exit}')
    status=$(printf '%s\n' "$headers" | sed -n 's/^HTTP_STATUS://p' | tail -1)
    [[ "$status" =~ ^2[0-9][0-9]$ ]] || { echo "HTTP ERROR: status ${status:-missing}; backend response is not healthy"; failures=$((failures+1)); http_errors=$((http_errors+1)); }
    case "$backend" in A) seen_a=$((seen_a+1));; B) seen_b=$((seen_b+1));; *) echo 'HEADER ERROR: missing or invalid X-Backend (expected A or B)'; failures=$((failures+1)); header_errors=$((header_errors+1));; esac
    edge=$(printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^X-Edge:/ {gsub("\r",""); sub(/^[^:]*:[[:space:]]*/,""); print; exit}')
    [[ -n "$edge" ]] || { echo 'HEADER ERROR: missing X-Edge'; failures=$((failures+1)); header_errors=$((header_errors+1)); }
  else
    echo 'REQUEST FAILED'
    failures=$((failures+1))
  fi
done
printf 'Observed backend responses: A=%s B=%s; failed requests=%s (HTTP errors=%s, header errors=%s)\n' "$seen_a" "$seen_b" "$failures" "$http_errors" "$header_errors"
if (( seen_a > 0 && seen_b > 0 )); then echo 'Both backends served this run; load balancing is observable.'; fi
if (( failures > 0 )); then exit 1; fi
