#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
printf 'Flush local macOS DNS cache with dscacheutil and mDNSResponder? [type YES] '; read -r answer
[[ "$answer" == YES ]] || exit 1
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo 'macOS resolver cache flush requested.'
