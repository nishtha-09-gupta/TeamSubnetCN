#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
usage() {
  cat >&2 <<USAGE
Usage:
  $0 restore primary|backup DNSMASQ_CONFIG   # run on that DNS Mac; restores local file only
  $0 verify                                  # after both DNS services were restarted
USAGE
  exit 2
}
[[ "$#" -ge 1 ]] || usage
case "$1" in
  restore)
    [[ "$#" == 3 ]] || usage
    resolver=$2
    case "$resolver" in primary|backup) ;; *) usage ;; esac
    need sudo
    need ifconfig
    if [[ "$resolver" == primary ]]; then expected_resolver_ip=$PRIMARY_DNS; else expected_resolver_ip=$BACKUP_DNS; fi
    if ! ifconfig | awk '/inet / {print $2}' | grep -Fxq "$expected_resolver_ip"; then
      echo "FAIL: this Mac does not have the $resolver resolver address $expected_resolver_ip; no file was changed." >&2
      exit 1
    fi
    shift 2
    echo "Restoring the $resolver resolver locally; the other resolver is untouched."
    sudo "$HERE/../dns/restore_dns_record.sh" "$1" || { echo 'FAIL: local restore did not complete.' >&2; exit 1; }
    echo 'Local config restored. Restart this resolver manually, restore/restart the other DNS host, then run rollback_edge_migration.sh verify.'
    ;;
  verify)
    [[ "$#" == 1 ]] || usage
    need dig
    status=0
    for dns in "$PRIMARY_DNS" "$BACKUP_DNS"; do
      for host in "$APP_HOST" "$API_HOST"; do
        result=$(dig +time=2 +tries=1 +noall +answer +ttlid @"$dns" "$host" A) || { echo "FAIL: $dns query failed for $host"; status=1; continue; }
        printf '%s via %s: %s\n' "$host" "$dns" "${result:-NO ANSWER}"
        ips=$(printf '%s\n' "$result" | awk '$4 == "A" {print $5}')
        [[ "$ips" == "$EDGE_IP" ]] || { echo "FAIL: expected restored Phase 2 edge $EDGE_IP from $dns for $host"; status=1; }
      done
    done
    if (( status == 0 )); then echo 'Rollback verified: both names on both resolvers return the original Phase 2 edge.'; else echo 'Rollback is partial or unverified. Restore/restart unavailable or stale resolver(s), then rerun verify.' >&2; exit 1; fi
    ;;
  *) usage ;;
esac
