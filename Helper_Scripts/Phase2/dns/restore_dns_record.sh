#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
[ "$#" -eq 1 ] || { echo "Usage: $0 /path/to/dnsmasq.conf" >&2; exit 2; }
conf=$1; backup="${conf}.phase2-original"
[[ -f "$backup" && -w "$conf" ]] || { echo "FAIL: original backup or writable config missing ($backup)" >&2; exit 1; }
printf 'Restore %s from %s? [type YES] ' "$conf" "$backup"; read -r answer
[[ "$answer" == YES ]] || { echo 'No change applied.'; exit 1; }
cp -p "$backup" "$conf" || exit 1
echo 'Restored. Validate then restart dnsmasq manually: sudo dnsmasq --test --conf-file=PATH; sudo brew services restart dnsmasq'
