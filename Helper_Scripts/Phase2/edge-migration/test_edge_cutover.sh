#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
need curl
need dscacheutil
need ifconfig
[[ "$#" -le 1 ]] || { echo "Usage: $0 [STANDBY_EDGE_IPV4]" >&2; exit 2; }
standby_ip=${1:-$STANDBY_EDGE_IP}
[[ -n "$standby_ip" ]] || { echo "Set STANDBY_EDGE_IP or pass a confirmed standby IPv4 address" >&2; exit 2; }
printf "%s\n" "$standby_ip" | awk -F. 'NF != 4 {exit 1} {for (i=1;i<=4;i++) if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1}' || { echo 'FAIL: supply the confirmed standby IP' >&2; exit 2; }
[[ "$standby_ip" != "$EDGE_IP" ]] || { echo 'FAIL: standby edge must differ from the original edge' >&2; exit 2; }
if ! ifconfig | awk '/inet / {print $2}' | grep -Fxq "$standby_ip"; then echo "FAIL: $standby_ip is not assigned to this Mac; run cutover verification on the standby" >&2; exit 1; fi
status=0
printf 'Direct DNS answers after controlled cutover (both resolver hosts, both names):\n'
for dns in "$PRIMARY_DNS" "$BACKUP_DNS"; do
  for host in "$APP_HOST" "$API_HOST"; do
    answer=$(dig +time=2 +tries=1 +noall +answer +ttlid @"$dns" "$host" A) || { echo "FAIL: query to $dns failed"; status=1; continue; }
    printf '%s via %s: %s\n' "$host" "$dns" "${answer:-NO ANSWER}"
    answer_ips=$(printf '%s\n' "$answer" | awk '$4 == "A" {print $5}')
    [[ "$answer_ips" == "$standby_ip" ]] || { echo "FAIL: $host via $dns should resolve only to $standby_ip"; status=1; }
  done
done
printf '\nSystem resolver answers (may still be cached at the original edge):\n'
for host in "$APP_HOST" "$API_HOST"; do dscacheutil -q host -a name "$host"; done
printf '\nStandby backend connectivity from this Mac:\n'
"$HERE/../ha/check_backend_health.sh" || { echo 'FAIL: backend connectivity from standby failed'; status=1; }
printf '\nTLS-validated HTTPS requests pinned to the standby edge:\n'
for host in "$APP_HOST" "$API_HOST"; do
  headers=$(curl -fsS --connect-timeout 3 --max-time 10 --resolve "$host:$HTTPS_PORT:$standby_ip" --cacert "$TLS_CERT" -D - -o /dev/null "https://$host:$HTTPS_PORT/api/status") || { echo "FAIL: HTTPS request failed for $host"; status=1; continue; }
  printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^HTTP\// || /^X-Backend:/ || /^X-Edge:/ {gsub("\r",""); print}'
  printf '%s\n' "$headers" | grep -qi '^X-Backend:' || { echo "FAIL: missing X-Backend for $host"; status=1; }
  printf '%s\n' "$headers" | grep -qi '^X-Edge:' || { echo "FAIL: missing X-Edge for $host"; status=1; }
done
if (( status == 0 )); then echo 'Cutover checks passed. DNS migration is controlled and explicit; this is not automatic edge failover.'; else exit 1; fi
