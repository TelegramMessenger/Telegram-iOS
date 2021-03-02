#!/bin/sh

set -e

APP_TARGET="$1"
if [ "$APP_TARGET" == "" ]; then
	echo "Usage: sh generate-xcode-project.sh app_target_folder"
	exit 1
fi

BAZEL="$(which bazel)"
if [ "$BAZEL" = "" ]; then
	echo "bazel not found in PATH"
	exit 1
fi

BAZEL_x86_64="$BAZEL"
if [ "$(arch)" == "arm64" ]; then
	BAZEL_x86_64="$(which bazel_x86_64)"
fi
if [ "$BAZEL_x86_64" = "" ]; then
	echo "bazel_x86_64 not found in PATH"
	exit 1
fi

XCODE_VERSION=$(cat "build-system/xcode_version")
INSTALLED_XCODE_VERSION=$(echo `plutil -p \`xcode-select -p\`/../Info.plist | grep -e CFBundleShortVersionString | sed 's/[^0-9\.]*//g'`)

if [ "$IGNORE_XCODE_VERSION_MISMATCH" = "1" ]; then
	XCODE_VERSION="$INSTALLED_XCODE_VERSION"
else
	if [ "$INSTALLED_XCODE_VERSION" != "$XCODE_VERSION" ]; then
		echo "Xcode $XCODE_VERSION required, $INSTALLED_XCODE_VERSION installed (at $(xcode-select -p))"
		exit 1
	fi
fi
GEN_DIRECTORY="build-input/gen/project"
mkdir -p "$GEN_DIRECTORY"

TULSI_DIRECTORY="build-input/gen/project"
TULSI_APP="build-input/gen/project/Tulsi.app"
TULSI="$TULSI_APP/Contents/MacOS/Tulsi"

rm -rf "$GEN_DIRECTORY/${APP_TARGET}.tulsiproj"
rm -rf "$TULSI_APP"

pushd "build-system/tulsi"
"$BAZEL_x86_64" build //:tulsi --xcode_version="$XCODE_VERSION" --use_top_level_targets_for_symlinks
popd

mkdir -p "$TULSI_DIRECTORY"

unzip -oq "build-system/tulsi/bazel-bin/tulsi.zip" -d "$TULSI_DIRECTORY"

CORE_COUNT=$(sysctl -n hw.logicalcpu)
CORE_COUNT_MINUS_ONE=$(expr ${CORE_COUNT} \- 1)

BAZEL_OPTIONS=(\
	--features=swift.use_global_module_cache \
	--spawn_strategy=standalone \
	--strategy=SwiftCompile=standalone \
	--features=swift.enable_batch_mode \
	--swiftcopt=-j${CORE_COUNT_MINUS_ONE} \
)

if [ "$BAZEL_HTTP_CACHE_URL" != "" ]; then
	BAZEL_OPTIONS=("${BAZEL_OPTIONS[@]}" --remote_cache="$(echo $BAZEL_HTTP_CACHE_URL | sed -e 's/[\/&]/\\&/g')")
elif [ "$BAZEL_CACHE_DIR" != "" ]; then
	BAZEL_OPTIONS=("${BAZEL_OPTIONS[@]}" --disk_cache="$(echo $BAZEL_CACHE_DIR | sed -e 's/[\/&]/\\&/g')")
fi

"$TULSI" -- \
	--verbose \
	--create-tulsiproj "$APP_TARGET" \
	--workspaceroot ./ \
	--bazel "$BAZEL" \
	--outputfolder "$GEN_DIRECTORY" \
	--target "$APP_TARGET":"$APP_TARGET" \

PATCH_OPTIONS="BazelBuildOptionsDebug BazelBuildOptionsRelease"
for NAME in $PATCH_OPTIONS; do
	sed -i "" -e '1h;2,$H;$!d;g' -e 's/\("'"$NAME"'" : {\n[ ]*"p" : "$(inherited)\)/\1'" ${BAZEL_OPTIONS[*]}"'/' "$GEN_DIRECTORY/${APP_TARGET}.tulsiproj/Configs/${APP_TARGET}.tulsigen"
done

sed -i "" -e '1h;2,$H;$!d;g' -e 's/\("sourceFilters" : \[\n[ ]*\)"\.\/\.\.\."/\1"'"${APP_TARGET}"'\/...", "submodules\/...", "third-party\/..."/' "$GEN_DIRECTORY/${APP_TARGET}.tulsiproj/Configs/${APP_TARGET}.tulsigen"

"$TULSI" -- \
	--verbose \
	--genconfig "$GEN_DIRECTORY/${APP_TARGET}.tulsiproj:${APP_TARGET}" \
	--bazel "$BAZEL" \
	--outputfolder "$GEN_DIRECTORY" \
	--no-open-xcode \

sed -i '' -e '1h;2,$H;$!d;g' -e 's/BUILD_SETTINGS = BazelBuildSettings(/import os\nBUILD_SETTINGS = BazelBuildSettings(/g' "$GEN_DIRECTORY/${APP_TARGET}.xcodeproj/.tulsi/Scripts/bazel_build_settings.py"
sed -i '' -e '1h;2,$H;$!d;g' -e "s/'--cpu=ios_arm64'/'--cpu=ios_arm64'.replace('ios_arm64', 'ios_sim_arm64' if os.environ.get('EFFECTIVE_PLATFORM_NAME') == '-iphonesimulator' else 'ios_arm64')/g" "$GEN_DIRECTORY/${APP_TARGET}.xcodeproj/.tulsi/Scripts/bazel_build_settings.py"

open "$GEN_DIRECTORY/${APP_TARGET}.xcodeproj"
