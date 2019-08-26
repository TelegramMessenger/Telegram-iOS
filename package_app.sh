#!/bin/sh

set -x

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Usage: sh package_app.sh path/to/buck platform-flavors"
	exit 1
fi

PLATFORM_FLAVORS="$2"
BUCK="$1"

BUILD_PATH="build"
APP_NAME="Telegram"

IPA_PATH="$BUILD_PATH/$APP_NAME.ipa"
DSYMS_FOLDER_NAME="DSYMs"
DSYMS_ZIP="$BUILD_PATH/$DSYMS_FOLDER_NAME.zip"
DSYMS_DIR="$BUILD_PATH/$DSYMS_FOLDER_NAME"

mkdir -p "$BUILD_PATH"
rm -f "$IPA_PATH"
rm -f "$DSYMS_ZIP"
rm -rf "$DSYMS_DIR"
mkdir -p "$DSYMS_DIR"

cp "buck-out/gen/App/AppPackage#$PLATFORM_FLAVORS.ipa" "$IPA_PATH"

for DEPENDENCY in $($BUCK query "kind('apple_library|apple_binary', deps('//App:App#$PLATFORM_FLAVORS', 1))"); do
	case "$DEPENDENCY" in 
		*"#"*)
			;;
		*)
			DEPENDENCY="$DEPENDENCY#$PLATFORM_FLAVORS"	
			;;
	esac
	DSYM_PATH="buck-out/gen/$(echo "$DEPENDENCY" | sed -e "s/#/#apple-dsym,/" | sed -e "s#^//##" | sed -e "s#:#/#").dSYM"
	cp -f -r "$DSYM_PATH" "$DSYMS_DIR/"
done

DIR=$(pwd)
cd "$BUILD_PATH"
zip -r "$DSYMS_FOLDER_NAME.zip" "$DSYMS_FOLDER_NAME"
cd "$DIR"
