#!/bin/bash

set -e

CONFIGURATION="$1"

if [ -z "$CONFIGURATION" ]; then
	echo "Usage: sh deploy-telegram.sh CONFIGURATION"
	exit 1
fi

if [ "$CONFIGURATION" == "hockeyapp" ]; then
	echo "$CONFIGURATION"
elif [ "$CONFIGURATION" == "appstore" ]; then
	echo "$CONFIGURATION"
else
	echo "Unknown configuration $CONFIGURATION"
	exit 1
fi

OUTPUT_PATH="build/artifacts"
IPA_PATH="$OUTPUT_PATH/Telegram.ipa"
DSYM_PATH="$OUTPUT_PATH/Telegram.DSYMs.zip"

if [ ! -f "$IPA_PATH" ]; then
	echo "$IPA_PATH not found"
	exit 1
fi

if [ ! -f "$DSYM_PATH" ]; then
	echo "$DSYM_PATH not found"
	exit 1
fi
