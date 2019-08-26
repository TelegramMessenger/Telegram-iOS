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

cp "buck-out/gen/App/AppPackage#$PLATFORM_FLAVORS.ipa" "$IPA_PATH.original"
rm -rf "$IPA_PATH.original.unpacked"
mkdir -p "$IPA_PATH.original.unpacked"
unzip "$IPA_PATH.original" -d "$IPA_PATH.original.unpacked/"

rm -rf "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*
rm -rf "$IPA_PATH.original.unpacked/Payload/App.app/Frameworks/"*

for DEPENDENCY in $($BUCK query "kind('apple_library|apple_binary', deps('//App:App#$PLATFORM_FLAVORS', 1))"); do
	case "$DEPENDENCY" in 
		*"#"*)
			;;
		*)
			DEPENDENCY="$DEPENDENCY#$PLATFORM_FLAVORS"	
			;;
	esac
	DEPENDENCY_PATH=$(echo "$DEPENDENCY" | sed -e "s#^//##" | sed -e "s#:#/#")
	DEPENDENCY_NAME=$(echo "$DEPENDENCY" | sed -e "s/#.*//" | sed -e "s/^.*\://")
	DYLIB_PATH="buck-out/gen/$DEPENDENCY_PATH/lib$DEPENDENCY_NAME.dylib"
	TARGET_DYLIB_PATH="$IPA_PATH.original.unpacked/Payload/App.app/Frameworks/lib$DEPENDENCY_NAME.dylib"
	cp "$DYLIB_PATH" "$TARGET_DYLIB_PATH"
	DSYM_PATH="buck-out/gen/$(echo "$DEPENDENCY" | sed -e "s/#/#apple-dsym,/" | sed -e "s#^//##" | sed -e "s#:#/#").dSYM"
	cp -f -r "$DSYM_PATH" "$DSYMS_DIR/"
done

for LIB in $(ls "$IPA_PATH.original.unpacked/Payload/App.app/Frameworks/"*.dylib); do
	strip -S -T "$LIB"
done

xcrun swift-stdlib-tool --scan-folder "$IPA_PATH.original.unpacked/Payload/App.app" --scan-folder "$IPA_PATH.original.unpacked/Payload/App.app/Frameworks" --strip-bitcode --platform iphoneos --copy --destination "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos"

for LIB in $(ls "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*.dylib); do
	codesign --remove-signature "$LIB"
	lipo -remove armv7s -remove arm64 "$LIB" -o "$LIB"
	bitcode_strip -r "$LIB" -o "$LIB"
	strip -S -T "$LIB"
done

cp "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*.dylib "$IPA_PATH.original.unpacked/Payload/App.app/Frameworks/"

DIR=$(pwd)
cd "$BUILD_PATH"
zip -r "$DSYMS_FOLDER_NAME.zip" "$DSYMS_FOLDER_NAME"
cd "$DIR"
