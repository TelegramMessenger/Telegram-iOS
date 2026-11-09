#!/usr/bin/env bash
# Pre-populate Bazel's repository cache with the large archives that GitHub
# occasionally refuses to serve to CI runners (502/503/504, truncated bodies).
#
# Every file is verified against its pinned SHA-256 before it is placed in
# Bazel's content-addressed repository cache, so a mirror can never corrupt the
# build: a bad download is discarded and Bazel simply fetches the archive
# itself.  The script always exits 0; it is only an optimisation.
#
# Cache layout (Bazel's DownloadCache): <cache>/content_addressable/sha256/<hash>/file

set -uo pipefail

cache_root="${BAZEL_REPOSITORY_CACHE:-$HOME/bazel-repository-cache}/content_addressable/sha256"
mkdir -p "$cache_root" || exit 0

# name | sha256 | primary URL | fallback URL (optional)
entries=(
  "bats-core v1.10.0|a1a9f7875aa4b6a9480ca384d5865f1ccf1b0b1faead6b47aa47d79709a5c5fd|https://github.com/bats-core/bats-core/archive/v1.10.0.tar.gz|https://codeload.github.com/bats-core/bats-core/tar.gz/v1.10.0"
  "rules_rust 0.74.0|d8bcc1e111e98270dc03172e22ef7af9c2f94f3269801618a2b83d20890f8df5|https://github.com/bazelbuild/rules_rust/releases/download/0.74.0/rules_rust-0.74.0.tar.gz|https://ghfast.top/https://github.com/bazelbuild/rules_rust/releases/download/0.74.0/rules_rust-0.74.0.tar.gz"
  "bazel-lib 3.1.0|fd0fe4df9b6b7837d5fd765c04ffcea462530a08b3d98627fb6be62a693f4e12|https://github.com/bazel-contrib/bazel-lib/releases/download/v3.1.0/bazel-lib-v3.1.0.tar.gz|https://ghfast.top/https://github.com/bazel-contrib/bazel-lib/releases/download/v3.1.0/bazel-lib-v3.1.0.tar.gz"
  "wasi-sdk 33 (macOS)|85c997a2665ead91673b5bb88b7d0df3fc8900df3bfa244f720d478187bbdc78|https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-33/wasi-sdk-33.0-arm64-macos.tar.gz|https://ghfast.top/https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-33/wasi-sdk-33.0-arm64-macos.tar.gz"
  "CMake 4.1.2|3be85f5b999e327b1ac7d804cbc9acd767059e9f603c42ec2765f6ab68fbd367|https://github.com/Kitware/CMake/releases/download/v4.1.2/cmake-4.1.2-macos-universal.tar.gz|https://ghfast.top/https://github.com/Kitware/CMake/releases/download/v4.1.2/cmake-4.1.2-macos-universal.tar.gz"
  "Meson 1.6.0|999b65f21c03541cf11365489c1fad22e2418bb0c3d50ca61139f2eec09d5496|https://github.com/mesonbuild/meson/releases/download/1.6.0/meson-1.6.0.tar.gz|https://ghfast.top/https://github.com/mesonbuild/meson/releases/download/1.6.0/meson-1.6.0.tar.gz"
  "Ninja 1.12.1|89a287444b5b3e98f88a945afa50ce937b8ffd1dcc59c555ad9b1baf855298c9|https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-mac.zip|https://ghfast.top/https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-mac.zip"
  "flatbuffers 24.12.23|c5cd6a605ff20350c7faa19d8eeb599df6117ea4aabd16ac58a7eb5ba82df4e7|https://codeload.github.com/google/flatbuffers/zip/refs/tags/v24.12.23|https://ghfast.top/https://github.com/google/flatbuffers/archive/refs/tags/v24.12.23.zip"
)

start_time=$SECONDS
budget_seconds=1200

fetch_entry() {
  local name sha primary fallback
  IFS='|' read -r name sha primary fallback <<< "$1"

  local dest="$cache_root/$sha/file"
  if [ -f "$dest" ]; then
    echo "Repository cache already contains $name"
    return 0
  fi

  if [ $((SECONDS - start_time)) -gt "$budget_seconds" ]; then
    echo "Prefetch time budget exhausted; skipping $name"
    return 0
  fi

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/bazel-prefetch.XXXXXX")" || return 0

  local urls=("$primary")
  if [ -n "${fallback:-}" ]; then
    urls+=("$fallback")
  fi

  local url attempt actual
  for url in "${urls[@]}"; do
    for attempt in 1 2; do
      echo "Prefetching $name (attempt $attempt): $url"
      if curl -fL --connect-timeout 20 --max-time 600 --retry 1 --retry-delay 10 \
          --speed-limit 1024 --speed-time 60 -o "$tmp" "$url"; then
        actual="$(shasum -a 256 "$tmp" | awk '{print $1}')"
        if [ "$actual" = "$sha" ]; then
          mkdir -p "$(dirname "$dest")"
          mv "$tmp" "$dest"
          echo "Cached $name"
          return 0
        fi
        echo "Hash mismatch for $name from $url (got $actual); discarding"
      fi
      sleep $((attempt * 10))
    done
  done

  rm -f "$tmp"
  echo "Could not prefetch $name; Bazel will download it itself"
  return 0
}

for entry in "${entries[@]}"; do
  fetch_entry "$entry"
done

echo "Prefetch finished."
exit 0
