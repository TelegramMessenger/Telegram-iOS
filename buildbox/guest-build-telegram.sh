#!/bin/sh

if [ "$1" == "hockeyapp" ]; then
	FASTLANE_BUILD_CONFIGURATION="internalhockeyapp"
elif [ "$1" == "appstore" ]; then
	FASTLANE_BUILD_CONFIGURATION="testflight_llc"
elif [ "$1" == "verify" ]; then
	FASTLANE_BUILD_CONFIGURATION="build_for_appstore"
else
	echo "Unknown configuration $1"
	exit 1
fi

security unlock-keychain -p telegram
security set-keychain-settings -lut 7200

CERTS_PATH="codesigning_data/certs"
for f in $(ls "$CERTS_PATH"); do
	fastlane run import_certificate "certificate_path:$CERTS_PATH/$f" keychain_name:login keychain_password:telegram log_output:true
done

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"

PROFILES_PATH="codesigning_data/profiles"
for f in $(ls "$PROFILES_PATH"); do
	PROFILE_PATH="$PROFILES_PATH/$f"
	uuid=`grep UUID -A1 -a "$PROFILE_PATH" | grep -io "[-A-F0-9]\{36\}"`
	cp "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
done

SOURCE_PATH="telegram-ios"

if [ -d "$SOURCE_PATH" ]; then
	echo "$SOURCE_PATH must not exist"
	exit 1
fi

echo "Unpacking files..."
tar -xf "source.tar"

cd "$SOURCE_PATH"
fastlane "$FASTLANE_BUILD_CONFIGURATION"
