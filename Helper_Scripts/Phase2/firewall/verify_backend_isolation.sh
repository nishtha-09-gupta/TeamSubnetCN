#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need nc
[[ "$#" == 1 ]] || { echo "Usage: $0 client|edge" >&2; exit 2; }
case "$1" in client) expected=BLOCKED;; edge) expected=ALLOWED;; *) exit 2;; esac
if [[ "$1" == edge ]]; then
  "$HERE/../ha/check_backend_health.sh" || { echo 'FAIL: a backend application is not healthy from the edge' >&2; exit 1; }
fi
if [[ "$1" == client ]]; then
  echo 'Run the edge check first and confirm both backend ports are ALLOWED; a client timeout alone cannot distinguish a firewall block from a stopped backend.'
fi
status=0
printf 'Testing from %s; expected result: %s\n' "$(hostname)" "$expected"
for spec in "$BACKEND_A_IP $BACKEND_A_PORT A" "$BACKEND_B_IP $BACKEND_B_PORT B"; do
  read -r ip port label <<< "$spec"
  if nc -z -G 3 "$ip" "$port" >/dev/null 2>&1; then actual=ALLOWED; else actual=BLOCKED; fi
  printf 'Backend %s %s:%s: %s (expected %s)\n' "$label" "$ip" "$port" "$actual" "$expected"
  [[ "$actual" == "$expected" ]] || status=1
done
exit "$status"
