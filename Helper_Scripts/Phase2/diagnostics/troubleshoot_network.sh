#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig; need nc; need curl; need openssl
fail=0
section(){ printf '
===== %s =====
' "$1"; }
section '1. DNS Resolution'
for dns in "$PRIMARY_DNS" "$BACKUP_DNS"; do echo "Resolver $dns"; dig +time=2 +tries=1 +noall +answer +ttlid @"$dns" "$APP_HOST" A || fail=1; done
resolved=$(dig +time=2 +tries=1 +short "$APP_HOST" A | head -1)
[[ -n "$resolved" ]] || { echo 'SYSTEM DNS FAILED'; fail=1; resolved=$EDGE_IP; }
echo "System resolver returned: ${resolved:-none}"
section '2. TCP Connectivity'
nc -z -G 3 "$resolved" "$HTTPS_PORT" && echo "HTTPS TCP reachable at $resolved:$HTTPS_PORT" || { echo 'HTTPS TCP CONNECTION FAILED'; fail=1; }
echo 'Backend port checks from this host (run on edge to test edge-to-backend path):'
for spec in "$BACKEND_A_IP $BACKEND_A_PORT A" "$BACKEND_B_IP $BACKEND_B_PORT B"; do set -- $spec; nc -z -G 3 "$1" "$2" && echo "Backend $3 TCP reachable" || echo "Backend $3 TCP failed/unreachable"; done
section '3. TLS / Certificate Validation'
openssl s_client -connect "$resolved:$HTTPS_PORT" -servername "$APP_HOST" -verify_hostname "$APP_HOST" -verify_return_error </dev/null 2>&1 | tail -18
section '4. HTTP / Application Layer'
curl -sS --connect-timeout 3 --max-time 15 -D - -o /tmp/teamx-phase2-body "https://$APP_HOST/api/status" || { echo 'HTTP request failed (connection/TLS/application error; see curl output above).'; fail=1; }
if [[ -f /tmp/teamx-phase2-body ]]; then cat /tmp/teamx-phase2-body; rm -f /tmp/teamx-phase2-body; fi
section '5. Backend Availability'
"$HERE/ha/check_backend_health.sh" || { echo 'One or more backend applications failed.'; fail=1; }
section '6. Final Diagnosis'
if (( fail )); then echo 'At least one layer reported a failure. Locate the first failing section above; TCP/TLS/HTTP can fail downstream of DNS.'; exit 1; else echo 'All tested layers responded. Confirm edge-to-backend checks by running from edge Mac.'; fi
