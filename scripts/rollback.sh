#!/usr/bin/env bash
# Runs ON the remote GLPI VM. Reverts to the commit recorded before the last deploy.
set -euo pipefail

REPO_DIR="${1:?Usage: rollback.sh <repo_dir>}"
cd "$REPO_DIR"

if [[ ! -f .last_good_commit ]]; then
    echo "No .last_good_commit file found — nothing to roll back to. Aborting."
    exit 1
fi

TARGET_COMMIT=$(cat .last_good_commit)
echo "Rolling back to: $TARGET_COMMIT"

git fetch origin
git reset --hard "$TARGET_COMMIT"

docker compose pull
docker compose up -d --remove-orphans

echo "Rollback complete. Current commit: $(git rev-parse HEAD)"
