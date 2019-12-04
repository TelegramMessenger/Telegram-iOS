#!/bin/sh

set -x

if [ -z "BUILD_NUMBER" ]; then
	echo "BUILD_NUMBER is not set"
	exit 1
fi

if [ -z "COMMIT_ID" ]; then
	echo "COMMIT_ID is not set"
	exit 1
fi

if [ "$1" == "hockeyapp" ] || [ "$1" == "testinghockeyapp" ]; then
	CERTS_PATH="$HOME/codesigning_data/certs"
	PROFILES_PATH="$HOME/codesigning_data/profiles"
elif [ "$1" == "testinghockeyapp-local" ]; then
	CERTS_PATH="$HOME/codesigning_data/certs"
	PROFILES_PATH="$HOME/codesigning_data/profiles"
elif [ "$1" == "appstore" ]; then
	if [ -z "$TELEGRAM_BUILD_APPSTORE_PASSWORD" ]; then
		echo "TELEGRAM_BUILD_APPSTORE_PASSWORD is not set"
		exit 1
	fi
	if [ -z "$TELEGRAM_BUILD_APPSTORE_TEAM_NAME" ]; then
		echo "TELEGRAM_BUILD_APPSTORE_TEAM_NAME is not set"
		exit 1
	fi
	CERTS_PATH="$HOME/codesigning_data/certs"
	PROFILES_PATH="$HOME/codesigning_data/profiles"
elif [ "$1" == "verify" ]; then
	CERTS_PATH="build-system/fake-codesigning/certs/distribution"
	PROFILES_PATH="build-system/fake-codesigning/profiles"
else
	echo "Unknown configuration $1"
	exit 1
fi

MY_KEYCHAIN="temp.keychain"
MY_KEYCHAIN_PASSWORD="secret"

if [ ! -z "$(security list-keychains | grep "$MY_KEYCHAIN")" ]; then
	security delete-keychain "$MY_KEYCHAIN" || true
fi
security create-keychain -p "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"
security list-keychains -d user -s "$MY_KEYCHAIN" $(security list-keychains -d user | sed s/\"//g)
security set-keychain-settings "$MY_KEYCHAIN"
security unlock-keychain -p "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"

SOURCE_PATH="telegram-ios"

if [ -d "$SOURCE_PATH" ]; then
	echo "Directory $SOURCE_PATH should not exist"
	exit 1
fi

mkdir "$SOURCE_PATH"

if [ "$1" != "verify" ]; then
	SIZE_IN_BLOCKS=$((12*1024*1024*1024/512))
	DEV=`hdid -nomount ram://$SIZE_IN_BLOCKS`

	if [ $? -eq 0 ]; then
		newfs_hfs -v 'ram disk' $DEV
		eval `/usr/bin/stat -s "$SOURCE_PATH"`
		mount -t hfs -o union -o nobrowse -o nodev -o noatime $DEV "$SOURCE_PATH"
		chown $st_uid:$st_gid "$SOURCE_PATH"
		chmod $st_mode "$SOURCE_PATH"
	else
		echo "Error creating ramdisk"
		exit 1
	fi
fi

echo "Unpacking files..."

mkdir -p "$SOURCE_PATH/buildbox"
mkdir -p "$SOURCE_PATH/buildbox/transient-data"
cp -r "$HOME/codesigning_teams" "$SOURCE_PATH/buildbox/transient-data/teams"

BASE_DIR=$(pwd)
cd "$SOURCE_PATH"
tar -xf "../source.tar"

for f in $(ls "$CERTS_PATH"); do
	security import "$CERTS_PATH/$f" -k "$MY_KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security
done

security set-key-partition-list -S apple-tool:,apple: -k "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"

for f in $(ls "$PROFILES_PATH"); do
	PROFILE_PATH="$PROFILES_PATH/$f"
	uuid=`grep UUID -A1 -a "$PROFILE_PATH" | grep -io "[-A-F0-9]\{36\}"`
	cp -f "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
done

if [ "$1" == "hockeyapp" ]; then
	BUILD_ENV_SCRIPT="../telegram-ios-shared/buildbox/bin/internal.sh"
	APP_TARGET="app_arm64"
elif [ "$1" == "appstore" ]; then
	BUILD_ENV_SCRIPT="../telegram-ios-shared/buildbox/bin/appstore.sh"
	APP_TARGET="app"
elif [ "$1" == "verify" ]; then
	BUILD_ENV_SCRIPT="build-system/verify.sh"
	APP_TARGET="app"
	export CODESIGNING_DATA_PATH="build-system/fake-codesigning"
	export CODESIGNING_CERTS_VARIANT="distribution"
	export CODESIGNING_PROFILES_VARIANT="appstore"
else
	echo "Unsupported configuration $1"
	exit 1
fi

if [ -d "$BUCK_DIR_CACHE" ]; then
	sudo chown telegram "$BUCK_DIR_CACHE"
fi

BUCK="$(pwd)/tools/buck" BUCK_HTTP_CACHE="$BUCK_HTTP_CACHE" BUCK_CACHE_MODE="$BUCK_CACHE_MODE" BUCK_DIR_CACHE="$BUCK_DIR_CACHE" LOCAL_CODESIGNING=1 sh "$BUILD_ENV_SCRIPT" make "$APP_TARGET"

OUTPUT_PATH="build/artifacts"
rm -rf "$OUTPUT_PATH"
mkdir -p "$OUTPUT_PATH"

cp "build/Telegram_signed.ipa" "./$OUTPUT_PATH/Telegram.ipa"
cp "build/DSYMs.zip" "./$OUTPUT_PATH/Telegram.DSYMs.zip"

cd "$BASE_DIR"
