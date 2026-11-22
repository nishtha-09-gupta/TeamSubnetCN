#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need curl
status=0
for spec in "$BACKEND_A_IP $BACKEND_A_PORT A" "$BACKEND_B_IP $BACKEND_B_PORT B"; do
  read -r ip port expected <<< "$spec"
  printf 'Backend %s (%s:%s): ' "$expected" "$ip" "$port"
  if response=$(curl -sS --connect-timeout 3 --max-time 5 -D - -w '\nHTTP_STATUS:%{http_code}' "http://$ip:$port/api/status" 2>&1); then
    code=$(printf '%s\n' "$response" | sed -n 's/^HTTP_STATUS://p' | tail -1)
    backend=$(printf '%s\n' "$response" | awk 'BEGIN{IGNORECASE=1} /^X-Backend:/ {gsub("\r",""); sub(/^[^:]*:[[:space:]]*/,""); print; exit}')
    body=$(printf '%s\n' "$response" | awk 'found {print} /^\r?$/ {found=1}')
    if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
      printf 'HTTP ERROR (status %s)\n' "${code:-missing}"
      status=1
    elif [[ "$backend" != "$expected" ]] || ! printf '%s\n' "$body" | grep -Eq '"backend"[[:space:]]*:[[:space:]]*"'"$expected"'"'; then
      printf 'IDENTITY ERROR (X-Backend=%s, expected %s)\n' "${backend:-missing}" "$expected"
      status=1
    else
      printf 'HEALTHY (HTTP %s, X-Backend=%s)\n' "$code" "$backend"
    fi
  else
    printf 'CONNECTION ERROR (%s)\n' "$response"
    status=1
  fi
done
exit "$status"
