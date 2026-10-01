#!/bin/bash
# Layer-by-layer check: DNS, then TCP, then TLS, then HTTP
dig app.teamX.test +short
dig api.teamX.test +short
nc -vz 10.7.28.24 443
nc -vz 10.7.9.8 3001
nc -vz 10.7.11.140 3002
curl -v https://app.teamX.test/api/status 2>&1 | grep -E "Connected|SSL|HTTP/|X-Backend"
