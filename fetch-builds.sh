#!/usr/bin/env bash
# Runs on the server: pulls client builds from the GitHub "guddesk" release into ./downloads.
set -euo pipefail

REPO="${REPO:-tonirafi/guddesk-client}"
TAG="${TAG:-guddesk}"
cd "$(dirname "$0")"
mkdir -p downloads
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ "$TAG" = "latest" ]; then
  release_url="https://api.github.com/repos/$REPO/releases/latest"
else
  release_url="https://api.github.com/repos/$REPO/releases/tags/$TAG"
fi
official=false
[ "$REPO" = "rustdesk/rustdesk" ] && official=true
curl -fsSL "$release_url" -o "$tmp/release.json"
grep -o '"browser_download_url": *"[^"]*"' "$tmp/release.json" | cut -d'"' -f4 > "$tmp/urls"

# target filename <- asset name pattern
map=(
  "GudDesk-linux-amd64.deb|rustdesk-[0-9.]*-x86_64\.deb$"
  "GudDesk-macos-apple-silicon.dmg|rustdesk-[0-9.]*-aarch64\.dmg$"
  "GudDesk-macos-intel.dmg|rustdesk-[0-9.]*-x86_64\.dmg$"
  "GudDesk-android-arm64.apk|rustdesk-[0-9.]*-aarch64.*\.apk$"
  "GudDesk-android-armv7.apk|rustdesk-[0-9.]*-armv7.*\.apk$"
)

version=$(grep -o 'rustdesk-[0-9.]*[0-9]' "$tmp/urls" | head -1 | sed 's/rustdesk-//')
entries=()
for m in "${map[@]}"; do
  target="${m%%|*}"
  pattern="${m#*|}"
  url=$(grep -E "/$pattern" "$tmp/urls" | grep -v -- '-suse' | head -1 || true)
  if [ -z "$url" ]; then
    echo "missing: $target"
    continue
  fi
  curl -fsSL "$url" -o "$tmp/$target"
  mv "$tmp/$target" "downloads/$target"
  size=$(stat -c %s "downloads/$target")
  sha=$(sha256sum "downloads/$target" | cut -d' ' -f1)
  entries+=("\"$target\":{\"size\":$size,\"sha256\":\"$sha\"}")
  echo "ok: $target ($size bytes)"
done

printf '{"version":"%s","official":%s,"updated":"%s","files":{%s}}\n' \
  "$version" "$official" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(IFS=,; echo "${entries[*]}")" > downloads/builds.json.tmp
mv downloads/builds.json.tmp downloads/builds.json
cat downloads/builds.json
