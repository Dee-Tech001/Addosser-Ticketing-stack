#!/usr/bin/env bash
# Runs ON the remote GLPI VM (invoked over SSH by Jenkins).
# Records the pre-deploy commit so rollback.sh has something to return to.
set -euo pipefail

REPO_DIR="${1:?Usage: deploy.sh <repo_dir>}"
cd "$REPO_DIR"

# Save current commit BEFORE moving, so rollback always has a known-good target.
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "$CURRENT_COMMIT" > .last_good_commit
echo "Recorded pre-deploy commit: $CURRENT_COMMIT"

git fetch origin
git reset --hard origin/main

docker compose pull
docker compose up -d --remove-orphans

echo "Deploy complete. New commit: $(git rev-parse HEAD)"
