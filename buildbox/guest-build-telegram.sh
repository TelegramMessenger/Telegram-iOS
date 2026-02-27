#!/bin/sh

set -x

if [ -z "BUILD_NUMBER" ]; then
	echo "BUILD_NUMBER is not set"
	exit 1
fi

if [ "$1" == "hockeyapp" ] || [ "$1" == "appcenter-experimental" ] || [ "$1" == "appcenter-experimental-2" ] || [ "$1" == "testinghockeyapp" ]; then
	CERTS_PATH="$HOME/codesigning_data/certs/enterprise"
elif [ "$1" == "testinghockeyapp-local" ]; then
	CERTS_PATH="$HOME/codesigning_data/certs/enterprise"
elif [ "$1" == "appstore" ]; then
	CERTS_PATH="$HOME/codesigning_data/certs/distribution"
elif [ "$1" == "appstore-development" ]; then
	CERTS_PATH="$HOME/codesigning_data/certs/development"
elif [ "$1" == "verify" ]; then
	CERTS_PATH="$HOME/codesigning_data/certs/distribution"
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

USE_RAMDISK="0"

if [ "$USE_RAMDISK" == "1" ]; then
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
#cp -r "$HOME/codesigning_teams" "$SOURCE_PATH/buildbox/transient-data/teams"

BASE_DIR=$(pwd)
cd "$SOURCE_PATH"
tar -xf "../source.tar"

for f in "$CERTS_PATH"/*.p12; do
	security import "$f" -k "$MY_KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security
done

for f in "$CERTS_PATH"/*.cer; do
	#sudo security add-trusted-cert -d -r trustRoot -p codeSign -k "$MY_KEYCHAIN" "$f"
	security import "$f" -k "$MY_KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security
done

security import "build-system/AppleWWDRCAG3.cer" -k "$MY_KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security

security set-key-partition-list -S apple-tool:,apple: -k "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"

if [ "$1" == "hockeyapp" ] || [ "$1" == "appcenter-experimental" ] || [ "$1" == "appcenter-experimental-2" ] || [ "$1" == "appstore-development" ]; then
	APP_CONFIGURATION="release_arm64"
elif [ "$1" == "appstore" ]; then
	APP_CONFIGURATION="release_universal"
elif [ "$1" == "verify" ]; then
	APP_CONFIGURATION="release_universal"
else
	echo "Unsupported configuration $1"
	exit 1
fi

python3 build-system/Make/Make.py \
    --bazel="$(pwd)/tools/bazel" \
    --cacheHost="$BAZEL_HTTP_CACHE_URL" \
    build \
    --configurationPath="$HOME/telegram-configuration" \
    --buildNumber="$BUILD_NUMBER" \
    --disableParallelSwiftmoduleGeneration \
    --configuration="$APP_CONFIGURATION" \
    --apsEnvironment=production

OUTPUT_PATH="build/artifacts"
rm -rf "$OUTPUT_PATH"
mkdir -p "$OUTPUT_PATH"

for f in bazel-out/applebin_ios-ios_arm*-opt-ST-*/bin/Telegram/Telegram.ipa; do
	cp "$f" $OUTPUT_PATH/
done

mkdir -p build/DSYMs
for f in bazel-out/applebin_ios-ios_arm*-opt-ST-*/bin/Telegram/*.dSYM; do
	cp -R "$f" build/DSYMs/
done

zip -r "./$OUTPUT_PATH/Telegram.DSYMs.zip" build/DSYMs 1>/dev/null

cd "$BASE_DIR"
