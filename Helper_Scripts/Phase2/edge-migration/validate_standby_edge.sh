#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need nginx
need openssl
need dig
need curl
need ifconfig
[[ "$#" -le 2 ]] || { echo "Usage: $0 [STANDBY_EDGE_IPV4 [NGINX_SERVER_CONFIG]]" >&2; exit 2; }
standby_ip=${1:-$STANDBY_EDGE_IP}
[[ -n "$standby_ip" ]] || { echo "Set STANDBY_EDGE_IP or pass a confirmed standby IPv4 address" >&2; exit 2; }
printf "%s\n" "$standby_ip" | awk -F. 'NF != 4 {exit 1} {for (i=1;i<=4;i++) if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1}' || { echo 'FAIL: provide the confirmed standby IPv4 address; none is assumed' >&2; exit 2; }
[[ "$standby_ip" != "$EDGE_IP" ]] || { echo 'FAIL: standby edge must be a different host from the current edge' >&2; exit 2; }
if ! ifconfig | awk '/inet / {print $2}' | grep -Fxq "$standby_ip"; then echo "FAIL: $standby_ip is not assigned to this Mac" >&2; exit 1; fi
snippet=${2:-"$(cd "$HERE/../../../Configuration_Bundle/nginx" && pwd)/standby-edge.conf"}
[[ -r "$snippet" ]] || { echo "FAIL: nginx server config not readable: $snippet" >&2; exit 1; }
[[ -r "$TLS_CERT" && -r "$TLS_KEY" ]] || { echo "FAIL: standby certificate or key missing/unreadable ($TLS_CERT, $TLS_KEY)" >&2; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/teamx-nginx-check.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/nginx.conf" <<EOF_NGINX
worker_processes 1;
pid $tmp/nginx.pid;
error_log $tmp/error.log;
events { worker_connections 16; }
http { include "$snippet"; }
EOF_NGINX
printf '1. Validate standby nginx configuration and TLS files\n'
nginx -t -p "$tmp/" -c "$tmp/nginx.conf" || exit 1
for host in "$APP_HOST" "$API_HOST"; do
  openssl x509 -in "$TLS_CERT" -noout -checkhost "$host" >/dev/null || { echo "FAIL: certificate does not validate hostname $host" >&2; exit 1; }
done
cert_key=$(openssl x509 -in "$TLS_CERT" -pubkey -noout) || exit 1
private_key=$(openssl pkey -in "$TLS_KEY" -pubout 2>/dev/null) || { echo 'FAIL: cannot read TLS private key' >&2; exit 1; }
[[ "$cert_key" == "$private_key" ]] || { echo 'FAIL: TLS certificate and private key do not match' >&2; exit 1; }
printf 'Certificate SAN/hostname checks and certificate/key match: PASS\n\n'
printf '2. Check both backends directly from the standby Mac\n'
"$HERE/../ha/check_backend_health.sh" || { echo 'FAIL: standby host cannot reach both healthy backends; check backend services and PF allowlist.' >&2; exit 1; }
printf '\n3. Confirm DNS remains on the original edge before migration\n'
for dns in "$PRIMARY_DNS" "$BACKUP_DNS"; do
  for host in "$APP_HOST" "$API_HOST"; do
    answer=$(dig +time=2 +tries=1 +noall +answer +ttlid @"$dns" "$host" A) || { echo "FAIL: DNS query to $dns failed" >&2; exit 1; }
    printf '%s via %s: %s\n' "$host" "$dns" "${answer:-NO ANSWER}"
    answer_ip=$(printf '%s\n' "$answer" | awk '$4 == "A" {print $5}')
    [[ "$answer_ip" == "$EDGE_IP" ]] || { echo "FAIL: pre-cutover DNS should return only $EDGE_IP" >&2; exit 1; }
  done
done
printf '\n4. Validate standby HTTPS, SNI, certificate hostname, routing and response headers\n'
for host in "$APP_HOST" "$API_HOST"; do
  headers=$(curl -fsS --connect-timeout 3 --max-time 10 --resolve "$host:$HTTPS_PORT:$standby_ip" --cacert "$TLS_CERT" -D - -o /dev/null "https://$host:$HTTPS_PORT/api/status") || { echo "FAIL: standby HTTPS request failed for $host" >&2; exit 1; }
  printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^HTTP\// || /^X-Backend:/ || /^X-Edge:/ {gsub("\r",""); print}'
  printf '%s\n' "$headers" | grep -qi '^X-Backend:' || { echo "FAIL: missing X-Backend from $host" >&2; exit 1; }
  printf '%s\n' "$headers" | grep -qi '^X-Edge:' || { echo "FAIL: missing X-Edge from $host" >&2; exit 1; }
done
echo 'Standby pre-cutover validation passed. DNS still points to the original edge; no DNS records were modified.'
