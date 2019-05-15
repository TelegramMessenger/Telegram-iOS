#!/bin/sh

set -e

BUILD_TELEGRAM_VERSION="1"

if [ `which cleanup-telegram-build-vms.sh` ]; then
	cleanup-telegram-build-vms.sh
fi

BUILDBOX_DIR="buildbox"

mkdir -p "$BUILDBOX_DIR/transient-data"

BUILD_CONFIGURATION="$1"

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ]; then
	CODESIGNING_SUBPATH="transient-data/codesigning"
elif [ "$BUILD_CONFIGURATION" == "appstore" ]; then
	CODESIGNING_SUBPATH="transient-data/codesigning"
elif [ "$BUILD_CONFIGURATION" == "verify" ]; then
	CODESIGNING_SUBPATH="fake-codesigning"
else
	echo "Unknown configuration $1"
	exit 1
fi

BASE_DIR=$(pwd)

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ] || [ "$BUILD_CONFIGURATION" == "appstore" ]; then
	if [ ! `which setup-telegram-build.sh` ]; then
		echo "setup-telegram-build.sh not found in PATH $PATH"
		exit 1
	fi
	source `which setup-telegram-build.sh`
	setup_telegram_build "$BUILD_CONFIGURATION" "$BASE_DIR/$BUILDBOX_DIR/transient-data"
	if [ "$SETUP_TELEGRAM_BUILD_VERSION" != "$BUILD_TELEGRAM_VERSION" ]; then
		echo "setup-telegram-build.sh script version doesn't match"
		exit 1
	fi
	if [ "$BUILD_CONFIGURATION" == "appstore" ]; then
		if [ -z "$TELEGRAM_BUILD_APPSTORE_PASSWORD" ]; then
			echo "TELEGRAM_BUILD_APPSTORE_PASSWORD is not set"
			exit 1
		fi
		if [ -z "$TELEGRAM_BUILD_APPSTORE_TEAM_NAME" ]; then
			echo "TELEGRAM_BUILD_APPSTORE_TEAM_NAME is not set"
			exit 1
		fi
	fi
fi

if [ ! -d "$BUILDBOX_DIR/$CODESIGNING_SUBPATH" ]; then
	echo "$BUILDBOX_DIR/$CODESIGNING_SUBPATH does not exist"
	exit 1
fi

SOURCE_DIR=$(basename "$BASE_DIR")
cd ..
rm -f "$SOURCE_DIR/$BUILDBOX_DIR/transient-data/source.tar"
tar cf "$SOURCE_DIR/$BUILDBOX_DIR/transient-data/source.tar" --exclude "$SOURCE_DIR/$BUILDBOX_DIR" "$SOURCE_DIR"
cd "$BASE_DIR"

VM_BASE_NAME="macos10_14_3_Xcode10_1"

SNAPSHOT_ID=$(prlctl snapshot-list "$VM_BASE_NAME" | grep -Eo '\{(\d|[a-f]|-)*\}' | tr '\n' '\0')

if [ -z "$SNAPSHOT_ID" ]; then
	echo "$VM_BASE_NAME is required to have one snapshot"
	exit 1
fi

PROCESS_ID="$$"
VM_NAME="$VM_BASE_NAME-$(openssl rand -hex 10)-build-telegram-$PROCESS_ID"

prlctl clone "$VM_BASE_NAME" --name "$VM_NAME"
prlctl snapshot-switch "$VM_NAME" -i "$SNAPSHOT_ID"

VM_IP=$(prlctl exec "$VM_NAME" "ifconfig | grep inet | grep broadcast | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | tr '\n' '\0'")

scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/$CODESIGNING_SUBPATH" telegram@"$VM_IP":codesigning_data

if [ "$BUILD_CONFIGURATION" == "verify" ]; then
	ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "mkdir -p telegram-ios-shared/fastlane; echo '' > telegram-ios-shared/fastlane/Fastfile"
else
	scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/transient-data/telegram-ios-shared" telegram@"$VM_IP":telegram-ios-shared
fi
scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/guest-build-telegram.sh" "$BUILDBOX_DIR/transient-data/source.tar" telegram@"$VM_IP":

ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "export TELEGRAM_BUILD_APPSTORE_PASSWORD=\"$TELEGRAM_BUILD_APPSTORE_PASSWORD\"; export TELEGRAM_BUILD_APPSTORE_TEAM_NAME=\"$TELEGRAM_BUILD_APPSTORE_TEAM_NAME\"; bash -l guest-build-telegram.sh $BUILD_CONFIGURATION" || true

if [ "$BUILD_CONFIGURATION" == "appstore" ]; then
	ARCHIVE_PATH="$HOME/telegram-builds-archive"
	DATE_PATH=$(date +%Y-%m-%d_%H-%M-%S)
	ARCHIVE_BUILD_PATH="$ARCHIVE_PATH/$DATE_PATH"
	mkdir -p "$ARCHIVE_PATH"
	mkdir -p "$ARCHIVE_BUILD_PATH"
	APPSTORE_IPA="Telegram-iOS-AppStoreLLC.ipa"
	APPSTORE_DSYM_ZIP="Telegram-iOS-AppStoreLLC.app.dSYM.zip"
	APPSTORE_TARGET_IPA="$ARCHIVE_BUILD_PATH/Telegram-iOS-AppStoreLLC.ipa"
	APPSTORE_TARGET_DSYM_ZIP="$ARCHIVE_BUILD_PATH/Telegram-iOS-AppStoreLLC.app.dSYM.zip"

	scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr telegram@"$VM_IP":"telegram-ios/*.ipa" "$ARCHIVE_BUILD_PATH/"
	scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr telegram@"$VM_IP":"telegram-ios/*.zip" "$ARCHIVE_BUILD_PATH/"
elif [ "$BUILD_CONFIGURATION" == "verify" ]; then
	VERIFY_IPA="Telegram-Verify-Build.ipa"
	rm -f "$VERIFY_IPA"
	scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr telegram@"$VM_IP":telegram-ios/Telegram-iOS-AppStoreLLC.ipa "./$VERIFY_IPA"
fi

prlctl stop "$VM_NAME" --kill
prlctl delete "$VM_NAME"
