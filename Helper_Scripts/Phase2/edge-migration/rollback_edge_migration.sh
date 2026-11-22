#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
[[ "$#" -eq 1 ]] || { echo "Usage: $0 DNSMASQ_CONFIG" >&2; exit 2; }
"$HERE/dns/restore_dns_record.sh" "$1"
echo "Restore the matching backup DNS config too, restart both DNS services, then inspect answers with $HERE/dns/test_dns_ttl.sh."
