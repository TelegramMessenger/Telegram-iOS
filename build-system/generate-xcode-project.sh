#!/bin/zsh

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

VARIABLES_DIRECTORY="build-input/data"
mkdir -p "$VARIABLES_DIRECTORY"
VARIABLES_PATH="$VARIABLES_DIRECTORY/variables.bzl"
rm -f "$VARIABLES_PATH"

GEN_DIRECTORY="build-input/gen/project"
rm -rf "$GEN_DIRECTORY"
mkdir -p "$GEN_DIRECTORY"

echo "telegram_build_number = \"$BUILD_NUMBER\"" >> "$VARIABLES_PATH"
echo "telegram_version = \"$APP_VERSION\"" >> "$VARIABLES_PATH"
echo "telegram_bundle_id = \"$BUNDLE_ID\"" >> "$VARIABLES_PATH"	
echo "telegram_api_id = \"$API_ID\"" >> "$VARIABLES_PATH"
echo "telegram_api_hash = \"$API_HASH\"" >> "$VARIABLES_PATH"
echo "telegram_app_center_id = \"$APP_CENTER_ID\"" >> "$VARIABLES_PATH"
echo "telegram_is_internal_build = \"$IS_INTERNAL_BUILD\"" >> "$VARIABLES_PATH"
echo "telegram_is_appstore_build = \"$IS_APPSTORE_BUILD\"" >> "$VARIABLES_PATH"
echo "telegram_appstore_id = \"$APPSTORE_ID\"" >> "$VARIABLES_PATH"
echo "telegram_app_specific_url_scheme = \"$APP_SPECIFIC_URL_SCHEME\"" >> "$VARIABLES_PATH"

BAZEL_OPTIONS=(\
	--features=swift.use_global_module_cache \
	--spawn_strategy=standalone \
	--strategy=SwiftCompile=standalone \
	--define=telegram_build_number="$BUILD_NUMBER" \
	--define=telegram_version="$APP_VERSION" \
	--define=telegram_bundle_id="$BUNDLE_ID" \
	--define=telegram_api_id="$API_ID" \
	--define=telegram_api_hash="$API_HASH" \
	--define=telegram_app_center_id="$APP_CENTER_ID" \
	--define=telegram_is_internal_build="$IS_INTERNAL_BUILD" \
	--define=telegram_is_appstore_build="$IS_APPSTORE_BUILD" \
	--define=telegram_appstore_id="$APPSTORE_ID" \
	--define=telegram_app_specific_url_scheme="$APP_SPECIFIC_URL_SCHEME" \
)

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
