#!/bin/bash

export TELEGRAM_ENV_SET="1"

export DEVELOPMENT_CODE_SIGN_IDENTITY="iPhone Distribution: Digital Fortress LLC (C67CF9S4VU)"
export DISTRIBUTION_CODE_SIGN_IDENTITY="iPhone Distribution: Digital Fortress LLC (C67CF9S4VU)"
export DEVELOPMENT_TEAM="C67CF9S4VU"

export API_ID="8"
export API_HASH="7245de8e747a0d6fbe11f7cc14fcc0bb"

export BUNDLE_ID="ph.telegra.Telegraph"
export APP_CENTER_ID=""
export IS_INTERNAL_BUILD="false"
export IS_APPSTORE_BUILD="true"
export APPSTORE_ID="686449807"
export APP_SPECIFIC_URL_SCHEME="tgapp"

if [ -z "$BUILD_NUMBER" ]; then
	echo "BUILD_NUMBER is not defined"
	exit 1
fi

export ENTITLEMENTS_APP="Telegram/Telegram-iOS/Telegram-iOS-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_APP="match Development ph.telegra.Telegraph"
export DISTRIBUTION_PROVISIONING_PROFILE_APP="match AppStore ph.telegra.Telegraph"
export ENTITLEMENTS_EXTENSION_SHARE="Telegram/Share/Share-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_SHARE="match Development ph.telegra.Telegraph.Share"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_SHARE="match AppStore ph.telegra.Telegraph.Share"
export ENTITLEMENTS_EXTENSION_WIDGET="Telegram/Widget/Widget-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_WIDGET="match Development ph.telegra.Telegraph.Widget"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_WIDGET="match AppStore ph.telegra.Telegraph.Widget"
export ENTITLEMENTS_EXTENSION_NOTIFICATIONSERVICE="Telegram/NotificationService/NotificationService-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE="match Development ph.telegra.Telegraph.NotificationService"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE="match AppStore ph.telegra.Telegraph.NotificationService"
export ENTITLEMENTS_EXTENSION_NOTIFICATIONCONTENT="Telegram/NotificationContent/NotificationContent-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT="match Development ph.telegra.Telegraph.NotificationContent"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT="match AppStore ph.telegra.Telegraph.NotificationContent"
export ENTITLEMENTS_EXTENSION_INTENTS="Telegram/SiriIntents/SiriIntents-AppStoreLLC.entitlements"
export DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_INTENTS="match Development ph.telegra.Telegraph.SiriIntents"
export DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_INTENTS="match AppStore ph.telegra.Telegraph.SiriIntents"
export DEVELOPMENT_PROVISIONING_PROFILE_WATCH_APP="match Development ph.telegra.Telegraph.watchkitapp"
export DISTRIBUTION_PROVISIONING_PROFILE_WATCH_APP="match AppStore ph.telegra.Telegraph.watchkitapp"
export DEVELOPMENT_PROVISIONING_PROFILE_WATCH_EXTENSION="match Development ph.telegra.Telegraph.watchkitapp.watchkitextension"
export DISTRIBUTION_PROVISIONING_PROFILE_WATCH_EXTENSION="match AppStore ph.telegra.Telegraph.watchkitapp.watchkitextension"

BUILDBOX_DIR="buildbox"

export CODESIGNING_PROFILES_VARIANT="appstore"
export PACKAGE_METHOD="appstore"

$@
