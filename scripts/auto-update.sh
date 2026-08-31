#!/usr/bin/env bash
# Auto-update: pull latest from origin and restart if code changed.
# Run this on a cron or systemd timer on your server.
#
# Example crontab (every 5 minutes):
#   */5 * * * * /path/to/t3code/scripts/auto-update.sh >> /tmp/t3-autoupdate.log 2>&1
#
set -euo pipefail

REPO_DIR="${T3_REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
BRANCH="${T3_BRANCH:-main}"

cd "$REPO_DIR"

# Fetch latest
git fetch origin "$BRANCH" --quiet

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH")

if [ "$LOCAL" = "$REMOTE" ]; then
  exit 0
fi

echo "[$(date -Iseconds)] Update detected: $(git rev-parse --short "$LOCAL") → $(git rev-parse --short "$REMOTE")"

# Fast-forward
git checkout "$BRANCH" 2>/dev/null
git pull origin "$BRANCH" --ff-only --quiet

echo "[$(date -Iseconds)] Updated to $(git rev-parse --short HEAD)"

# Restart t3 if running as a service
if command -v systemctl &>/dev/null && systemctl is-active --quiet t3 2>/dev/null; then
  systemctl restart t3
  echo "[$(date -Iseconds)] Restarted t3 service"
elif pgrep -f "node.*t3.*serve" >/dev/null 2>&1; then
  PID=$(pgrep -f "node.*t3.*serve" | head -1)
  kill "$PID" 2>/dev/null || true
  sleep 1
  nohup node apps/server/src/bin.ts serve &>/dev/null &
  echo "[$(date -Iseconds)] Restarted t3 process"
fi
