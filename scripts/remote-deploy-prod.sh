#!/usr/bin/env bash
# Deploy ke production dari LOCAL PC: rsync config + downloads, lalu SSH pull/up.
# Tidak ada docker build di server (image resmi rustdesk-server + nginx).
#
# Usage:
#   ./scripts/remote-deploy-prod.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck disable=SC1091
[ -f "$PROJECT_ROOT/project-config" ] && source "$PROJECT_ROOT/project-config"

SERVER="${SERVER_USER:-root}@${SERVER_IP:-148.230.101.168}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
REMOTE_DIR="${SERVER_PATH:-/opt/gutekno/guddesk}"
SSH=(ssh -o BatchMode=yes -i "$SSH_KEY" "$SERVER")

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Remote deploy → ${SERVER}:${REMOTE_DIR}"

"${SSH[@]}" "mkdir -p $REMOTE_DIR/data $REMOTE_DIR/web $REMOTE_DIR/downloads && \
  { [ -f $REMOTE_DIR/downloads/builds.json ] || echo '{\"files\":{}}' > $REMOTE_DIR/downloads/builds.json; }"
rsync -az --delete -e "ssh -o BatchMode=yes -i $SSH_KEY" \
  --exclude data --exclude downloads --exclude client-build --exclude .git --exclude .env \
  ./ "$SERVER:$REMOTE_DIR/"

if [ -f downloads/builds.json ]; then
  log "Upload client builds..."
  rsync -az --delete -e "ssh -o BatchMode=yes -i $SSH_KEY" downloads/ "$SERVER:$REMOTE_DIR/downloads/"
else
  log "downloads/builds.json belum ada, build client dulu: make build-client"
fi

# hbbs generates the keypair on first start; web mounts the public key file, so it must exist first.
"${SSH[@]}" "cd $REMOTE_DIR && docker compose pull -q && docker compose up -d hbbr hbbs && \
  for i in \$(seq 1 30); do [ -s data/id_ed25519.pub ] && break; sleep 1; done && \
  docker compose up -d web && docker compose ps && echo && echo \"Public key: \$(cat data/id_ed25519.pub)\""

log "✅ Remote deploy selesai — https://${DOMAIN:-guddesk.gutekno.com}"
