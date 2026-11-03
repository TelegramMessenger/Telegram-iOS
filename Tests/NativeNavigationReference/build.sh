#!/bin/zsh
# Builds the native navigation reference app for the iOS simulator and installs it on a simulator.
# Usage: Tests/NativeNavigationReference/build.sh <simulator-udid> [output-dir]
# Then: xcrun simctl launch <udid> org.telegram.NativeNavigationReference -scenario editDone -interval 2
set -e
UDID="$1"
OUT="${2:-${TMPDIR:-/tmp}/NativeNavigationReference}"
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$OUT/NativeNavigationReference.app"
rm -rf "$APP"
mkdir -p "$APP"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -target arm64-apple-ios26.0-simulator -sdk "$SDK" -Onone -g "$HERE/main.swift" -o "$APP/NativeNavigationReference"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>org.telegram.NativeNavigationReference</string>
    <key>CFBundleExecutable</key><string>NativeNavigationReference</string>
    <key>CFBundleName</key><string>NavReference</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>MinimumOSVersion</key><string>26.0</string>
    <key>UIDeviceFamily</key><array><integer>1</integer></array>
    <key>UILaunchScreen</key><dict/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key><false/>
    </dict>
</dict>
</plist>
PLIST
codesign -s - --force "$APP"
if [ -n "$UDID" ]; then
    xcrun simctl install "$UDID" "$APP"
fi
echo "$APP"
