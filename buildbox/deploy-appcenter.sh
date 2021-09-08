#!/bin/bash

set -e
set -x

IPA_PATH="build/artifacts/Telegram.ipa"
DSYM_PATH="build/artifacts/Telegram.DSYMs.zip"

APPCENTER="/usr/local/bin/appcenter"

$APPCENTER login --token "$API_TOKEN"
$APPCENTER distribute release --app "$API_USER_NAME/$API_APP_NAME" -f "$IPA_PATH" -g Internal
$APPCENTER crashes upload-symbols --app "$API_USER_NAME/$API_APP_NAME" --symbol "$DSYM_PATH"
