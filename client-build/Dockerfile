# Toolchain for building the GudDesk client (Linux .deb + Android .apk) on the local PC.
# Versions follow guddesk-client/.github/workflows/flutter-build.yml and bridge.yml.
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG RUST_VERSION=1.75
ARG CARGO_NDK_VERSION=3.1.2
ARG CARGO_EXPAND_VERSION=1.0.95
ARG FLUTTER_RUST_BRIDGE_VERSION=1.80.1
ARG FLUTTER_VERSION=3.24.5
ARG BRIDGE_FLUTTER_VERSION=3.22.3
ARG NDK_VERSION=r28c
ARG VCPKG_COMMIT_ID=9e593bb18ea69cc5095e012465dcd675a822ed0d
ARG VCPKG_CMAKE_VERSION=4.3.0
ARG ANDROID_CMDLINE_TOOLS=11076708

RUN apt-get update && apt-get install -y --no-install-recommends \
      autoconf automake autoconf-archive bison build-essential ca-certificates clang curl file flex \
      g++ gcc git gperf libasound2-dev libayatana-appindicator3-dev libclang-dev \
      libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev libgtk-3-dev libltdl-dev libpulse-dev \
      libssl-dev libtool libunwind-dev libva-dev libxcb-randr0-dev libxcb-shape0-dev \
      libxcb-xfixes0-dev libxdo-dev libxfixes-dev llvm-dev nasm ninja-build \
      openjdk-17-jdk-headless pkg-config python3 python3-pip rsync tar unzip wget xz-utils zip \
    && apt-get remove -y libopus-dev || true \
    && rm -rf /var/lib/apt/lists/*

# vcpkg's SPDX scripts need CMake 4.3+; the policy minimum keeps older cmake_minimum_required() calls working.
RUN pip3 install --no-cache-dir "cmake==${VCPKG_CMAKE_VERSION}"
ENV CMAKE_POLICY_VERSION_MINIMUM=3.5

ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
ENV PATH=/opt/cargo/bin:$PATH
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal \
      --default-toolchain "${RUST_VERSION}" --component rustfmt \
    && rustup target add aarch64-linux-android armv7-linux-androideabi \
    && cargo install cargo-ndk --version "${CARGO_NDK_VERSION}" --locked \
    && cargo install cargo-expand --version "${CARGO_EXPAND_VERSION}" --locked \
    && cargo install flutter_rust_bridge_codegen --version "${FLUTTER_RUST_BRIDGE_VERSION}" --features uuid --locked \
    && rm -rf /opt/cargo/registry /opt/cargo/git

RUN git clone https://github.com/microsoft/vcpkg /opt/vcpkg \
    && git -C /opt/vcpkg checkout "${VCPKG_COMMIT_ID}" \
    && /opt/vcpkg/bootstrap-vcpkg.sh -disableMetrics
ENV VCPKG_ROOT=/opt/vcpkg VCPKG_DEFAULT_BINARY_CACHE=/cache/vcpkg-archives VCPKG_DOWNLOADS=/cache/vcpkg-downloads

RUN cd /opt \
    && wget -q "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar xf "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" && rm "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && wget -q "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${BRIDGE_FLUTTER_VERSION}-stable.tar.xz" \
    && mkdir flutter-bridge && tar xf "flutter_linux_${BRIDGE_FLUTTER_VERSION}-stable.tar.xz" -C flutter-bridge --strip-components=1 \
    && rm "flutter_linux_${BRIDGE_FLUTTER_VERSION}-stable.tar.xz" \
    && git config --system --add safe.directory '*'
ENV PATH=/opt/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true PUB_CACHE=/cache/pub

ENV ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_NDK_HOME=/opt/android-ndk-${NDK_VERSION} ANDROID_NDK_ROOT=/opt/android-ndk-${NDK_VERSION}
RUN mkdir -p /opt/android-sdk/cmdline-tools && cd /tmp \
    && wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" -O tools.zip \
    && unzip -q tools.zip && mv cmdline-tools /opt/android-sdk/cmdline-tools/latest && rm tools.zip \
    && yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null \
    && /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-36" "build-tools;35.0.0" > /dev/null \
    && wget -q "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" -O ndk.zip \
    && unzip -q ndk.zip -d /opt && rm ndk.zip

RUN flutter config --no-analytics && flutter precache --linux --android > /dev/null \
    && /opt/flutter-bridge/bin/flutter config --no-analytics && /opt/flutter-bridge/bin/flutter --version > /dev/null

# hwcodec's bindgen for Android targets needs the multilib headers (bits/libc-header-start.h).
RUN apt-get update && apt-get install -y --no-install-recommends gcc-multilib g++-multilib \
    && rm -rf /var/lib/apt/lists/*

# hwcodec's bindgen for Android targets needs the multilib headers (bits/libc-header-start.h).
RUN apt-get update && apt-get install -y --no-install-recommends gcc-multilib g++-multilib \
    && rm -rf /var/lib/apt/lists/*

COPY build.sh /usr/local/bin/guddesk-build
ENTRYPOINT ["/usr/local/bin/guddesk-build"]
