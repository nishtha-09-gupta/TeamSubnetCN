#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need pfctl
[[ "$#" == 2 && ( "$1" == A || "$1" == B ) ]] || { echo "Usage: sudo $0 A|B /etc/pf.anchors/teamphase2.teamx-phase2.TIMESTAMP.bak" >&2; exit 2; }
role=$1
anchor_backup=$2
anchor_file=/etc/pf.anchors/teamphase2
[[ -f "$anchor_backup" ]] || { echo "FAIL: anchor backup not found: $anchor_backup" >&2; exit 1; }
printf 'Restore the teamphase2 anchor to the saved state from before Backend %s rules were applied? [type YES] ' "$role"
read -r answer
[[ "$answer" == YES ]] || { echo 'No changes applied.'; exit 1; }
sudo cp -p "$anchor_backup" "$anchor_file" || exit 1
sudo pfctl -a teamphase2 -f "$anchor_file" || { echo 'FAIL: anchor restore did not load.' >&2; exit 1; }
token_file="${anchor_backup}.pf-token"
if [[ -f "$token_file" ]]; then
  token=$(cat "$token_file")
  [[ -n "$token" ]] || { echo 'FAIL: PF reference token file is empty.' >&2; exit 1; }
  sudo pfctl -X "$token" || { echo 'FAIL: could not release the PF enable reference.' >&2; exit 1; }
  sudo rm -f "$token_file"
fi
echo 'Restored only the saved teamphase2 anchor. /etc/pf.conf was not changed or reloaded.'
echo 'If both backend rules were installed, roll them back in reverse application order.'
