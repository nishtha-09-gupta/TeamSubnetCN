#!/bin/bash
set -u
umask 077
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
record_ip() { awk -F/ -v host="$2" '$1 == "address=" && $2 == host {print $3}' "$1"; }
[[ "$EUID" == 0 ]] || { echo "Run with sudo: sudo $0 /path/to/dnsmasq.conf" >&2; exit 2; }
command -v dig >/dev/null 2>&1 || { echo 'FAIL: missing dependency: dig' >&2; exit 2; }
[[ -x "$DNSMASQ_BIN" ]] || { echo "FAIL: dnsmasq binary is not executable: $DNSMASQ_BIN (set DNSMASQ_BIN if Homebrew uses another prefix)" >&2; exit 2; }
[[ "$#" == 1 ]] || { echo "Usage: sudo $0 /path/to/dnsmasq.conf" >&2; exit 2; }
conf=$1
backup="${conf}.phase2-original"
[[ -f "$backup" && -f "$conf" && -w "$conf" ]] || { echo "FAIL: original backup or active config missing/not writable ($backup)" >&2; exit 1; }
[[ "$(record_ip "$backup" "$APP_HOST")" == "$EDGE_IP" && "$(record_ip "$backup" "$API_HOST")" == "$EDGE_IP" ]] || { echo "FAIL: saved original does not match Phase 2 baseline $EDGE_IP; active config was not changed." >&2; exit 1; }
"$DNSMASQ_BIN" --test --conf-file="$backup" || { echo 'FAIL: saved original dnsmasq config did not validate.' >&2; exit 1; }
echo 'Current local answers (informational; an unavailable resolver does not prevent restoring its config):'
for name in "$APP_HOST" "$API_HOST"; do
  if ! dig +time=2 +tries=1 +noall +answer +ttlid @127.0.0.1 "$name" A; then
    echo "NOTICE: could not query $name on localhost; continuing with validated saved config."
  fi
done
candidate=$(mktemp "${conf}.phase2-restore.XXXXXX") || exit 1
trap 'rm -f "$candidate"' EXIT
cp "$backup" "$candidate" || exit 1
"$DNSMASQ_BIN" --test --conf-file="$candidate" || { echo 'FAIL: restore candidate did not validate; active file was not changed.' >&2; exit 1; }
mode=$(stat -f '%Lp' "$conf") || exit 1
owner=$(stat -f '%u' "$conf") || exit 1
group=$(stat -f '%g' "$conf") || exit 1
printf 'Restore both host records and all config settings from %s? [type YES] ' "$backup"
read -r answer
[[ "$answer" == YES ]] || { echo 'No change applied.'; exit 1; }
chown "$owner:$group" "$candidate" && chmod "$mode" "$candidate" || { echo 'FAIL: could not preserve active file ownership and mode; active file was not changed.' >&2; exit 1; }
mv -f "$candidate" "$conf" || { echo 'FAIL: atomic restore failed; active file was not partially written.' >&2; exit 1; }
echo 'Saved configuration atomically restored with original active-file owner and mode.'
echo 'Restart this resolver manually, then verify both names on both DNS servers with rollback_edge_migration.sh verify.'
