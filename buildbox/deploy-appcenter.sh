#!/bin/bash

set -e
set -x

IPA_PATH="build/artifacts/Telegram.ipa"
DSYM_PATH="build/artifacts/Telegram.DSYMs.zip"

APPCENTER="/usr/local/bin/appcenter"

$APPCENTER login --token "$API_TOKEN"

NEXT_WAIT_TIME=0
until [ $NEXT_WAIT_TIME -eq 5 ] || $APPCENTER distribute release --app "$API_USER_NAME/$API_APP_NAME" -f "$IPA_PATH" -g Internal; do
    sleep $(( NEXT_WAIT_TIME++ ))
done
[ $NEXT_WAIT_TIME -lt 10 ]

$APPCENTER crashes upload-symbols --app "$API_USER_NAME/$API_APP_NAME" --symbol "$DSYM_PATH"
