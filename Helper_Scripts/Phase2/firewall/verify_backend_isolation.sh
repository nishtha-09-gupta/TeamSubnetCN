#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need nc
[[ "$#" -eq 1 ]] || { echo "Usage: $0 client|edge" >&2; exit 2; }
case "$1" in client) expected=BLOCKED;; edge) expected=ALLOWED;; *) exit 2;; esac
status=0
echo "Running from $(hostname); expected service ports: $expected"
if [[ "$1" == client ]]; then echo "Before this client check, run with edge and confirm both ports report ALLOWED; a BLOCKED result can also mean a stopped backend."; fi
for spec in "$BACKEND_A_IP $BACKEND_A_PORT A" "$BACKEND_B_IP $BACKEND_B_PORT B"; do
  read -r ip port label <<< "$spec"
  if nc -z -G 3 "$ip" "$port" >/dev/null 2>&1; then actual=ALLOWED; else actual=BLOCKED; fi
  printf 'Backend %s %s:%s: %s (expected %s)
' "$label" "$ip" "$port" "$actual" "$expected"
  [[ "$actual" == "$expected" ]] || status=1
done
exit "$status"
