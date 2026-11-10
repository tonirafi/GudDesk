#!/usr/bin/env bash
# Build client GudDesk (Linux .deb + Android .apk) di LOCAL PC lewat Docker, hasil ke ./downloads.
# DILARANG menjalankan script ini di server production.
#
# Usage:
#   ./scripts/build-client.sh
#   TARGETS="android-arm64" ./scripts/build-client.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

_SAVED_TARGETS="${TARGETS:-}"
# shellcheck disable=SC1091
[ -f "$PROJECT_ROOT/project-config" ] && source "$PROJECT_ROOT/project-config"
TARGETS="${_SAVED_TARGETS:-linux android-arm64 android-armv7}"

CLIENT_DIR="$(cd "$PROJECT_ROOT/${CLIENT_DIR:-../guddesk-client}" && pwd)"
BUILDER_IMAGE="${BUILDER_IMAGE:-guddesk-client-builder}"
KEYSTORE_DIR="$HOME/.config/guddesk/android"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [ "$PROJECT_ROOT" = "${SERVER_PATH:-/opt/gutekno/guddesk}" ]; then
  echo "❌ DILARANG build di server production. Jalankan dari local PC."
  exit 1
fi

if [ ! -f "$CLIENT_DIR/Cargo.toml" ]; then
  echo "❌ Source client tidak ditemukan di $CLIENT_DIR"
  exit 1
fi

log "Building builder image ${BUILDER_IMAGE}..."
docker build -t "$BUILDER_IMAGE" "$PROJECT_ROOT/client-build"

mkdir -p "$PROJECT_ROOT/downloads" "$KEYSTORE_DIR"

log "Building client (${TARGETS}) from ${CLIENT_DIR}..."
docker run --rm \
  -e TARGETS="$TARGETS" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$CLIENT_DIR:/src:ro" \
  -v "$PROJECT_ROOT/downloads:/out" \
  -v "$KEYSTORE_DIR:/root/.android" \
  -v guddesk-work:/work \
  -v guddesk-cache:/cache \
  -v guddesk-cargo-registry:/opt/cargo/registry \
  -v guddesk-cargo-git:/opt/cargo/git \
  -v guddesk-vcpkg-installed:/opt/vcpkg/installed \
  -v guddesk-gradle:/root/.gradle \
  -v guddesk-android-sdk:/opt/android-sdk \
  "$BUILDER_IMAGE"

echo ""
echo "✅ Build selesai: $PROJECT_ROOT/downloads"
echo "   Deploy: ./scripts/remote-deploy-prod.sh"
