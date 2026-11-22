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
stamp="$(date +%Y%m%d%H%M%S)-$$"
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
printf '# BEGIN TEAMX PHASE2 BACKEND %s\n' "$role" >> "$tmp"
append_rule() {
  if ! grep -Fxq "$1" "$tmp"; then printf '%s\n' "$1" >> "$tmp"; fi
}
append_rule "pass in quick on $EDGE_INTERFACE inet proto tcp from $EDGE_IP to $ip port = $port flags S/SA keep state"
if [[ -n "$STANDBY_EDGE_IP" && "$STANDBY_EDGE_IP" != "$EDGE_IP" ]]; then
  append_rule "pass in quick on $EDGE_INTERFACE inet proto tcp from $STANDBY_EDGE_IP to $ip port = $port flags S/SA keep state"
fi
append_rule "pass in quick on lo0 inet proto tcp from any to any port = $port keep state"
append_rule "block drop in quick on $EDGE_INTERFACE inet proto tcp from any to any port $port"
printf '# END TEAMX PHASE2 BACKEND %s\n' "$role" >> "$tmp"

cat <<EOF_PLAN
Plan: restrict Backend $role at $ip:$port to edge $EDGE_IP${STANDBY_EDGE_IP:+ and standby $STANDBY_EDGE_IP}.
Will back up only $anchor_file, then load only the existing '$anchor_name' anchor.
The base pf.conf is not rewritten or reloaded; unrelated system rules are not flushed.
EOF_PLAN
pfctl -vnf "$tmp" || { echo 'FAIL: candidate anchor rules did not validate; no changes made.' >&2; exit 1; }
if (( dry_run )); then echo 'Dry run passed; no files or firewall state changed.'; exit 0; fi
printf 'Apply this backend firewall change? [type YES] '; read -r answer
[[ "$answer" == YES ]] || { echo 'No changes applied.'; exit 1; }
sudo cp -p "$anchor_file" "$anchor_backup" || exit 1
echo "Saved anchor: $anchor_backup"
sudo cp "$tmp" "$anchor_file" || exit 1
sudo pfctl -a "$anchor_name" -f "$anchor_file" || { echo "Load failed. Restore anchor with: rollback_backend_firewall.sh $role $anchor_backup" >&2; exit 1; }
pf_status=$(sudo pfctl -s info 2>/dev/null | awk -F: '/Status:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')
if [[ "$pf_status" == Disabled ]]; then
  enable_output=$(sudo pfctl -E 2>&1) || { echo "Rules loaded, but PF could not be enabled. Restore using $anchor_backup" >&2; exit 1; }
  enable_token=$(printf '%s\n' "$enable_output" | awk -F: '/Token/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')
  if [[ -n "$enable_token" ]]; then
    printf '%s\n' "$enable_token" | sudo tee "${anchor_backup}.pf-token" >/dev/null || exit 1
  else
    echo "FAIL: PF enabled but no reference token was returned. Restore anchor with $anchor_backup and review pfctl output:" >&2
    printf '%s\n' "$enable_output" >&2
    exit 1
  fi
elif [[ "$pf_status" != Enabled ]]; then
  echo "FAIL: could not determine PF status ($pf_status); anchor loaded but PF enable state was not changed. Restore anchor with $anchor_backup." >&2
  exit 1
fi
echo "Applied. Anchor backup: $anchor_backup"
echo "Rollback: sudo $HERE/rollback_backend_firewall.sh $role $anchor_backup"
