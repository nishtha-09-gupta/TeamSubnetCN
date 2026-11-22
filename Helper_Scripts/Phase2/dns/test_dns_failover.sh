#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
need scutil
printf 'Direct query primary (%s): ' "$PRIMARY_DNS"; dig +time=2 +tries=1 +short @"$PRIMARY_DNS" "$APP_HOST" || true
printf 'Direct query backup (%s): ' "$BACKUP_DNS"; dig +time=2 +tries=1 +short @"$BACKUP_DNS" "$APP_HOST" || exit 1
printf '
macOS resolver view (may be cached or use another resolver):
'; scutil --dns | sed -n '1,100p'
printf '
System resolver query (may return cache):
'; dscacheutil -q host -a name "$APP_HOST"
echo 'For failover evidence: first confirm the direct backup query succeeds; stop primary dnsmasq manually on its Mac; then rerun this script. This script never stops a service.'
