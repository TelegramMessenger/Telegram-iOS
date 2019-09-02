.PHONY : check_env build build_arm64 package_arm64 app_arm64 build_buckdebug build_verbose kill_xcode clean project project_buckdebug

BUCK_OPTIONS=\
	--config custom.developmentCodeSignIdentity="${DEVELOPMENT_CODE_SIGN_IDENTITY}" \
	--config custom.distributionCodeSignIdentity="${DISTRIBUTION_CODE_SIGN_IDENTITY}" \
	--config custom.developmentTeam="${DEVELOPMENT_TEAM}" \
	--config custom.baseApplicationBundleId="${BUNDLE_ID}" \
	--config custom.apiId="${API_ID}" \
	--config custom.apiHash="${API_HASH}" \
	--config custom.hockeyAppId="${HOCKEYAPP_ID}" \
	--config custom.isInternalBuild="${IS_INTERNAL_BUILD}" \
	--config custom.isAppStoreBuild="${IS_APPSTORE_BUILD}" \
	--config custom.appStoreId="${APPSTORE_ID}" \
	--config custom.appSpecificUrlScheme="${APP_SPECIFIC_URL_SCHEME}" \
	--config custom.buildNumber="${BUILD_NUMBER}" \
	--config custom.entitlementsApp="${ENTITLEMENTS_APP}" \
	--config custom.developmentProvisioningProfileApp="${DEVELOPMENT_PROVISIONING_PROFILE_APP}" \
	--config custom.distributionProvisioningProfileApp="${DISTRIBUTION_PROVISIONING_PROFILE_APP}" \
	--config custom.entitlementsExtensionShare="${ENTITLEMENTS_EXTENSION_SHARE}" \
	--config custom.developmentProvisioningProfileExtensionShare="${DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_SHARE}" \
	--config custom.distributionProvisioningProfileExtensionShare="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_SHARE}" \
	--config custom.entitlementsExtensionWidget="${ENTITLEMENTS_EXTENSION_WIDGET}" \
	--config custom.developmentProvisioningProfileExtensionWidget="${DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_WIDGET}" \
	--config custom.distributionProvisioningProfileExtensionWidget="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_WIDGET}" \
	--config custom.entitlementsExtensionNotificationService="${ENTITLEMENTS_EXTENSION_NOTIFICATIONSERVICE}" \
	--config custom.developmentProvisioningProfileExtensionNotificationService="${DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE}" \
	--config custom.distributionProvisioningProfileExtensionNotificationService="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE}" \
	--config custom.entitlementsExtensionNotificationContent="${ENTITLEMENTS_EXTENSION_NOTIFICATIONCONTENT}" \
	--config custom.developmentProvisioningProfileExtensionNotificationContent="${DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT}" \
	--config custom.distributionProvisioningProfileExtensionNotificationContent="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT}" \
	--config custom.entitlementsExtensionIntents="${ENTITLEMENTS_EXTENSION_INTENTS}" \
	--config custom.developmentProvisioningProfileExtensionIntents="${DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_INTENTS}" \
	--config custom.distributionProvisioningProfileExtensionIntents="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_INTENTS}" \
	--config custom.developmentProvisioningProfileWatchApp="${DEVELOPMENT_PROVISIONING_PROFILE_WATCH_APP}" \
	--config custom.distributionProvisioningProfileWatchApp="${DISTRIBUTION_PROVISIONING_PROFILE_WATCH_APP}" \
	--config custom.developmentProvisioningProfileWatchExtension="${DEVELOPMENT_PROVISIONING_PROFILE_WATCH_EXTENSION}" \
	--config custom.distributionProvisioningProfileWatchExtension="${DISTRIBUTION_PROVISIONING_PROFILE_WATCH_EXTENSION}"

BUCK=/Users/peter/build/buck-next/buck/buck-out/gen/programs/buck.pex

check_env:
	sh check_env.sh

build: check_env
	$(BUCK) build //:AppPackage#iphoneos-arm64,iphoneos-armv7 ${BUCK_OPTIONS}
	sh package_app.sh iphoneos-arm64,iphoneos-armv7 $(BUCK) ${BUCK_OPTIONS}

build_arm64: check_env
	$(BUCK) build //:AppPackage#iphoneos-arm64 ${BUCK_OPTIONS}

package_arm64:
	PACKAGE_DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
	PACKAGE_CODE_SIGN_IDENTITY="${DISTRIBUTION_CODE_SIGN_IDENTITY}" \
	PACKAGE_PROVISIONING_PROFILE_APP="${DISTRIBUTION_PROVISIONING_PROFILE_APP}" \
	PACKAGE_ENTITLEMENTS_APP="${ENTITLEMENTS_APP}" \
	PACKAGE_PROVISIONING_PROFILE_EXTENSION_Share="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_SHARE}" \
	PACKAGE_ENTITLEMENTS_EXTENSION_Share="${ENTITLEMENTS_EXTENSION_SHARE}" \
	PACKAGE_PROVISIONING_PROFILE_EXTENSION_Widget="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_WIDGET}" \
	PACKAGE_ENTITLEMENTS_EXTENSION_Widget="${ENTITLEMENTS_EXTENSION_WIDGET}" \
	PACKAGE_PROVISIONING_PROFILE_EXTENSION_NotificationService="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE}" \
	PACKAGE_ENTITLEMENTS_EXTENSION_NotificationService="${ENTITLEMENTS_EXTENSION_NOTIFICATIONSERVICE}" \
	PACKAGE_PROVISIONING_PROFILE_EXTENSION_NotificationContent="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT}" \
	PACKAGE_ENTITLEMENTS_EXTENSION_NotificationContent="${ENTITLEMENTS_EXTENSION_NOTIFICATIONCONTENT}" \
	PACKAGE_PROVISIONING_PROFILE_EXTENSION_Intents="${DISTRIBUTION_PROVISIONING_PROFILE_EXTENSION_INTENTS}" \
	PACKAGE_ENTITLEMENTS_EXTENSION_Intents="${ENTITLEMENTS_EXTENSION_INTENTS}" \
	PACKAGE_PROVISIONING_PROFILE_WATCH_APP="${DISTRIBUTION_PROVISIONING_PROFILE_WATCH_APP}" \
	PACKAGE_PROVISIONING_PROFILE_WATCH_EXTENSION="${DISTRIBUTION_PROVISIONING_PROFILE_WATCH_EXTENSION}" \
	sh package_app.sh iphoneos-arm64 $(BUCK) $(BUCK_OPTIONS)

app_arm64: build_arm64 package_arm64

build_buckdebug: check_env
	BUCK_DEBUG_MODE=1 $(BUCK) build //:AppPackage#iphoneos-arm64 ${BUCK_OPTIONS}

build_verbose: check_env
	$(BUCK) build //:AppPackage#iphoneos-arm64 --verbose 7 ${BUCK_OPTIONS}

kill_xcode:
	killall Xcode || true
	killall Simulator || true

clean: kill_xcode
	sh clean.sh

project: check_env kill_xcode
	$(BUCK) project //:workspace --config custom.mode=project ${BUCK_OPTIONS}
	open Telegram_Buck.xcworkspace

project_buckdebug: check_env kill_xcode
	BUCK_DEBUG_MODE=1 $(BUCK) project //:workspace --config custom.mode=project ${BUCK_OPTIONS}
	open Telegram_Buck.xcworkspace
