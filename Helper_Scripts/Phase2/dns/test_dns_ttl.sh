#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
expected_ip=${1:-${EXPECTED_DNS_IP:-$EDGE_IP}}
printf '%s\n' "$expected_ip" | awk -F. 'NF != 4 {exit 1} {for (i=1;i<=4;i++) if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1}' || { echo 'Usage: test_dns_ttl.sh [EXPECTED_IPV4]' >&2; exit 2; }
status=0
for name in "$APP_HOST" "$API_HOST"; do
  printf '\n%s — direct resolver answers and TTL (expected <= %ss, expected IP %s)\n' "$name" "$DNS_TTL" "$expected_ip"
  for dns in "$PRIMARY_DNS" "$BACKUP_DNS"; do
    echo "@$dns"
    answer=$(dig +time=2 +tries=1 +noall +answer +ttlid @"$dns" "$name" A) || { status=1; continue; }
    printf '%s\n' "${answer:-NO ANSWER}"
    record_count=$(printf '%s\n' "$answer" | awk '$4 == "A" {n++} END {print n+0}')
    ttl=$(printf '%s\n' "$answer" | awk '$4 == "A" {print $2; exit}')
    ip=$(printf '%s\n' "$answer" | awk '$4 == "A" {print $5; exit}')
    if [[ "$record_count" != 1 || -z "$ttl" || ! "$ttl" =~ ^[0-9]+$ || "$ttl" -gt "$DNS_TTL" || "$ip" != "$expected_ip" ]]; then
      echo "FAIL: expected an A record for $expected_ip with TTL from 0 through $DNS_TTL" >&2
      status=1
    fi
  done
done
need dscacheutil
printf '\nSystem resolver answers (may be cached; TTL is not exposed here):\n'
for name in "$APP_HOST" "$API_HOST"; do dscacheutil -q host -a name "$name"; done
echo 'Compare direct @server TTLs with system resolver addresses before/after a change; system caches expire independently.'
exit "$status"
