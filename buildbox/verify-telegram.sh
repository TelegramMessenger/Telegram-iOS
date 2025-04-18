#!/bin/bash

set -e
set -x

CONFIGURATION="$1"
MODE="$2"

if [ -z "$CONFIGURATION" ] || [ -z "$MODE" ] ; then
	echo "Usage: sh deploy-telegram.sh CONFIGURATION [cached|full]"
	exit 1
fi

if [ "$MODE" == "cached" ]; then
	BAZEL_HTTP_CACHE_URL="$BAZEL_HTTP_CACHE_URL"
	ERROR_OUTPUT_PATH="build/verifysanity_artifacts"
elif [ "$MODE" == "full" ]; then
	BAZEL_HTTP_CACHE_URL=""
	ERROR_OUTPUT_PATH="build/verify_artifacts"
else
	echo "Unknown mode $MODE"
	exit 1
fi

OUTPUT_PATH="build/artifacts"

if [ "$CONFIGURATION" == "appstore" ]; then
	if [ -z "$IPA_PATH" ]; then
		IPA_PATH="$OUTPUT_PATH/Telegram.ipa"
	fi
else
	echo "Unknown configuration $CONFIGURATION"
	exit 1
fi

if [ ! -f "$IPA_PATH" ]; then
	echo "$IPA_PATH not found"
	exit 1
fi

VERIFY_PATH="TelegramVerifyBuild.ipa"

rm -f "$VERIFY_PATH"
cp "$IPA_PATH" "$VERIFY_PATH"

BAZEL_HTTP_CACHE_URL="$BAZEL_HTTP_CACHE_URL" sh buildbox/build-telegram.sh verify

python3 tools/ipadiff.py "$IPA_PATH" "$VERIFY_PATH"
retVal=$?
if [ $retVal -ne 0 ]; then
    mkdir -p "$ERROR_OUTPUT_PATH"
    cp "$IPA_PATH" "$ERROR_OUTPUT_PATH"/
    exit 1
fi


