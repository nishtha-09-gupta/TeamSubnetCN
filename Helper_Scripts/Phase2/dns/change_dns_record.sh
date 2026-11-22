#!/bin/bash
set -u
umask 077
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
valid_ipv4() { awk -F. 'NF != 4 {exit 1} {for (i=1;i<=4;i++) if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1}' <<< "$1"; }
record_ip() { awk -F/ -v host="$2" '$1 == "address=" && $2 == host {print $3}' "$1"; }
[[ "$EUID" == 0 ]] || { echo "Run with sudo: sudo $0 /path/to/dnsmasq.conf NEW_APP_IP [NEW_API_IP]" >&2; exit 2; }
need dig
[[ -x "$DNSMASQ_BIN" ]] || { echo "FAIL: dnsmasq binary is not executable: $DNSMASQ_BIN (set DNSMASQ_BIN if Homebrew uses another prefix)" >&2; exit 2; }
[[ "$#" == 2 || "$#" == 3 ]] || { echo "Usage: sudo $0 /path/to/dnsmasq.conf NEW_APP_IP [NEW_API_IP]" >&2; exit 2; }
conf=$1
app_ip=$2
api_ip=${3:-$app_ip}
valid_ipv4 "$app_ip" || { echo 'FAIL: APP IP must be a valid IPv4 address' >&2; exit 2; }
valid_ipv4 "$api_ip" || { echo 'FAIL: API IP must be a valid IPv4 address' >&2; exit 2; }
[[ -f "$conf" ]] || { echo "FAIL: config not found: $conf" >&2; exit 2; }
[[ -w "$conf" ]] || { echo "FAIL: config is not writable even as root: $conf" >&2; exit 2; }
app_prefix="address=/$APP_HOST/"
api_prefix="address=/$API_HOST/"
[[ $(grep -c "^$app_prefix" "$conf") == 1 ]] || { echo "FAIL: expected exactly one $APP_HOST record in $conf" >&2; exit 1; }
[[ $(grep -c "^$api_prefix" "$conf") == 1 ]] || { echo "FAIL: expected exactly one $API_HOST record in $conf" >&2; exit 1; }
for name in "$APP_HOST" "$API_HOST"; do
  answer=$(dig +time=2 +tries=1 +short @127.0.0.1 "$name" A) || { echo "FAIL: local DNS query failed for $name; no change made." >&2; exit 1; }
  [[ -n "$answer" ]] || { echo "FAIL: local DNS returned no A answer for $name; no change made." >&2; exit 1; }
  dig +noall +answer +ttlid @127.0.0.1 "$name" A
done

# The original copy is immutable; create it atomically and never replace an existing backup.
backup="${conf}.phase2-original"
if [[ -e "$backup" ]]; then
  "$DNSMASQ_BIN" --test --conf-file="$backup" >/dev/null || { echo "FAIL: saved original is invalid: $backup" >&2; exit 1; }
  [[ "$(record_ip "$backup" "$APP_HOST")" == "$EDGE_IP" && "$(record_ip "$backup" "$API_HOST")" == "$EDGE_IP" ]] || { echo "FAIL: saved original does not contain the Phase 2 baseline ($EDGE_IP); no change made. Inspect $backup." >&2; exit 1; }
  echo "Using the validated original backup: $backup"
else
  [[ "$(record_ip "$conf" "$APP_HOST")" == "$EDGE_IP" && "$(record_ip "$conf" "$API_HOST")" == "$EDGE_IP" ]] || { echo "FAIL: first change must start from the Phase 2 baseline ($EDGE_IP); no backup or change made." >&2; exit 1; }
  backup_tmp=$(mktemp "${conf}.phase2-backup.XXXXXX") || exit 1
  trap 'rm -f "$backup_tmp" "${candidate:-}"' EXIT
  cp "$conf" "$backup_tmp" || exit 1
  chmod 600 "$backup_tmp" || exit 1
  "$DNSMASQ_BIN" --test --conf-file="$backup_tmp" >/dev/null || { echo 'FAIL: original backup copy did not validate.' >&2; exit 1; }
  ln "$backup_tmp" "$backup" || { echo "FAIL: backup already exists or could not be created: $backup" >&2; exit 1; }
  rm -f "$backup_tmp"
  echo "Saved original configuration with mode 600: $backup"
fi

candidate=$(mktemp "${conf}.phase2-candidate.XXXXXX") || exit 1
trap 'rm -f "${backup_tmp:-}" "$candidate"' EXIT
awk -v app="$APP_HOST" -v api="$API_HOST" -v app_ip="$app_ip" -v api_ip="$api_ip" '
  index($0, "address=/" app "/") == 1 {print "address=/" app "/" app_ip; next}
  index($0, "address=/" api "/") == 1 {print "address=/" api "/" api_ip; next}
  {print}
' "$conf" > "$candidate" || exit 1
"$DNSMASQ_BIN" --test --conf-file="$candidate" || { echo 'FAIL: candidate dnsmasq config did not validate; active file was not changed.' >&2; exit 1; }
mode=$(stat -f '%Lp' "$conf") || exit 1
owner=$(stat -f '%u' "$conf") || exit 1
group=$(stat -f '%g' "$conf") || exit 1
printf 'Change %s -> %s and %s -> %s in %s? [type YES] ' "$APP_HOST" "$app_ip" "$API_HOST" "$api_ip" "$conf"
read -r answer
[[ "$answer" == YES ]] || { echo 'No change applied.'; exit 1; }
chown "$owner:$group" "$candidate" && chmod "$mode" "$candidate" || { echo 'FAIL: could not preserve active file ownership and mode; active file was not changed.' >&2; exit 1; }
mv -f "$candidate" "$conf" || { echo 'FAIL: atomic replacement failed; active file was not partially written.' >&2; exit 1; }
echo 'Candidate validated and atomically installed with the original owner and mode.'
echo 'Restart dnsmasq manually on this resolver, then run test_dns_ttl.sh to verify both direct answers.'
echo "Expected answers after restart: $APP_HOST=$app_ip; $API_HOST=$api_ip"
echo 'Repeat on the other DNS Mac. Client caches can retain their prior answers until TTL expiry or a deliberate local flush.'
