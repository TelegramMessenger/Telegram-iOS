#!/bin/sh

set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
	echo "Usage: sh package_app.sh path/to/buck platform-flavors type"
	exit 1
fi

PLATFORM_FLAVORS="$1"
BUCK="$2"
APP_TYPE="$3"
shift
shift
shift

BUILD_PATH="build"
if [ "$APP_TYPE" == "wallet" ]; then
	APP_NAME="TONWallet"
else
	APP_NAME="Telegram"
fi

IPA_PATH="$BUILD_PATH/$APP_NAME.ipa"
DSYMS_FOLDER_NAME="DSYMs"
DSYMS_ZIP="$BUILD_PATH/$DSYMS_FOLDER_NAME.zip"
DSYMS_DIR="$BUILD_PATH/$DSYMS_FOLDER_NAME"

TEMP_PATH="$BUILD_PATH/temp"
TEMP_ENTITLEMENTS_PATH="$TEMP_PATH/entitlements"
KEYCHAIN_PATH="$TEMP_PATH/keychain"

if [ -z "$PACKAGE_BUNDLE_ID" ]; then
	echo "PACKAGE_BUNDLE_ID not set"
	exit 1
fi

BUNDLE_ID_PREFIX=$(echo "$PACKAGE_BUNDLE_ID" | grep -Eo "^.*?\\..*?\\." | head -1)
if [ -z "$BUNDLE_ID_PREFIX" ]; then
	echo "Could not extract bundle id prefix from $PACKAGE_BUNDLE_ID"
	exit 1
fi

mkdir -p "$BUILD_PATH"
rm -f "$IPA_PATH"
rm -f "$DSYMS_ZIP"
rm -rf "$DSYMS_DIR"
mkdir -p "$DSYMS_DIR"
rm -rf "$TEMP_PATH"

mkdir -p "$TEMP_PATH"
mkdir -p "$TEMP_ENTITLEMENTS_PATH"

if [ "$APP_TYPE" == "wallet" ]; then
	cp "buck-out/gen/Wallet/AppPackage#$PLATFORM_FLAVORS.ipa" "$IPA_PATH.original"
else
	cp "buck-out/gen/Telegram/AppPackage#$PLATFORM_FLAVORS.ipa" "$IPA_PATH.original"
fi
rm -rf "$IPA_PATH.original.unpacked"
rm -f "$BUILD_PATH/${APP_NAME}_signed.ipa"
mkdir -p "$IPA_PATH.original.unpacked"

echo "Unzipping original ipa..."
unzip "$IPA_PATH.original" -d "$IPA_PATH.original.unpacked/" 1>/dev/null
rm "$IPA_PATH.original"

UNPACKED_PATH="$IPA_PATH.original.unpacked"
if [ "$APP_TYPE" == "wallet" ]; then
	APP_PATH="$UNPACKED_PATH/Payload/Wallet.app"
else
	APP_PATH="$UNPACKED_PATH/Payload/Telegram.app"
fi

FRAMEWORKS_DIR="$APP_PATH/Frameworks"

rm -rf "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*
rm -rf "$IPA_PATH.original.unpacked/Symbols/"*
rm -rf "$FRAMEWORKS_DIR/"*

if [ -z "$PACKAGE_METHOD" ]; then
	echo "PACKAGE_METHOD is not set"
	exit 1
fi

if [ "$PACKAGE_METHOD" != "appstore" ] && [ "$PACKAGE_METHOD" != "enterprise" ]; then
	echo "PACKAGE_METHOD $PACKAGE_METHOD should be in [appstore, enterprise]"
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
	exit 1
fi

if [ -z "$CODESIGNING_PROFILES_VARIANT" ]; then
	echo "CODESIGNING_PROFILES_VARIANT is not set"
	exit 1
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

rm -f "$KEYCHAIN_PATH"

if [ "$APP_TYPE" == "wallet" ]; then
	APP_ITEMS_WITH_PROVISIONING_PROFILE="APP"
	APP_ITEMS_WITH_ENTITLEMENTS="APP"
else
	APP_ITEMS_WITH_PROVISIONING_PROFILE="APP EXTENSION_Share EXTENSION_Widget EXTENSION_NotificationService EXTENSION_NotificationContent EXTENSION_Intents WATCH_APP WATCH_EXTENSION"
	APP_ITEMS_WITH_ENTITLEMENTS="APP EXTENSION_Share EXTENSION_Widget EXTENSION_NotificationService EXTENSION_NotificationContent EXTENSION_Intents"
fi

COMMON_IDENTITY_HASH=""

REMOVE_ENTITLEMENT_KEYS=(\
	"com.apple.developer.icloud-container-development-container-identifiers" \
	"com.apple.developer.ubiquity-kvstore-identifier" \
)

COPY_ENTITLEMENT_KEYS=(\
	"com.apple.developer.associated-domains" \
	"com.apple.developer.icloud-services" \
	"com.apple.developer.pushkit.unrestricted-voip" \
)

REPLACE_TO_PRODUCTION_ENTITLEMENT_KEYS=(\
	"com.apple.developer.icloud-container-environment" \
)

echo "Generating entitlements..."
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

			for KEY in "${REMOVE_ENTITLEMENT_KEYS[@]}"; do
	            /usr/libexec/PlistBuddy -c "Delete $KEY" "$PROFILE_ENTITLEMENTS_PATH" 2>/dev/null || true
	        done

	        for KEY in "${REPLACE_TO_PRODUCTION_ENTITLEMENT_KEYS[@]}"; do
	        	VALUE=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$PROFILE_ENTITLEMENTS_PATH" 2>/dev/null || echo "")
				if [ ! -z "$VALUE" ]; then
					PLUTIL_KEY=$(echo "$KEY" | sed 's/\./\\\./g')
					/usr/libexec/PlistBuddy -c "Delete $KEY" "$PROFILE_ENTITLEMENTS_PATH" 2>/dev/null
					VALUE="<array><string>Production</string></array>"
					plutil -insert "$PLUTIL_KEY" -xml "$VALUE" "$PROFILE_ENTITLEMENTS_PATH"
		        fi
	        done

	        if [ "$ENABLE_GET_TASK_ALLOW" == "1" ]; then
	        	KEY="com.apple.security.get-task-allow"
	        	PLUTIL_KEY=$(echo "$KEY" | sed 's/\./\\\./g')
	        	plutil -insert "$PLUTIL_KEY" -xml "<true/>" "$PROFILE_ENTITLEMENTS_PATH"
	        fi

	        ENTITLEMENTS_VAR=PACKAGE_ENTITLEMENTS_$ITEM
			if [ ! -z "${!ENTITLEMENTS_VAR}" ]; then
				if [ ! -f "${!ENTITLEMENTS_VAR}" ]; then
					echo "${!ENTITLEMENTS_VAR} does not exist"
					exit 1	
				fi

				for KEY in "${COPY_ENTITLEMENT_KEYS[@]}"; do
					VALUE=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$PROFILE_ENTITLEMENTS_PATH" 2>/dev/null || echo "")
					if [ ! -z "$VALUE" ]; then
			            PLUTIL_KEY=$(echo "$KEY" | sed 's/\./\\\./g')
			            TEST_VALUE=$(plutil -extract "$PLUTIL_KEY" xml1 -o - "${!ENTITLEMENTS_VAR}" 1>/dev/null || echo "error")
			            if [ "$TEST_VALUE" != "error" ]; then
				            VALUE=$(plutil -extract "$PLUTIL_KEY" xml1 -o - "${!ENTITLEMENTS_VAR}")
				            /usr/libexec/PlistBuddy -c "Delete $KEY" "$PROFILE_ENTITLEMENTS_PATH" 2>/dev/null
				            plutil -insert "$PLUTIL_KEY" -xml "$VALUE" "$PROFILE_ENTITLEMENTS_PATH"
				        fi
			        fi
		        done
			fi
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
done

if [ -z "$COMMON_IDENTITY_HASH" ]; then
	echo "Failed to determine signing identity"
	exit 1
fi

COPY_PLIST_KEYS=(\
	"DTSDKName" \
	"DTXcode" \
	"DTSDKBuild" \
	"CFBundleDevelopmentRegion" \
	"BuildMachineOSBuild" \
	"DTPlatformName" \
	"CFBundleSupportedPlatforms" \
	"CFBundleInfoDictionaryVersion" \
	"DTCompiler" \
	"MinimumOSVersion" \
	"UIDeviceFamily" \
	"DTPlatformVersion" \
	"DTXcodeBuild" \
	"DTPlatformBuild" \
)
APP_PLIST="$APP_PATH/Info.plist"

if [ "$APP_TYPE" == "wallet" ]; then
	APP_BINARY_TARGET="//Wallet:Wallet"
else
	APP_BINARY_TARGET="//Telegram:Telegram"
fi

echo "Repacking frameworks..."
for DEPENDENCY in $(${BUCK} query "kind('apple_library', deps('${APP_BINARY_TARGET}#$PLATFORM_FLAVORS', 1))" "$@"); do
	DEPENDENCY_PATH=$(echo "$DEPENDENCY" | sed -e "s#^//##" | sed -e "s#:#/#")
	DEPENDENCY_NAME=$(echo "$DEPENDENCY" | sed -e "s/#.*//" | sed -e "s/^.*\://")
	DYLIB_PATH="buck-out/gen/$DEPENDENCY_PATH/lib$DEPENDENCY_NAME.dylib"
	mkdir -p "$FRAMEWORKS_DIR/${DEPENDENCY_NAME}.framework"
	TARGET_DYLIB_PATH="$FRAMEWORKS_DIR/${DEPENDENCY_NAME}.framework/$DEPENDENCY_NAME"
	PLIST_FILE="$FRAMEWORKS_DIR/${DEPENDENCY_NAME}.framework/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string \"${DEPENDENCY_NAME}\"" "$PLIST_FILE" 1>/dev/null
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string \"1\"" "$PLIST_FILE"
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string \"1.0\"" "$PLIST_FILE"
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string \"FMWK\"" "$PLIST_FILE"
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string \"${DEPENDENCY_NAME}\"" "$PLIST_FILE"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string \"${BUNDLE_ID_PREFIX}.${DEPENDENCY_NAME}\"" "$PLIST_FILE"
	for KEY in "${COPY_PLIST_KEYS[@]}"; do
		VALUE=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$APP_PLIST" 2>/dev/null || echo "")
		if [ ! -z "$VALUE" ]; then
            PLUTIL_KEY=$(echo "$KEY" | sed 's/\./\\\./g')
            VALUE=$(plutil -extract "$PLUTIL_KEY" xml1 -o - "$APP_PLIST")
            plutil -insert "$PLUTIL_KEY" -xml "$VALUE" "$PLIST_FILE"
        fi
	done
	plutil -convert binary1 "$PLIST_FILE"
	cp "$DYLIB_PATH" "$TARGET_DYLIB_PATH"
	DSYM_PATH="buck-out/gen/$(echo "$DEPENDENCY" | sed -e "s/#/#apple-dsym,/" | sed -e "s#^//##" | sed -e "s#:#/#").dSYM"
	cp -r "$DSYM_PATH" "$DSYMS_DIR/"
done

if [ "$APP_TYPE" == "wallet" ]; then
	APP_BINARY_DSYM_PATH="buck-out/gen/Wallet/Wallet#dwarf-and-dsym,$PLATFORM_FLAVORS,no-include-frameworks/Wallet.app.dSYM"
else
	APP_BINARY_DSYM_PATH="buck-out/gen/Telegram/Telegram#dwarf-and-dsym,$PLATFORM_FLAVORS,no-include-frameworks/Telegram.app.dSYM"
fi
cp -r "$APP_BINARY_DSYM_PATH" "$DSYMS_DIR/"

if [ "$APP_TYPE" == "wallet" ]; then
	EXTENSIONS=""
else
	EXTENSIONS="Share Widget Intents NotificationContent NotificationService"
fi

for EXTENSION in $EXTENSIONS; do
	EXTENSION_DSYM_PATH="buck-out/gen/Telegram/${EXTENSION}Extension#dwarf-and-dsym,$PLATFORM_FLAVORS,no-include-frameworks/${EXTENSION}Extension.appex.dSYM"
	cp -r "$EXTENSION_DSYM_PATH" "$DSYMS_DIR/"
done

if [ "$APP_TYPE" != "wallet" ]; then
	WATCH_EXTENSION_DSYM_PATH="buck-out/gen/Telegram/WatchAppExtension#dwarf-and-dsym,no-include-frameworks,watchos-arm64_32,watchos-armv7k/WatchAppExtension.appex.dSYM"
	cp -r "$WATCH_EXTENSION_DSYM_PATH" "$DSYMS_DIR/"
fi

TEMP_DYLIB_DIR="$TEMP_PATH/SwiftSupport"
rm -rf "$TEMP_DYLIB_DIR"
mkdir -p "$TEMP_DYLIB_DIR"
mkdir -p "$TEMP_DYLIB_DIR/out"

if [ "$APP_TYPE" == "wallet" ]; then
	EXECUTABLE_NAME="Wallet"
else
	EXECUTABLE_NAME="Telegram"
fi

XCODE_PATH="$(xcode-select -p)"
TOOLCHAIN_PATH="$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain"

if [ -f "$TOOLCHAIN_PATH/usr/lib/swift/iphoneos/libswiftCore.dylib" ]; then
	SOURCE_LIBRARIES_PATH="$TOOLCHAIN_PATH/usr/lib/swift/iphoneos"
else
	SOURCE_LIBRARIES_PATH="$TOOLCHAIN_PATH/usr/lib/swift-5.0/iphoneos"
fi

echo "Copying swift support files..."
xcrun swift-stdlib-tool \
	--copy \
	--strip-bitcode \
	--platform iphoneos \
	--toolchain "$TOOLCHAIN_PATH" \
	--source-libraries "$SOURCE_LIBRARIES_PATH" \
	--scan-executable "$APP_PATH/$EXECUTABLE_NAME" \
	--scan-folder "$APP_PATH/Frameworks" \
	--scan-folder "$APP_PATH/PlugIns" \
	--destination "$TEMP_DYLIB_DIR"

for dylib in "$TEMP_DYLIB_DIR"/*.dylib; do
	FILE_NAME=$(basename "$dylib")
	lipo -extract armv7 "$dylib" -output "$dylib.armv7"
	lipo -extract arm64 "$dylib" -output "$dylib.arm64"
	lipo "$dylib.armv7" "$dylib.arm64" -create -output "$dylib.unstripped"
	if [ "$PACKAGE_METHOD" == "enterprise" ]; then
		xcrun strip -ST -o "$TEMP_DYLIB_DIR/out/$FILE_NAME" - "$dylib.unstripped" 2>/dev/null
		xcrun bitcode_strip -r "$TEMP_DYLIB_DIR/out/$FILE_NAME" -o "$TEMP_DYLIB_DIR/out/$FILE_NAME" 1>/dev/null
	else
		cp "$dylib.unstripped" "$TEMP_DYLIB_DIR/out/$FILE_NAME"
	fi
done

cp "$TEMP_DYLIB_DIR/out/"*.dylib "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"
cp "$IPA_PATH.original.unpacked/SwiftSupport/iphoneos/"*.dylib "$FRAMEWORKS_DIR/"

REMOVE_ARCHS="armv7s arm64e"

for framework in "$FRAMEWORKS_DIR"/*; do
    if [[ "$framework" == *.framework || "$framework" == *.dylib ]]; then
		if [[ "$framework" == *.framework ]]; then
			FRAMEWORK_NAME=$(basename "$framework" | sed -e 's/\.framework//')
			for ARCH in $REMOVE_ARCHS; do
				lipo -remove "$ARCH" "$framework/$FRAMEWORK_NAME" -o "$framework/$FRAMEWORK_NAME" 2>/dev/null || true
			done
			xcrun bitcode_strip -r "$framework/$FRAMEWORK_NAME" -o "$framework/$FRAMEWORK_NAME" 1>/dev/null
			xcrun strip -S -T -x "$framework/$FRAMEWORK_NAME" 1>/dev/null
			/usr/bin/codesign ${VERBOSE} ${KEYCHAIN_FLAG} -f -s "$COMMON_IDENTITY_HASH" "$framework" 1>/dev/null
		else
			/usr/bin/codesign ${VERBOSE} ${KEYCHAIN_FLAG} -f -s "$COMMON_IDENTITY_HASH" "$framework" 1>/dev/null
		fi
    fi
done

echo "Signing..."

if [ "$APP_TYPE" == "wallet" ]; then
	PLUGINS=""
else
	PLUGINS="Share Widget Intents NotificationService NotificationContent"
fi

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

if [ "$APP_TYPE" != "wallet" ]; then
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
	/usr/bin/codesign ${VERBOSE} -f -s "$COMMON_IDENTITY_HASH" --entitlements "${!WATCH_EXTENSION_ENTITLEMENTS_PATH_VAR}" "$WATCH_EXTENSION_PATH" 2>/dev/null

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
	/usr/bin/codesign ${VERBOSE} -f -s "$COMMON_IDENTITY_HASH" --entitlements "${!WATCH_APP_ENTITLEMENTS_PATH_VAR}" "$WATCH_APP_PATH" 2>/dev/null
fi

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
if [ "$PACKAGE_METHOD" == "appstore" ]; then
	zip -r "../${APP_NAME}_signed.ipa" Payload SwiftSupport WatchKitSupport2 1>/dev/null
elif [ "$PACKAGE_METHOD" == "enterprise" ]; then
	zip -r "../${APP_NAME}_signed.ipa" Payload 1>/dev/null
fi
cd "$DIR"

cd "$BUILD_PATH"
zip -r "$DSYMS_FOLDER_NAME.zip" "$DSYMS_FOLDER_NAME" 1>/dev/null

cd "$DIR"

echo "Done"