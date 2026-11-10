#!/usr/bin/env bash
set -euo pipefail

SERVER="${SERVER:-root@148.230.101.168}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
REMOTE_DIR="${REMOTE_DIR:-/opt/gutekno/guddesk}"
SSH=(ssh -o BatchMode=yes -i "$SSH_KEY" "$SERVER")

cd "$(dirname "$0")"

"${SSH[@]}" "mkdir -p $REMOTE_DIR/data $REMOTE_DIR/web"
rsync -az --delete -e "ssh -o BatchMode=yes -i $SSH_KEY" \
  --exclude data --exclude .git --exclude .env \
  ./ "$SERVER:$REMOTE_DIR/"

# hbbs generates the keypair on first start; web mounts the public key file, so it must exist first.
"${SSH[@]}" "cd $REMOTE_DIR && docker compose pull -q && docker compose up -d hbbr hbbs && \
  for i in \$(seq 1 30); do [ -s data/id_ed25519.pub ] && break; sleep 1; done && \
  docker compose up -d web && docker compose ps && echo && echo \"Public key: \$(cat data/id_ed25519.pub)\""
