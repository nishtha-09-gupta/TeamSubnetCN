#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
need curl
[[ "$#" -eq 2 ]] || { echo "Usage: $0 DNSMASQ_CONFIG STANDBY_EDGE_IPV4" >&2; exit 2; }
standby_ip=$2
[[ "$standby_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "FAIL: standby IP must be supplied explicitly; deployment role/IP is unconfirmed" >&2; exit 2; }
"$HERE/dns/test_dns_ttl.sh"
echo "Controlled migration: change only app record in $1 to $2 using dns/change_dns_record.sh, on BOTH DNS servers; then verify DNS and endpoint:"
printf 'After change, direct DNS answers: '; dig +short @"$PRIMARY_DNS" "$APP_HOST"; dig +short @"$BACKUP_DNS" "$APP_HOST"
printf 'Standby HTTPS by IP with hostname/SNI: '; curl -sS --connect-timeout 3 --max-time 8 --resolve "$APP_HOST:443:$standby_ip" -o /dev/null -w 'HTTP %{http_code}; peer=%{remote_ip}\n' "https://$APP_HOST/api/status" || true
echo 'Existing resolver caches may continue using old edge until TTL expires. This utility does not edit DNS.'
