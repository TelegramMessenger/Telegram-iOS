#!/bin/sh

if [ -z "BUILD_NUMBER" ]; then
	echo "BUILD_NUMBER is not set"
	exit 1
fi

if [ -z "COMMIT_ID" ]; then
	echo "COMMIT_ID is not set"
	exit 1
fi

if [ "$1" == "hockeyapp" ]; then
	FASTLANE_BUILD_CONFIGURATION="internalhockeyapp"
	CERTS_PATH="codesigning_data/certs"
	PROFILES_PATH="codesigning_data/profiles"
elif [ "$1" == "appstore" ]; then
	FASTLANE_BUILD_CONFIGURATION="testflight_llc"
	if [ -z "$TELEGRAM_BUILD_APPSTORE_PASSWORD" ]; then
		echo "TELEGRAM_BUILD_APPSTORE_PASSWORD is not set"
		exit 1
	fi
	if [ -z "$TELEGRAM_BUILD_APPSTORE_TEAM_NAME" ]; then
		echo "TELEGRAM_BUILD_APPSTORE_TEAM_NAME is not set"
		exit 1
	fi
	FASTLANE_PASSWORD="$TELEGRAM_BUILD_APPSTORE_PASSWORD"
	FASTLANE_ITC_TEAM_NAME="$TELEGRAM_BUILD_APPSTORE_TEAM_NAME"
	CERTS_PATH="codesigning_data/certs"
	PROFILES_PATH="codesigning_data/profiles"
elif [ "$1" == "verify" ]; then
	FASTLANE_BUILD_CONFIGURATION="build_for_appstore"
	CERTS_PATH="codesigning_data/certs"
	PROFILES_PATH="codesigning_data/profiles"
elif [ "$1" == "verify-local" ]; then
	FASTLANE_BUILD_CONFIGURATION="build_for_appstore"
	CERTS_PATH="buildbox/fake-codesigning/certs"
	PROFILES_PATH="buildbox/fake-codesigning/profiles"
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

for f in $(ls "$CERTS_PATH"); do
	fastlane run import_certificate "certificate_path:$CERTS_PATH/$f" keychain_name:"$MY_KEYCHAIN" keychain_password:"$MY_KEYCHAIN_PASSWORD" log_output:true
done

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"

for f in $(ls "$PROFILES_PATH"); do
	PROFILE_PATH="$PROFILES_PATH/$f"
	uuid=`grep UUID -A1 -a "$PROFILE_PATH" | grep -io "[-A-F0-9]\{36\}"`
	cp -f "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
done

if [ "$1" == "verify-local" ]; then
	fastlane "$FASTLANE_BUILD_CONFIGURATION"
else
	SOURCE_PATH="telegram-ios"

	if [ -d "$SOURCE_PATH" ]; then
		echo "Directory $SOURCE_PATH should not exist"
		exit 1
	fi

	mkdir "$SOURCE_PATH"


	SIZE_IN_BLOCKS=$((10*1024*1024*1024/512))
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

	echo "Unpacking files..."
	mkdir "$SOURCE_PATH"
	BASE_DIR=$(pwd)
	cd "$SOURCE_PATH"
	tar -xf "../source.tar"

	FASTLANE_PASSWORD="$FASTLANE_PASSWORD" FASTLANE_ITC_TEAM_NAME="$FASTLANE_ITC_TEAM_NAME" fastlane "$FASTLANE_BUILD_CONFIGURATION" build_number:"$BUILD_NUMBER" commit_hash:"$COMMIT_ID" commit_author:"$COMMIT_AUTHOR"

	cd "$BASE_DIR"
	umount -f "$SOURCE_PATH"
	hdiutil detach "$DEV"
fi
