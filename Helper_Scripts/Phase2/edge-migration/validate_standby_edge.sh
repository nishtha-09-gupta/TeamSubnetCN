#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
command -v nginx >/dev/null 2>&1 || { echo 'FAIL: nginx not installed/on PATH' >&2; exit 2; }
[[ -n "$STANDBY_EDGE_IP" ]] || { echo "FAIL: set STANDBY_EDGE_IP after confirming standby Mac assignment" >&2; exit 2; }
snippet=${1:-"$(cd "$HERE/../../../Configuration_Bundle/nginx" && pwd)/standby-edge.conf"}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/teamx-nginx-check.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/nginx.conf" <<EOF2
worker_processes 1;
pid $tmp/nginx.pid;
error_log $tmp/error.log;
events { worker_connections 16; }
http { include "$snippet"; }
EOF2
nginx -t -p "$tmp/" -c "$tmp/nginx.conf"
echo "Standby config syntax valid; check certificate/key availability on standby: $TLS_CERT and $TLS_KEY"
