#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need pfctl
[[ "$#" -eq 2 ]] || { echo "Usage: sudo $0 A|B /etc/pf.conf.teamx-phase2.TIMESTAMP.bak" >&2; exit 2; }
role=$1; backup=$2; [[ "$role" == A || "$role" == B ]] || exit 2
case "$role" in A) anchor_name=teamx-phase2-a;; B) anchor_name=teamx-phase2-b;; esac
[[ -f "$backup" ]] || { echo "FAIL: backup not found: $backup" >&2; exit 1; }
printf 'Restore /etc/pf.conf from %s and remove TeamSubnetCN role-%s anchor? [type YES] ' "$backup" "$role"; read -r answer
[[ "$answer" == YES ]] || exit 1
sudo cp -p "$backup" /etc/pf.conf || exit 1
sudo rm -f "/etc/pf.anchors/$anchor_name"
sudo pfctl -vnf /etc/pf.conf && sudo pfctl -f /etc/pf.conf
echo 'Restored prior pf.conf. No global ruleset flush performed.'
