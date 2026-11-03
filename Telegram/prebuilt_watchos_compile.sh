#!/usr/bin/env bash
# Compile worker for the apple_prebuilt_watchos_application Bazel rule (action 1 of 2).
#
# Builds the tgwatch watch app via xcodebuild (device, Release, UNSIGNED) and zips the
# .app into the rule's intermediate archive.
#
# It bakes the values that xcodebuild must own — the api credentials and the bundle id
# (PRODUCT_BUNDLE_IDENTIFIER, from which the Info.plist derives
# WKCompanionAppBundleIdentifier via $(PRODUCT_BUNDLE_IDENTIFIER:base)) — and leaves
# the version keys as PLACEHOLDERS for prebuilt_watchos_patch.sh to rewrite. All three
# baked values are stable for a given host configuration, whereas the version changes
# on every build, so keeping the version out of this action is what makes the
# expensive (~4-min) xcodebuild cacheable across builds.
#
# Args:
#   $1 source_path      Execroot-relative path to the committed in-repo snapshot
#                       (Telegram/WatchApp), which contains tgwatch.xcodeproj.
#   $2 output_zip       Path (declared by Bazel) to write the unsigned .app archive to.
#   $3 api_id           TG_API_ID build setting
#   $4 api_hash         TG_API_HASH build setting
#   $5 watch_bundle_id  PRODUCT_BUNDLE_IDENTIFIER (the watch app id, "<host>.watchkitapp");
#                       empty => keep the project default.
set -euo pipefail

SRC="$1"; OUT_ZIP="$2"; API_ID="${3:-0}"; API_HASH="${4:-placeholder}"; WATCH_BUNDLE_ID="${5:-}"

if [ ! -e "$SRC/tgwatch.xcodeproj" ]; then
  echo "error: no tgwatch.xcodeproj at $SRC (re-sync the Telegram/WatchApp snapshot via tgwatch/tools/export-sources.sh)" >&2
  exit 1
fi

DD="$(mktemp -d)"
trap 'rm -rf "$DD"' EXIT

# Build from a writable copy so xcodebuild/SwiftPM never write into the (possibly
# in-repo, read-only) source tree — e.g. SwiftPM's Package.resolved or the workspace.
# The tree is small (~12M); a plain cp on each (uncached) build is acceptable.
WORKSRC="$DD/src"
mkdir -p "$WORKSRC"
cp -R "$SRC/." "$WORKSRC/"

# MARKETING_VERSION / CURRENT_PROJECT_VERSION are placeholders; the patch action
# overwrites CFBundleShortVersionString / CFBundleVersion afterwards. They only ever
# land in Info.plist (via $(...) substitution), never in the compiled binary, so the
# build output is independent of them. Note the nested TDLibFramework keeps these
# placeholder versions — nothing verifies a nested framework's version against the
# host, only the watch app's own Info.plist, which the patch action fixes up.
xcodebuild \
  -project "$WORKSRC/tgwatch.xcodeproj" \
  -scheme "tgwatch Watch App" \
  -configuration Release \
  -destination 'generic/platform=watchOS' \
  -derivedDataPath "$DD" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  TG_API_ID="$API_ID" TG_API_HASH="$API_HASH" \
  MARKETING_VERSION=0.0 CURRENT_PROJECT_VERSION=0 \
  ${WATCH_BUNDLE_ID:+PRODUCT_BUNDLE_IDENTIFIER="$WATCH_BUNDLE_ID"} \
  build 1>&2

APP="$(find "$DD/Build/Products" -maxdepth 2 -name 'tgwatch Watch App.app' -type d | head -1)"
if [ -z "$APP" ]; then
  echo "error: built watch .app not found under $DD/Build/Products" >&2
  exit 1
fi

# $OUT_ZIP is execroot-relative; the action's cwd is the execroot, so do NOT cd
# (that would resolve $OUT_ZIP against the DerivedData dir). --keepParent makes the
# archive root the .app itself even when $APP is an absolute path.
rm -f "$OUT_ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$OUT_ZIP"
