#!/usr/bin/env bash
# Runs inside the guddesk-client-builder container. Mirrors the bridge, Android and Linux jobs
# of guddesk-client/.github/workflows/flutter-build.yml.
#   /src  client source (read-only)    /work  persistent build tree    /out  GudDesk/downloads
set -euo pipefail

TARGETS="${TARGETS:-linux android-arm64 android-armv7}"
SRC=/work/src
OUT=/out

log() { echo "[$(date '+%H:%M:%S')] $*"; }
fix_owner() { [ -n "${HOST_UID:-}" ] && chown -R "${HOST_UID}:${HOST_GID}" "$OUT" /root/.android 2>/dev/null || true; }
trap fix_owner EXIT

log "Sync source → /work/src"
mkdir -p "$SRC" "$VCPKG_DEFAULT_BINARY_CACHE" "$VCPKG_DOWNLOADS" "$PUB_CACHE"
rsync -a --delete \
  --exclude .git --exclude /target --exclude /flutter/build --exclude /flutter/.dart_tool \
  --exclude /flutter/android/app/src/main/jniLibs --exclude /flutter/linux/flutter/ephemeral \
  /src/ "$SRC/"
cd "$SRC"
# build.rs regenerates the gitignored src/version.rs (removed by the sync) only when Cargo.toml changes.
touch Cargo.toml
VERSION=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)
log "GudDesk client ${VERSION}, targets: ${TARGETS}"

patch=.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff
git -C /opt/flutter apply --reverse --check "$SRC/$patch" 2>/dev/null || git -C /opt/flutter apply "$SRC/$patch"

log "Generate flutter_rust_bridge (Flutter 3.22.3, as in bridge.yml)"
cp flutter/pubspec.yaml /tmp/pubspec.yaml
cp flutter/pubspec.lock /tmp/pubspec.lock
sed -i -e 's/extended_text: 14.0.0/extended_text: 13.0.0/g' flutter/pubspec.yaml
(cd flutter && /opt/flutter-bridge/bin/flutter pub get)
PATH=/opt/flutter-bridge/bin:$PATH flutter_rust_bridge_codegen \
  --rust-input ./src/flutter_ffi.rs \
  --dart-output ./flutter/lib/generated_bridge.dart \
  --c-output ./flutter/macos/Runner/bridge_generated.h
cp /tmp/pubspec.yaml flutter/pubspec.yaml
cp /tmp/pubspec.lock flutter/pubspec.lock

vcpkg_install() {
  log "vcpkg install --triplet $1"
  if ! "$VCPKG_ROOT/vcpkg" install --triplet "$1" --x-install-root="$VCPKG_ROOT/installed"; then
    find "$VCPKG_ROOT/buildtrees" -name '*.log' -newer /tmp/pubspec.yaml -exec tail -n 40 {} + || true
    exit 1
  fi
}

# abi  rust-target  ndk-script  ndk-sysroot-triple  flutter-platform  name
build_android() {
  local abi=$1 target=$2 script=$3 sysroot=$4 platform=$5 name=$6
  log "vcpkg deps android ${abi}"
  ./flutter/build_android_deps.sh "$abi"
  log "cargo ndk ${target}"
  "./flutter/${script}"
  local jni="flutter/android/app/src/main/jniLibs/${abi}"
  mkdir -p "$jni"
  cp "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${sysroot}/libc++_shared.so" "$jni/"
  cp "target/${target}/release/liblibrustdesk.so" "$jni/librustdesk.so"
  sed -i "s/org.gradle.jvmargs=-Xmx1024M/org.gradle.jvmargs=-Xmx4g/g" flutter/android/gradle.properties
  # Release keystore is mounted from ~/.config/guddesk/android on the host. A debug signature is what
  # makes Play Protect hard-block the APK, so never fall back to it.
  cat > flutter/android/key.properties <<EOF
storePassword=${GUDDESK_STORE_PASSWORD:?release keystore password missing}
keyPassword=${GUDDESK_KEY_PASSWORD:?release keystore password missing}
keyAlias=${GUDDESK_KEY_ALIAS:-guddesk}
storeFile=/root/.android/guddesk-release.jks
EOF
  log "flutter build apk ${platform}"
  (cd flutter && flutter build apk --release --target-platform "$platform" --split-per-abi)
  cp "flutter/build/app/outputs/flutter-apk/app-${abi}-release.apk" "$OUT/GudDesk-android-${name}.apk"
  log "ok: GudDesk-android-${name}.apk"
}

build_linux() {
  vcpkg_install x64-linux
  cp Cargo.toml /tmp/Cargo.toml.orig
  sed -i 's/\["cdylib", "staticlib", "rlib"\]/["cdylib"]/g' Cargo.toml
  log "cargo build linux"
  cargo build --locked --lib --features hwcodec,flutter,unix-file-copy-paste --release
  log "flutter build linux + deb"
  DEB_ARCH=amd64 python3 ./build.py --flutter --skip-cargo
  cp /tmp/Cargo.toml.orig Cargo.toml
  mv "rustdesk-${VERSION}.deb" "$OUT/GudDesk-linux-amd64.deb"
  log "ok: GudDesk-linux-amd64.deb"
}

for t in $TARGETS; do
  case "$t" in
    android-arm64) build_android arm64-v8a aarch64-linux-android ndk_arm64.sh aarch64-linux-android android-arm64 arm64 ;;
    android-armv7) build_android armeabi-v7a armv7-linux-androideabi ndk_arm.sh arm-linux-androideabi android-arm armv7 ;;
    linux) build_linux ;;
    *) echo "unknown target: $t" >&2; exit 1 ;;
  esac
done

log "Write builds.json"
entries=()
for f in "$OUT"/GudDesk-*; do
  [ -f "$f" ] || continue
  n=$(basename "$f")
  entries+=("\"$n\":{\"size\":$(stat -c %s "$f"),\"sha256\":\"$(sha256sum "$f" | cut -d' ' -f1)\"}")
done
printf '{"version":"%s","official":false,"updated":"%s","files":{%s}}\n' \
  "$VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(IFS=,; echo "${entries[*]}")" > "$OUT/builds.json"
cat "$OUT/builds.json"
