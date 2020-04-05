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

XCODE_VERSION=$(cat "build-system/xcode_version")
INSTALLED_XCODE_VERSION=$(echo `plutil -p \`xcode-select -p\`/../Info.plist | grep -e CFBundleShortVersionString | sed 's/[^0-9\.]*//g'`)

if [ "$INSTALLED_XCODE_VERSION" != "$XCODE_VERSION" ]; then
	echo "Xcode $XCODE_VERSION required, $INSTALLED_XCODE_VERSION installed (at $(xcode-select -p))"
	exit 1
fi

GEN_DIRECTORY="build-input/gen/project"
mkdir -p "$GEN_DIRECTORY"

TULSI_DIRECTORY="build-input/gen/project"
TULSI_APP="build-input/gen/project/Tulsi.app"
TULSI="$TULSI_APP/Contents/MacOS/Tulsi"

rm -rf "$GEN_DIRECTORY/${APP_TARGET}.tulsiproj"
rm -rf "$TULSI_APP"

pushd "build-system/tulsi"
"$BAZEL" build //:tulsi --xcode_version="$XCODE_VERSION"
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

if [ "$BAZEL_CACHE_DIR" != "" ]; then
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

sed -i "" -e '1h;2,$H;$!d;g' -e 's/\("sourceFilters" : \[\n[ ]*\)"\.\/\.\.\."/\1"'"${APP_TARGET}"'\/...", "submodules\/..."/' "$GEN_DIRECTORY/${APP_TARGET}.tulsiproj/Configs/${APP_TARGET}.tulsigen"

"$TULSI" -- \
	--verbose \
	--genconfig "$GEN_DIRECTORY/${APP_TARGET}.tulsiproj:${APP_TARGET}" \
	--bazel "$BAZEL" \
	--outputfolder "$GEN_DIRECTORY" \
