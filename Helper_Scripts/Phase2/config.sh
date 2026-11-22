#!/bin/bash
# Deployment values from Phase 2 terminal evidence (override by exporting before use).
PROJECT_DOMAIN=${PROJECT_DOMAIN:-teamX.test}
APP_HOST=${APP_HOST:-app.teamX.test}
API_HOST=${API_HOST:-api.teamX.test}
PRIMARY_DNS=${PRIMARY_DNS:-10.7.30.234}
BACKUP_DNS=${BACKUP_DNS:-10.7.13.67}
EDGE_IP=${EDGE_IP:-10.7.13.91}
STANDBY_EDGE_IP=${STANDBY_EDGE_IP:-}
BACKEND_A_IP=${BACKEND_A_IP:-10.7.30.234}
BACKEND_B_IP=${BACKEND_B_IP:-10.7.1.114}
BACKEND_A_PORT=${BACKEND_A_PORT:-3001}
BACKEND_B_PORT=${BACKEND_B_PORT:-3002}
HTTPS_PORT=${HTTPS_PORT:-443}
DNS_TTL=${DNS_TTL:-30}
TLS_CERT=${TLS_CERT:-/opt/homebrew/etc/nginx/certs/edge.crt}
TLS_KEY=${TLS_KEY:-/opt/homebrew/etc/nginx/certs/edge.key}
EDGE_INTERFACE=${EDGE_INTERFACE:-en0}
