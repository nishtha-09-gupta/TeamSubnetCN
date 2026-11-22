#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
need scutil
need dscacheutil
mode=${1:-before}
[[ "$mode" == before || "$mode" == after-primary-stop ]] || { echo "Usage: $0 [before|after-primary-stop]" >&2; exit 2; }
status=0
for name in "$APP_HOST" "$API_HOST"; do
  printf '\n%s\n' "$name"
  for label_ip in "primary $PRIMARY_DNS" "backup $BACKUP_DNS"; do
    set -- $label_ip
    label=$1
    server=$2
    response=$(dig +time=2 +tries=1 @"$server" "$name" A 2>&1)
    answer=$(printf '%s\n' "$response" | awk '$4 == "A" {print $5}')
    if [[ "$mode" == after-primary-stop && "$label" == primary ]]; then
      if printf '%s\n' "$response" | grep -Eiq 'timed out|no servers could be reached|connection refused|network is unreachable'; then
        printf 'Primary DNS (%s): unreachable as expected after manual stop\n' "$server"
      else
        printf 'FAIL: primary DNS (%s) still responded; this is not a primary-service outage\n' "$server"
        status=1
      fi
      continue
    fi
    if [[ -n "$answer" ]]; then
      printf '%s DNS (%s): %s\n' "$label" "$server" "$answer"
      if [[ "$answer" != "$EDGE_IP" ]]; then echo "FAIL: expected only $EDGE_IP"; status=1; fi
    else
      printf '%s DNS (%s): no A answer\n' "$label" "$server"
      printf '%s\n' "$response" | sed -n '/timed out/p;/no servers could be reached/p;/status:/p'
      status=1
    fi
  done
done
printf '\nmacOS resolver configuration (selection and ordering):\n'
scutil --dns | sed -n '1,100p'
printf '\nSystem resolver answers (may be cached):\n'
for name in "$APP_HOST" "$API_HOST"; do dscacheutil -q host -a name "$name"; done
if [[ "$mode" == after-primary-stop ]]; then
  echo 'Direct backup answers and system resolver behavior are separate observations; the latter may still reflect cache or macOS resolver selection.'
else
  echo 'For failover evidence, stop primary dnsmasq manually, then rerun with after-primary-stop. This script never stops a service.'
fi
exit "$status"
