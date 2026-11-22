#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need pfctl
[[ "$(uname -s)" == Darwin ]] || { echo 'FAIL: this installer supports macOS only' >&2; exit 2; }
dry_run=0
if [[ "${1:-}" == --dry-run ]]; then dry_run=1; shift; fi
[[ "$#" == 1 && ( "$1" == A || "$1" == B ) ]] || { echo "Usage: $0 [--dry-run] A|B" >&2; exit 2; }
role=$1
case "$role" in A) ip=$BACKEND_A_IP; port=$BACKEND_A_PORT;; B) ip=$BACKEND_B_IP; port=$BACKEND_B_PORT;; esac
pf_conf=/etc/pf.conf
anchor_file=/etc/pf.anchors/teamphase2
anchor_name=teamphase2
stamp=$(date +%Y%m%d%H%M%S)
pf_backup="${pf_conf}.teamx-phase2.${stamp}.bak"
anchor_backup="${anchor_file}.teamx-phase2.${stamp}.bak"
tmp=$(mktemp "${TMPDIR:-/tmp}/teamx-pf.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT

grep -Eq '^[[:space:]]*anchor "teamphase2"' "$pf_conf" || { echo 'FAIL: /etc/pf.conf has no teamphase2 anchor hook; no changes made.' >&2; exit 1; }
grep -Eq '^[[:space:]]*load anchor "teamphase2" from "/etc/pf.anchors/teamphase2"' "$pf_conf" || { echo 'FAIL: /etc/pf.conf does not load /etc/pf.anchors/teamphase2; no changes made.' >&2; exit 1; }
[[ -f "$anchor_file" ]] || { echo "FAIL: existing anchor file missing: $anchor_file; no changes made." >&2; exit 1; }

awk -v start="# BEGIN TEAMX PHASE2 BACKEND $role" -v finish="# END TEAMX PHASE2 BACKEND $role" '
  $0 == start {skip=1; next}
  $0 == finish {skip=0; next}
  !skip {print}
' "$anchor_file" > "$tmp" || exit 1
cat >> "$tmp" <<EOF_RULES
# BEGIN TEAMX PHASE2 BACKEND $role
pass in quick on $EDGE_INTERFACE inet proto tcp from $EDGE_IP to $ip port $port flags S/SA keep state
EOF_RULES
if [[ -n "$STANDBY_EDGE_IP" && "$STANDBY_EDGE_IP" != "$EDGE_IP" ]]; then
  printf 'pass in quick on %s inet proto tcp from %s to %s port %s flags S/SA keep state\n' "$EDGE_INTERFACE" "$STANDBY_EDGE_IP" "$ip" "$port" >> "$tmp"
fi
cat >> "$tmp" <<EOF_RULES
pass in quick on lo0 inet proto tcp from any to any port $port keep state
block drop in quick on $EDGE_INTERFACE inet proto tcp from any to any port $port
# END TEAMX PHASE2 BACKEND $role
EOF_RULES

cat <<EOF_PLAN
Plan: restrict Backend $role at $ip:$port to edge $EDGE_IP${STANDBY_EDGE_IP:+ and standby $STANDBY_EDGE_IP}.
Will back up $pf_conf and $anchor_file, then load only the existing '$anchor_name' anchor.
The base pf.conf is not rewritten or reloaded; unrelated system rules are not flushed.
EOF_PLAN
pfctl -vnf "$tmp" || { echo 'FAIL: candidate anchor rules did not validate; no changes made.' >&2; exit 1; }
if (( dry_run )); then echo 'Dry run passed; no files or firewall state changed.'; exit 0; fi
printf 'Apply this backend firewall change? [type YES] '; read -r answer
[[ "$answer" == YES ]] || { echo 'No changes applied.'; exit 1; }
sudo cp -p "$pf_conf" "$pf_backup" && sudo cp -p "$anchor_file" "$anchor_backup" || exit 1
sudo cp "$tmp" "$anchor_file" || exit 1
sudo pfctl -a "$anchor_name" -f "$anchor_file" || { echo "Load failed. Restore anchor with: rollback_backend_firewall.sh $role $anchor_backup" >&2; exit 1; }
sudo pfctl -E || { echo 'Rules loaded in anchor, but enabling PF reported a failure.' >&2; exit 1; }
echo "Applied. Base-config backup: $pf_backup"
echo "Anchor backup: $anchor_backup"
echo "Rollback: sudo $HERE/rollback_backend_firewall.sh $role $anchor_backup"
