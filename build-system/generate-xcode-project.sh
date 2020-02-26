#!/bin/sh

set -e

BAZEL="$(which bazel)"
if [ "$BAZEL" = "" ]; then
	echo "bazel not found in PATH"
	exit 1
fi

EXPECTED_VARIABLES=(\
	BUILD_NUMBER \
	APP_VERSION \
	BUNDLE_ID \
	API_ID \
	API_HASH \
	APP_CENTER_ID \
	IS_INTERNAL_BUILD \
	IS_APPSTORE_BUILD \
	APPSTORE_ID \
	APP_SPECIFIC_URL_SCHEME \
)

MISSING_VARIABLES="0"
for VARIABLE_NAME in ${EXPECTED_VARIABLES[@]}; do
	if [ "${!VARIABLE_NAME}" = "" ]; then
		echo "$VARIABLE_NAME not defined"
		MISSING_VARIABLES="1"
	fi
done
if [ "$MISSING_VARIABLES" == "1" ]; then
	exit 1
fi

GEN_DIRECTORY="build-input/gen/project"
rm -rf "$GEN_DIRECTORY"
mkdir -p "$GEN_DIRECTORY"

BAZEL_OPTIONS=(\
	--features=swift.use_global_module_cache \
	--spawn_strategy=standalone \
	--strategy=SwiftCompile=standalone \
)
set -x
if [ "$BAZEL_CACHE_DIR" != "" ]; then
	BAZEL_OPTIONS=("${BAZEL_OPTIONS[@]}" --disk_cache="$(echo $BAZEL_CACHE_DIR | sed -e 's/[\/&]/\\&/g')")
fi 

$HOME/Applications/Tulsi.app/Contents/MacOS/Tulsi -- \
	--verbose \
	--create-tulsiproj Telegram \
	--workspaceroot ./ \
	--bazel "$BAZEL" \
	--outputfolder "$GEN_DIRECTORY" \
	--target Telegram:Telegram \
	--target Telegram:Main \
	--target Telegram:Lib \

PATCH_OPTIONS="BazelBuildOptionsDebug BazelBuildOptionsRelease"
for NAME in $PATCH_OPTIONS; do
	sed -i "" -e '1h;2,$H;$!d;g' -e 's/\("'"$NAME"'" : {\n[ ]*"p" : "$(inherited)\)/\1'" ${BAZEL_OPTIONS[*]}"'/' "$GEN_DIRECTORY/Telegram.tulsiproj/Configs/Telegram.tulsigen"
done

sed -i "" -e '1h;2,$H;$!d;g' -e 's/\("sourceFilters" : \[\n[ ]*\)"\.\/\.\.\."/\1"Telegram\/...", "submodules\/..."/' "$GEN_DIRECTORY/Telegram.tulsiproj/Configs/Telegram.tulsigen"

${HOME}/Applications/Tulsi.app/Contents/MacOS/Tulsi -- \
	--verbose \
	--genconfig "$GEN_DIRECTORY/Telegram.tulsiproj:Telegram" \
	--bazel "$BAZEL" \
	--outputfolder "$GEN_DIRECTORY" \
