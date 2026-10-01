#!/bin/bash
# Shows X-Backend alternating between A and B through the edge
for i in {1..10}; do
  curl -sI https://app.teamX.test/api/status | grep -i x-backend
done
