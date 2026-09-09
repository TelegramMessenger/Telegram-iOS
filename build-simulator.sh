#!/bin/bash
#
# Build Telegram-iOS from the current branch and run it on an iOS simulator.
#
# The script is self-contained: the bazel binary and the build configuration ship
# with the repository and are resolved relative to this file, and Xcode is located
# by scanning the standard application directories. Nothing outside the checkout
# has to be prepared beforehand.
#
# Xcode 26 is required. The sources carry fixes for the iOS 26 SDK; Xcode 15
# predates them and Xcode 27 (iOS 27 SDK) has never been built against this tree.
#
# Environment overrides:
#   BUILD_NUMBER            build number passed to Make.py (default 100001)
#   TELEGRAM_BAZEL_CACHE    bazel disk cache directory (default ~/telegram-bazel-cache)

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$repo_root"

# Make.py resolves --bazel through a PATH lookup, so it has to be given an
# absolute path. Derive it from the checkout rather than hardcoding one.
bazel_binary="$repo_root/build-input/bazel-6.4.0-darwin-arm64"
configuration_path="build-system/template_minimal_development_configuration.json"
build_configuration="debug_sim_arm64"
build_number="${BUILD_NUMBER:-100001}"
cache_dir="${TELEGRAM_BAZEL_CACHE:-$HOME/telegram-bazel-cache}"

log() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# Highest locally installed Xcode 26, as a DEVELOPER_DIR.
resolve_developer_dir() {
    local app version best_version="" best_app=""
    for app in /Applications/Xcode*.app "$HOME"/Applications/Xcode*.app; do
        [ -d "$app" ] || continue
        version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null) || continue
        case "$version" in
            26.*) ;;
            *) continue ;;
        esac
        if [ -z "$best_version" ] || [ "$(printf '%s\n%s\n' "$best_version" "$version" | sort -V | tail -n 1)" = "$version" ]; then
            best_version="$version"
            best_app="$app"
        fi
    done
    [ -n "$best_app" ] || die "no Xcode 26 found in /Applications or ~/Applications"
    printf '%s\t%s' "$best_app/Contents/Developer" "$best_version"
}

# Bazel 6.4.0 links its wrapped_clang helper with -Wl,-no_uuid, and dyld on
# macOS 26 refuses to exec a binary that has no LC_UUID load command. Drop the
# flag from the freshly extracted install base. Bazel validates the install base
# by mtime, so the original (far-future) timestamp has to be restored, and the
# generated C++ toolchain has to go so it is reconfigured with the patched rule.
patch_bazel_install_base() {
    local install_base configure_file mtime output_base
    install_base=$("$bazel_binary" info install_base)
    configure_file="$install_base/embedded_tools/tools/cpp/osx_cc_configure.bzl"
    [ -f "$configure_file" ] || die "unexpected bazel install base layout at $install_base"

    if ! grep -q -- '"-Wl,-no_uuid",' "$configure_file"; then
        log "bazel install base already patched"
        return
    fi

    log "patching bazel install base for macOS 26 dyld (LC_UUID)"
    mtime=$(stat -f '%Sm' -t '%Y%m%d%H%M.%S' "$configure_file")
    sed -i '' -- '/"-Wl,-no_uuid",/d' "$configure_file"
    touch -t "$mtime" "$configure_file"

    output_base=$("$bazel_binary" info output_base)
    rm -rf "$output_base/external/local_config_cc"
}

# Booted iOS simulator if there is one, otherwise an iPhone. Runtimes matching the
# major version of the Xcode we build with are preferred over newer (beta) ones,
# so the app runs on the runtime whose SDK it was compiled against.
resolve_simulator() {
    xcrun simctl list devices available --json | python3 -c '
import json
import sys

preferred_major = int(sys.argv[1])
runtimes = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in runtimes.items():
    marker = "SimRuntime.iOS-"
    if marker not in runtime:
        continue
    version = [int(part) for part in runtime.split(marker)[-1].split("-")]
    for device in devices:
        if not device.get("isAvailable"):
            continue
        if device.get("state") == "Booted":
            print(device["udid"], device["name"], sep="\t")
            sys.exit(0)
        if "iPhone" not in device["name"]:
            continue
        candidate = (version[0] == preferred_major, version, device["name"])
        if best is None or candidate > best[0]:
            best = (candidate, device)

if best is None:
    sys.exit(1)
print(best[1]["udid"], best[1]["name"], sep="\t")
' "$1"
}

resolve_ipa() {
    local path
    if [ -f "bazel-bin/Telegram/Telegram.ipa" ]; then
        printf '%s' "bazel-bin/Telegram/Telegram.ipa"
        return
    fi
    path=$(ls -t bazel-out/applebin_ios-ios_sim_arm64-*/bin/Telegram/Telegram.ipa 2>/dev/null | head -n 1 || true)
    [ -n "$path" ] || die "no Telegram.ipa produced by the build"
    printf '%s' "$path"
}

resolved_xcode=$(resolve_developer_dir)
DEVELOPER_DIR="${resolved_xcode%%$'\t'*}"
xcode_version="${resolved_xcode#*$'\t'}"
export DEVELOPER_DIR
log "using Xcode $xcode_version at $DEVELOPER_DIR"

[ -x "$bazel_binary" ] || die "bazel binary missing at $bazel_binary"
[ -f "$configuration_path" ] || die "build configuration missing at $configuration_path"

patch_bazel_install_base

log "generating Xcode project"
python3 build-system/Make/Make.py \
    --bazel="$bazel_binary" \
    --cacheDir="$cache_dir" \
    --overrideXcodeVersion \
    generateProject \
    --configurationPath="$configuration_path" \
    --xcodeManagedCodesigning \
    --disableProvisioningProfiles \
    --buildNumber="$build_number"

log "building $build_configuration"
python3 build-system/Make/Make.py \
    --bazel="$bazel_binary" \
    --cacheDir="$cache_dir" \
    --overrideXcodeVersion \
    build \
    --configurationPath="$configuration_path" \
    --xcodeManagedCodesigning \
    --disableProvisioningProfiles \
    --buildNumber="$build_number" \
    --configuration="$build_configuration"

simulator=$(resolve_simulator "${xcode_version%%.*}") || die "no available iOS simulator to run on"
simulator_udid="${simulator%%$'\t'*}"
log "booting simulator ${simulator#*$'\t'}"
xcrun simctl bootstatus "$simulator_udid" -b > /dev/null
open -a Simulator

ipa_path=$(resolve_ipa)
payload_dir=$(mktemp -d "${TMPDIR:-/tmp}/telegram-simulator.XXXXXX")
trap 'rm -rf "$payload_dir"' EXIT
unzip -q "$ipa_path" -d "$payload_dir"

bundle_id=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["bundle_id"])' "$configuration_path")
log "installing $bundle_id from $ipa_path"
xcrun simctl install "$simulator_udid" "$payload_dir/Payload/Telegram.app"
xcrun simctl launch "$simulator_udid" "$bundle_id"
