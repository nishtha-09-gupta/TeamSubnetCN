#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
need dnsmasq
[ "$#" -eq 2 ] || { echo "Usage: $0 /path/to/dnsmasq.conf NEW_APP_IP" >&2; exit 2; }
conf=$1; new_ip=$2
[[ "$new_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo 'FAIL: expected IPv4 address' >&2; exit 2; }
[[ -f "$conf" && -w "$conf" ]] || { echo "FAIL: config missing/not writable: $conf" >&2; exit 2; }
backup="${conf}.phase2-original"
if [[ ! -e "$backup" ]]; then cp -p "$conf" "$backup" || exit 1; echo "Saved original: $backup"; else echo "Original already preserved: $backup"; fi
if ! grep -q "^address=/$APP_HOST/" "$conf"; then echo "FAIL: no existing $APP_HOST address record" >&2; exit 1; fi
sed "s#^address=/$APP_HOST/.*#address=/$APP_HOST/$new_ip#" "$conf" > "${conf}.phase2.tmp" || exit 1
sudo -v || exit 1
sudo dnsmasq --test --conf-file="${conf}.phase2.tmp" || { rm -f "${conf}.phase2.tmp"; exit 1; }
printf 'Change authoritative %s to %s and restart dnsmasq? [type YES] ' "$APP_HOST" "$new_ip"; read -r answer
[[ "$answer" == YES ]] || { rm -f "${conf}.phase2.tmp"; echo 'No change applied.'; exit 1; }
sudo cp "${conf}.phase2.tmp" "$conf" && rm -f "${conf}.phase2.tmp" || exit 1
echo 'Record file updated. Restart dnsmasq manually with: sudo brew services restart dnsmasq'
echo 'Repeat the same change on backup DNS config for consistent answers; recursive/client caches can retain old data until TTL expires.'
