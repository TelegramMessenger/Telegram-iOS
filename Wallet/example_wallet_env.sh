#!/bin/bash

custom_realpath() {
	OURPWD=$PWD
	cd "$(dirname "$1")"
	LINK=$(readlink "$(basename "$1")")
	while [ "$LINK" ]; do
		cd "$(dirname "$LINK")"
		LINK=$(readlink "$(basename "$1")")
	done
	REALPATH="$PWD/$(basename "$1")"
	cd "$OURPWD"
	echo "$REALPATH"
}

export TELEGRAM_ENV_SET="1"

export HOCKEYAPP_ID=""
export IS_INTERNAL_BUILD="false"
export IS_APPSTORE_BUILD="true"
export APPSTORE_ID="1"
export APP_SPECIFIC_URL_SCHEME=""
export API_ID="0"
export API_HASH=""

if [ -z "$DEVELOPMENT_CODE_SIGN_IDENTITY" ]; then
	export DEVELOPMENT_CODE_SIGN_IDENTITY="iPhone Developer: AAAAA AAAAA (XXXXXXXXXX)"
fi
if [ -z "$DISTRIBUTION_CODE_SIGN_IDENTITY" ]; then
	export DISTRIBUTION_CODE_SIGN_IDENTITY="iPhone Distribution: AAAAA AAAAA (XXXXXXXXXX)"
fi
if [ -z "$DEVELOPMENT_TEAM" ]; then
	export DEVELOPMENT_TEAM="XXXXXXXXXX"
fi

if [ -z "$WALLET_BUNDLE_ID" ]; then
	export WALLET_BUNDLE_ID="reverse.dns.notation"
fi

if [ -z "$BUILD_NUMBER" ]; then
	echo "BUILD_NUMBER is not defined"
	exit 1
fi

export WALLET_ENTITLEMENTS_APP="Wallet.entitlements"
if [ -z "$WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP" ]; then
	export WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP="development profile name"
fi
if [ -z "$WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP" ]; then
	export WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP="distribution profile name"
fi

BASE_DIR="$(custom_realpath .)"
BASE_PATH=$(dirname "$(custom_realpath $0)")
BUILDBOX_DIR="buildbox"

if [ -z "$CODESIGNING_SOURCE_DATA_PATH" ]; then
	echo "CODESIGNING_SOURCE_DATA_PATH is not defined"
	exit 1
fi

if [ ! -d "$CODESIGNING_SOURCE_DATA_PATH/profiles" ]; then
	echo "Expected codesigning directory layout:"
	echo "$CODESIGNING_SOURCE_DATA_PATH/profiles/appstore/*.mobileprovision"
	exit 1
fi

rm -rf "$BASE_DIR/$BUILDBOX_DIR/transient-data/teams/$DEVELOPMENT_TEAM/codesigning"
mkdir -p "$BASE_DIR/$BUILDBOX_DIR/transient-data/teams/$DEVELOPMENT_TEAM/codesigning"
cp -R "$CODESIGNING_SOURCE_DATA_PATH/"* "$BASE_DIR/$BUILDBOX_DIR/transient-data/teams/$DEVELOPMENT_TEAM/codesigning/"

export CODESIGNING_DATA_PATH="$BUILDBOX_DIR/transient-data/teams/$DEVELOPMENT_TEAM/codesigning"
export CODESIGNING_CERTS_VARIANT="distribution"
export CODESIGNING_PROFILES_VARIANT="appstore"
export PACKAGE_METHOD="appstore"

$@
