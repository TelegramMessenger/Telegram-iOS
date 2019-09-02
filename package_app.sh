#!/bin/sh

set -x
set -e

PLATFORM_FLAVORS="$1"
BUCK="$2"
shift
shift

BUILD_PATH="build"
APP_NAME="Telegram"

IPA_PATH="$BUILD_PATH/$APP_NAME.ipa"
DSYMS_FOLDER_NAME="DSYMs"
DSYMS_ZIP="$BUILD_PATH/$DSYMS_FOLDER_NAME.zip"
DSYMS_DIR="$BUILD_PATH/$DSYMS_FOLDER_NAME"

TEMP_PATH="$BUILD_PATH/temp"
TEMP_ENTITLEMENTS_PATH="$TEMP_PATH/entitlements"
KEYCHAIN_PATH="$TEMP_PATH/keychain"

mkdir -p "$BUILD_PATH"
rm -f "$IPA_PATH"
rm -f "$DSYMS_ZIP"
rm -rf "$DSYMS_DIR"
mkdir -p "$DSYMS_DIR"
rm -rf "$TEMP_PATH"

mkdir -p "$TEMP_PATH"
mkdir -p "$TEMP_ENTITLEMENTS_PATH"

cp "buck-out/gen/AppPackage#$PLATFORM_FLAVORS.ipa" "$IPA_PATH.original"
rm -rf "$IPA_PATH.original.unpacked"
rm -f "$BUILD_PATH/${APP_NAME}_signed.ipa"
mkdir -p "$IPA_PATH.original.unpacked"
unzip "$IPA_PATH.original" -d "$IPA_PATH.original.unpacked/"
rm "$IPA_PATH.original"

UNPACKED_PATH="$IPA_PATH.original.unpacked"
APP_PATH="$UNPACKED_PATH/Payload/Telegram.app"
FRAMEWORKS_DIR="$APP_PATH/Frameworks"

rm -rf "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*
rm -rf "$IPA_PATH.original.unpacked/Symbols/"*
rm -rf "$FRAMEWORKS_DIR/"*

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Usage: sh package_app.sh path/to/buck platform-flavors"
	exit 1
fi

if [ -z "$PACKAGE_CODE_SIGN_IDENTITY" ]; then
	echo "PACKAGE_CODE_SIGN_IDENTITY is not set"
	exit 1
fi

if [ -z "$DEVELOPMENT_TEAM" ]; then
	echo "DEVELOPMENT_TEAM is not set"
	exit 1
fi

if [ ! -d "$CODESIGNING_DATA_PATH" ]; then
	echo "CODESIGNING_DATA_PATH $CODESIGNING_DATA_PATH does not exist"
	exit 1
fi

if [ -z "$CODESIGNING_CERTS_VARIANT" ]; then
	echo "CODESIGNING_CERTS_VARIANT is not set"
fi

if [ -z "$CODESIGNING_PROFILES_VARIANT" ]; then
	echo "CODESIGNING_PROFILES_VARIANT is not set"
fi

CERTS_PATH="$CODESIGNING_DATA_PATH/certs/$CODESIGNING_CERTS_VARIANT"
PROFILES_PATH="$CODESIGNING_DATA_PATH/profiles/$CODESIGNING_PROFILES_VARIANT"

if [ ! -d "$CERTS_PATH" ]; then
	echo "$CERTS_PATH does not exist"
	exit 1
fi

if [ ! -d "$PROFILES_PATH" ]; then
	echo "$PROFILES_PATH does not exist"
	exit 1
fi

#security delete-keychain "$KEYCHAIN_PATH" || true
rm -f "$KEYCHAIN_PATH"
#security create-keychain -p "password" "$KEYCHAIN_PATH"
#security unlock-keychain -p "password" "$KEYCHAIN_PATH"
KEYCHAIN_FLAG="--keychain '$KEYCHAIN_PATH'"

APP_ITEMS_WITH_PROVISIONING_PROFILE="APP EXTENSION_Share EXTENSION_Widget EXTENSION_NotificationService EXTENSION_NotificationContent EXTENSION_Intents WATCH_APP WATCH_EXTENSION"
APP_ITEMS_WITH_ENTITLEMENTS="APP EXTENSION_Share EXTENSION_Widget EXTENSION_NotificationService EXTENSION_NotificationContent EXTENSION_Intents"

COMMON_IDENTITY_HASH=""

for ITEM in $APP_ITEMS_WITH_PROVISIONING_PROFILE; do
	PROFILE_VAR=PACKAGE_PROVISIONING_PROFILE_$ITEM
	if [ -z "${!PROFILE_VAR}" ]; then
		echo "$PROFILE_VAR is not set"
		exit 1
	fi
	for PROFILE in "$PROFILES_PATH/"*; do
		PROFILE_DATA=$(security cms -D -i "$PROFILE")
		PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin <<< $(echo $PROFILE_DATA))
		if [ "$PROFILE_NAME" == "${!PROFILE_VAR}" ]; then
			TEAM_IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.developer.team-identifier" /dev/stdin <<< $(echo $PROFILE_DATA))
			if [ "$TEAM_IDENTIFIER" != "$DEVELOPMENT_TEAM" ]; then
				"Entitlements:com.apple.developer.team-identifier in $PROFILE does not match $DEVELOPMENT_TEAM"
			fi

			IDENTITY_NAME=$(/usr/libexec/PlistBuddy -c "Print :DeveloperCertificates:0 :data" /dev/stdin <<< $(echo $PROFILE_DATA) | openssl x509 -inform DER -subject -nameopt multiline -sha1 -noout | grep commonName | sed -e 's#[ ]*commonName[ ]*=[ ]*##g')
			if [ ! -z "$IDENTITY_NAME" ]; then
				IDENTITY_HASH=$(/usr/libexec/PlistBuddy -c "Print :DeveloperCertificates:0 :data" /dev/stdin <<< $(echo $PROFILE_DATA) | openssl x509 -inform DER -fingerprint -sha1 -noout | sed -e 's#SHA1 Fingerprint=##' | sed -e 's#:##g')
				if [ -z "$COMMON_IDENTITY_HASH" ]; then
					COMMON_IDENTITY_HASH="$IDENTITY_HASH"
				elif [ "$COMMON_IDENTITY_HASH" != "$IDENTITY_HASH" ]; then
					"Signing identity in $PROFILE ($IDENTITY_HASH) does not match $COMMON_IDENTITY_HASH from previously processed profiles"
				fi
			else
				echo "Signing identity name in $PROFILE does not match $PACKAGE_CODE_SIGN_IDENTITY"
				exit 1
			fi

			declare PROFILE_PATH_$ITEM="$PROFILE"

			PROFILE_ENTITLEMENTS_PATH="$TEMP_ENTITLEMENTS_PATH/$ITEM.entitlements"
			security cms -D -i "$PROFILE" > "$TEMP_PATH/temp.plist" && /usr/libexec/PlistBuddy -x -c 'Print:Entitlements' "$TEMP_PATH/temp.plist" > "$PROFILE_ENTITLEMENTS_PATH"
			declare ENTITLEMENTS_PATH_$ITEM="$PROFILE_ENTITLEMENTS_PATH"
		fi
	done
done

for ITEM in $APP_ITEMS_WITH_PROVISIONING_PROFILE; do
	PROFILE_PATH_VAR=PROFILE_PATH_$ITEM
	if [ -z "${!PROFILE_PATH_VAR}" ]; then
		echo "Provisioning profile for $ITEM was not found"
		exit 1
	fi
done

for ITEM in $APP_ITEMS_WITH_ENTITLEMENTS; do
	ENTITLEMENTS_VAR=PACKAGE_ENTITLEMENTS_$ITEM
	if [ -z "${!ENTITLEMENTS_VAR}" ]; then
		echo "$ENTITLEMENTS_VAR is not set"
		exit 1
	fi
	if [ ! -f "${!ENTITLEMENTS_VAR}" ]; then
		echo "${!ENTITLEMENTS_VAR} does not exist"
		exit 1	
	fi

	#declare ENTITLEMENTS_PATH_$ITEM="${!ENTITLEMENTS_VAR}"
done

if [ -z "$COMMON_IDENTITY_HASH" ]; then
	echo "Failed to determine signing identity"
	exit 1
fi

for DEPENDENCY in $(${BUCK} query "kind('apple_library', deps('//:Telegram#$PLATFORM_FLAVORS', 1))" "$@"); do
	DEPENDENCY_PATH=$(echo "$DEPENDENCY" | sed -e "s#^//##" | sed -e "s#:#/#")
	DEPENDENCY_NAME=$(echo "$DEPENDENCY" | sed -e "s/#.*//" | sed -e "s/^.*\://")
	DYLIB_PATH="buck-out/gen/$DEPENDENCY_PATH/lib$DEPENDENCY_NAME.dylib"
	TARGET_DYLIB_PATH="$FRAMEWORKS_DIR/lib$DEPENDENCY_NAME.dylib"
	cp "$DYLIB_PATH" "$TARGET_DYLIB_PATH"
	DSYM_PATH="buck-out/gen/$(echo "$DEPENDENCY" | sed -e "s/#/#apple-dsym,/" | sed -e "s#^//##" | sed -e "s#:#/#").dSYM"
	cp -r "$DSYM_PATH" "$DSYMS_DIR/"
done

APP_BINARY_DSYM_PATH="buck-out/gen/Telegram#dwarf-and-dsym,$PLATFORM_FLAVORS,no-include-frameworks/Telegram.app.dSYM"
cp -r "$APP_BINARY_DSYM_PATH" "$DSYMS_DIR/"

EXTENSIONS="Share Widget Intents NotificationContent NotificationService"
for EXTENSION in $EXTENSIONS; do
	EXTENSION_DSYM_PATH="buck-out/gen/${EXTENSION}Extension#dwarf-and-dsym,$PLATFORM_FLAVORS,no-include-frameworks/${EXTENSION}Extension.appex.dSYM"
	cp -r "$EXTENSION_DSYM_PATH" "$DSYMS_DIR/"
done

WATCH_EXTENSION_DSYM_PATH="buck-out/gen/WatchAppExtension#dwarf-and-dsym,no-include-frameworks,watchos-arm64_32,watchos-armv7k/WatchAppExtension.appex.dSYM"
cp -r "$WATCH_EXTENSION_DSYM_PATH" "$DSYMS_DIR/"

for LIB in $(ls "$FRAMEWORKS_DIR"/*.dylib); do
	strip -S -T "$LIB"
done

xcrun swift-stdlib-tool --scan-folder "$IPA_PATH.original.unpacked/Payload/Telegram.app" --scan-folder "$IPA_PATH.original.unpacked/Payload/Telegram.app/Frameworks" --scan-folder "$IPA_PATH.original.unpacked/Payload/Telegram.app/PlugIns" --strip-bitcode --platform iphoneos --copy --destination "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos"

for LIB in $(ls "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*.dylib); do
	codesign --remove-signature "$LIB"
	lipo -remove armv7s -remove arm64e "$LIB" -o "$LIB"
	xcrun bitcode_strip -r "$LIB" -o "$LIB"
	strip -S -T "$LIB"
done

cp "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*.dylib "$FRAMEWORKS_DIR/"

for framework in "$FRAMEWORKS_DIR"/*; do
    if [[ "$framework" == *.framework || "$framework" == *.dylib ]]; then
        /usr/bin/codesign ${VERBOSE} ${KEYCHAIN_FLAG} -f -s "$COMMON_IDENTITY_HASH" "$framework"
    fi
done

PLUGINS="Share Widget Intents NotificationService NotificationContent"
for PLUGIN in $PLUGINS; do
	PLUGIN_PATH="$APP_PATH/PlugIns/${PLUGIN}Extension.appex"
	if [ ! -d "$PLUGIN_PATH" ]; then
		echo "Directory at $PLUGIN_PATH does not exist"
		exit 1
	fi
	PROFILE_PATH_VAR="PROFILE_PATH_EXTENSION_$PLUGIN"
	if [ -z "${!PROFILE_PATH_VAR}" ]; then
		echo "$PROFILE_PATH_VAR is not defined"
		exit 1
	fi
	if [ ! -f "${!PROFILE_PATH_VAR}" ]; then
		echo "${!PROFILE_PATH_VAR} does not exist"
		exit 1
	fi
	ENTITLEMENTS_PATH_VAR="ENTITLEMENTS_PATH_EXTENSION_$PLUGIN"
	if [ -z "${!ENTITLEMENTS_PATH_VAR}" ]; then
		echo "$ENTITLEMENTS_PATH_VAR is not defined"
		exit 1
	fi
	if [ ! -f "${!ENTITLEMENTS_PATH_VAR}" ]; then
		echo "${!ENTITLEMENTS_PATH_VAR} does not exist"
		exit 1
	fi
	cp "${!PROFILE_PATH_VAR}" "$PLUGIN_PATH/embedded.mobileprovision"
	/usr/bin/codesign ${VERBOSE} -f -s "$COMMON_IDENTITY_HASH" --entitlements "${!ENTITLEMENTS_PATH_VAR}" "$PLUGIN_PATH"	
done

WATCH_APP_PATH="$APP_PATH/Watch/WatchApp.app"
WATCH_EXTENSION_PATH="$WATCH_APP_PATH/PlugIns/WatchAppExtension.appex"

WATCH_EXTENSION_PROFILE_PATH_VAR="PROFILE_PATH_WATCH_EXTENSION"
if [ -z "${!WATCH_EXTENSION_PROFILE_PATH_VAR}" ]; then
	echo "$WATCH_EXTENSION_PROFILE_PATH_VAR is not defined"
	exit 1
fi
if [ ! -f "${!WATCH_EXTENSION_PROFILE_PATH_VAR}" ]; then
	echo "${!WATCH_EXTENSION_PROFILE_PATH_VAR} does not exist"
	exit 1
fi
WATCH_EXTENSION_ENTITLEMENTS_PATH_VAR="ENTITLEMENTS_PATH_WATCH_EXTENSION"
if [ -z "${!WATCH_EXTENSION_ENTITLEMENTS_PATH_VAR}" ]; then
	echo "$WATCH_EXTENSION_ENTITLEMENTS_PATH_VAR is not defined"
	exit 1
fi
if [ ! -f "${!WATCH_EXTENSION_ENTITLEMENTS_PATH_VAR}" ]; then
	echo "${!WATCH_EXTENSION_ENTITLEMENTS_PATH_VAR} does not exist"
	exit 1
fi

cp "${!WATCH_EXTENSION_PROFILE_PATH_VAR}" "$WATCH_EXTENSION_PATH/embedded.mobileprovision"
/usr/bin/codesign ${VERBOSE} -f -s "$COMMON_IDENTITY_HASH" --entitlements "${!WATCH_EXTENSION_ENTITLEMENTS_PATH_VAR}" "$WATCH_EXTENSION_PATH"

WATCH_APP_PROFILE_PATH_VAR="PROFILE_PATH_WATCH_APP"
if [ -z "${!WATCH_APP_PROFILE_PATH_VAR}" ]; then
	echo "$WATCH_APP_PROFILE_PATH_VAR is not defined"
	exit 1
fi
if [ ! -f "${!WATCH_APP_PROFILE_PATH_VAR}" ]; then
	echo "${!WATCH_APP_PROFILE_PATH_VAR} does not exist"
	exit 1
fi
WATCH_APP_ENTITLEMENTS_PATH_VAR="ENTITLEMENTS_PATH_WATCH_APP"
if [ -z "${!WATCH_APP_ENTITLEMENTS_PATH_VAR}" ]; then
	echo "$WATCH_APP_ENTITLEMENTS_PATH_VAR is not defined"
	exit 1
fi
if [ ! -f "${!WATCH_APP_ENTITLEMENTS_PATH_VAR}" ]; then
	echo "${!WATCH_APP_ENTITLEMENTS_PATH_VAR} does not exist"
	exit 1
fi

cp "${!WATCH_APP_PROFILE_PATH_VAR}" "$WATCH_APP_PATH/embedded.mobileprovision"
/usr/bin/codesign ${VERBOSE} -f -s "$COMMON_IDENTITY_HASH" --entitlements "${!WATCH_APP_ENTITLEMENTS_PATH_VAR}" "$WATCH_APP_PATH"

APP_PROFILE_PATH_VAR="PROFILE_PATH_APP"
if [ -z "${!APP_PROFILE_PATH_VAR}" ]; then
	echo "$APP_PROFILE_PATH_VAR is not defined"
	exit 1
fi
if [ ! -f "${!APP_PROFILE_PATH_VAR}" ]; then
	echo "${!APP_PROFILE_PATH_VAR} does not exist"
	exit 1
fi
APP_ENTITLEMENTS_PATH_VAR="ENTITLEMENTS_PATH_APP"
if [ -z "${!APP_ENTITLEMENTS_PATH_VAR}" ]; then
	echo "$APP_ENTITLEMENTS_PATH_VAR is not defined"
	exit 1
fi
if [ ! -f "${!APP_ENTITLEMENTS_PATH_VAR}" ]; then
	echo "${!APP_ENTITLEMENTS_PATH_VAR} does not exist"
	exit 1
fi

cp "${!APP_PROFILE_PATH_VAR}" "$APP_PATH/embedded.mobileprovision"
/usr/bin/codesign ${VERBOSE} -f -s "$COMMON_IDENTITY_HASH" --entitlements "${!APP_ENTITLEMENTS_PATH_VAR}" "$APP_PATH"

DIR=$(pwd)

cd "$UNPACKED_PATH"
zip -r "../${APP_NAME}_signed.ipa" Payload #SwiftSupport WatchKitSupport2
cd "$DIR"

cd "$BUILD_PATH"
zip -r "$DSYMS_FOLDER_NAME.zip" "$DSYMS_FOLDER_NAME"

cd "$DIR"
