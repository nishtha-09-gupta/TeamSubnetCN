#!/bin/bash
# Full request, then conditional request (expect 304 if same backend answers)
URL=https://app.teamX.test/api/status
curl -si $URL | head -n 12
ETAG=$(curl -sI $URL | grep -i '^etag' | cut -d' ' -f2- | tr -d '\r')
echo "--- conditional request with If-None-Match: $ETAG"
curl -si -H "If-None-Match: $ETAG" $URL | head -n 8
echo "NOTE: A and B have different ETags; if round-robin hits the other backend you get 200, not 304."
