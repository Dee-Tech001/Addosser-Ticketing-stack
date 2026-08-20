#!/usr/bin/env bash
# Runs ON the remote VM. Polls GLPI's HTTP endpoint until it's actually serving,
# not just until the container reports "running".
set -euo pipefail

MAX_ATTEMPTS=10
SLEEP_SECS=5

for i in $(seq 1 "$MAX_ATTEMPTS"); do
    if curl -sf -o /dev/null http://localhost:80/; then
        echo "Health check passed on attempt $i."
        exit 0
    fi
    echo "Waiting for GLPI to respond... ($i/$MAX_ATTEMPTS)"
    sleep "$SLEEP_SECS"
done

echo "Health check FAILED after $MAX_ATTEMPTS attempts."
exit 1
