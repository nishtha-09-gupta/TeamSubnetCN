#!/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../config.sh"
need() { command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing dependency: $1" >&2; exit 2; }; }
need dig
for dns in "$PRIMARY_DNS" "$BACKUP_DNS"; do echo "@$dns"; dig +noall +answer +ttlid @"$dns" "$APP_HOST" A; done
echo 'Direct @server answers show authoritative service values; system resolver answers may be cached.'
