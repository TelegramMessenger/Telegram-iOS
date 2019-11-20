#!/bin/bash

set -e
set -x

CONFIGURATION="$1"

if [ -z "$CONFIGURATION" ]; then
	echo "Usage: sh deploy-telegram.sh CONFIGURATION"
	exit 1
fi

OUTPUT_PATH="build/artifacts"

if [ "$CONFIGURATION" == "appstore" ]; then
	IPA_PATH="$OUTPUT_PATH/Telegram.ipa"
else
	echo "Unknown configuration $CONFIGURATION"
	exit 1
fi

if [ ! -f "$IPA_PATH" ]; then
	echo "$IPA_PATH not found"
	exit 1
fi

VERIFY_PATH="TelegramVerifyBuild.ipa"

mv "$IPA_PATH" "$VERIFY_PATH"

BUCK_HTTP_CACHE="" sh buildbox/build-telegram.sh verify

python3 tools/ipadiff.py "$IPA_PATH" "$VERIFY_PATH"
