.PHONY : check_env build build_arm64 build_debug_arm64 package package_arm64 app app_arm64 app_debug_arm64 build_buckdebug build_verbose kill_xcode clean project project_buckdebug temp


BUCK_DEBUG_OPTIONS=\
	--config custom.other_cflags="-O0 -D DEBUG" \
  	--config custom.other_cxxflags="-O0 -D DEBUG" \
  	--config custom.optimization="-Onone" \
  	--config custom.config_swift_compiler_flags="-DDEBUG"

BUCK_RELEASE_OPTIONS=\
	--config custom.other_cflags="-Os" \
  	--config custom.other_cxxflags="-Os" \
  	--config custom.optimization="-O" \
  	--config custom.config_swift_compiler_flags="-whole-module-optimization"

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

BUCK_THREADS_OPTIONS=--config build.threads=$(shell sysctl -n hw.logicalcpu)

BUCK_CACHE_OPTIONS=

ifneq ($(BUCK_HTTP_CACHE),)
	ifeq ($(BUCK_CACHE_MODE),)
		BUCK_CACHE_MODE=readwrite
	endif
	BUCK_CACHE_OPTIONS=\
		--config cache.mode=http \
		--config cache.http_url="$(BUCK_HTTP_CACHE)" \
		--config cache.http_mode="$(BUCK_CACHE_MODE)"
endif

check_env:
ifndef BUCK
	$(error BUCK is not set)
endif
	sh check_env.sh

build_arm64: check_env
	$(BUCK) build \
	//:AppPackage#iphoneos-arm64 \
	//:Telegram#dwarf-and-dsym,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#shared,iphoneos-arm64 \
	//submodules/Display:Display#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Display:Display#shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#shared,iphoneos-arm64 \
	//:WatchAppExtension#dwarf-and-dsym,watchos-arm64_32,watchos-armv7k \
	//:ShareExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:WidgetExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:NotificationContentExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:NotificationServiceExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:IntentsExtension#dwarf-and-dsym,iphoneos-arm64 \
	${BUCK_OPTIONS} ${BUCK_RELEASE_OPTIONS} ${BUCK_THREADS_OPTIONS} ${BUCK_CACHE_OPTIONS}

build_debug_arm64: check_env
	$(BUCK) build \
	//:AppPackage#iphoneos-arm64 \
	//:Telegram#dwarf-and-dsym,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#shared,iphoneos-arm64 \
	//submodules/Display:Display#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Display:Display#shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#shared,iphoneos-arm64 \
	//:WatchAppExtension#dwarf-and-dsym,watchos-arm64_32,watchos-armv7k \
	//:ShareExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:WidgetExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:NotificationContentExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:NotificationServiceExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:IntentsExtension#dwarf-and-dsym,iphoneos-arm64 \
	${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS} ${BUCK_THREADS_OPTIONS} ${BUCK_CACHE_OPTIONS}

build: check_env
	$(BUCK) build \
	//:AppPackage#iphoneos-arm64,iphoneos-armv7 \
	//:Telegram#dwarf-and-dsym,iphoneos-arm64,iphoneos-armv7 \
	//submodules/MtProtoKit:MtProtoKit#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/MtProtoKit:MtProtoKit#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/Postbox:Postbox#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/Postbox:Postbox#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/TelegramCore:TelegramCore#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/TelegramCore:TelegramCore#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/Display:Display#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/Display:Display#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/TelegramUI:TelegramUI#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/TelegramUI:TelegramUI#shared,iphoneos-arm64,iphoneos-armv7 \
	//:WatchAppExtension#dwarf-and-dsym,watchos-arm64_32,watchos-armv7k \
	//:ShareExtension#dwarf-and-dsym,iphoneos-arm64,iphoneos-armv7 \
    //:WidgetExtension#dwarf-and-dsym,iphoneos-arm64,iphoneos-armv7 \
    //:NotificationContentExtension#dwarf-and-dsym,iphoneos-arm64,iphoneos-armv7 \
    //:NotificationServiceExtension#dwarf-and-dsym,iphoneos-arm64,iphoneos-armv7 \
    //:IntentsExtension#dwarf-and-dsym,iphoneos-arm64,iphoneos-armv7 \
	${BUCK_OPTIONS} ${BUCK_RELEASE_OPTIONS} ${BUCK_THREADS_OPTIONS} ${BUCK_CACHE_OPTIONS}

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
	PACKAGE_BUNDLE_ID="${BUNDLE_ID}" \
	sh package_app.sh iphoneos-arm64 $(BUCK) $(BUCK_OPTIONS) ${BUCK_RELEASE_OPTIONS}

package:
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
	PACKAGE_BUNDLE_ID="${BUNDLE_ID}" \
	sh package_app.sh iphoneos-arm64,iphoneos-armv7 $(BUCK) $(BUCK_OPTIONS) ${BUCK_RELEASE_OPTIONS}

app: build package

app_arm64: build_arm64 package_arm64

app_debug_arm64: build_debug_arm64 package_arm64

build_buckdebug: check_env
	BUCK_DEBUG_MODE=1 $(BUCK) build \
	//:AppPackage#iphoneos-arm64 \
	//:Telegram#dwarf-and-dsym,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#shared,iphoneos-arm64 \
	//submodules/Display:Display#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Display:Display#shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#shared,iphoneos-arm64 \
	//:WatchAppExtension#dwarf-and-dsym,watchos-arm64_32,watchos-armv7k \
	//:ShareExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:WidgetExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:NotificationContentExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:NotificationServiceExtension#dwarf-and-dsym,iphoneos-arm64 \
    //:IntentsExtension#dwarf-and-dsym,iphoneos-arm64 \
    --verbose 7 ${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}

build_buckdebug_one: check_env
	BUCK_DEBUG_MODE=1 $(BUCK) build \
	//submodules/Postbox:Postbox#shared,iphoneos-arm64 \
	--verbose 7 ${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}

build_verbose_one: check_env
	$(BUCK) build \
	//submodules/Postbox:Postbox#shared,iphoneos-arm64 \
	--verbose 7 ${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}

build_verbose: check_env
	$(BUCK) build \
	//:AppPackage#iphoneos-arm64 \
	//:Telegram#dwarf-and-dsym,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/MtProtoKit:MtProtoKit#shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Postbox:Postbox#shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramCore:TelegramCore#shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#shared,iphoneos-arm64 \
	//submodules/Display:Display#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/Display:Display#shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#dwarf-and-dsym,shared,iphoneos-arm64 \
	//submodules/TelegramUI:TelegramUI#shared,iphoneos-arm64 \
	//:WatchAppExtension#dwarf-and-dsym,watchos-arm64_32,watchos-armv7k \
	//:ShareExtension#dwarf-and-dsym,iphoneos-arm64 \
	//:WidgetExtension#dwarf-and-dsym,iphoneos-arm64 \
	//:NotificationContentExtension#dwarf-and-dsym,iphoneos-arm64 \
	//:NotificationServiceExtension#dwarf-and-dsym,iphoneos-arm64 \
	//:IntentsExtension#dwarf-and-dsym,iphoneos-arm64 \
	--verbose 8 ${BUCK_OPTIONS} ${BUCK_THREADS_OPTIONS} ${BUCK_DEBUG_OPTIONS}

deps: check_env
	$(BUCK) query "deps(//:AppPackage)" --dot  \
	${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}



build_openssl: check_env
	$(BUCK) build \
	//submodules/openssl:openssl#iphoneos-arm64 \
	--verbose 7 ${BUCK_OPTIONS} ${BUCK_THREADS_OPTIONS} ${BUCK_DEBUG_OPTIONS}

build_ton: check_env
	$(BUCK) build \
	//submodules/ton:ton#iphoneos-arm64 \
	--verbose 7 ${BUCK_OPTIONS} ${BUCK_THREADS_OPTIONS} ${BUCK_DEBUG_OPTIONS}

kill_xcode:
	killall Xcode || true

clean: kill_xcode
	sh clean.sh

project: check_env kill_xcode
	$(BUCK) project //:workspace --config custom.mode=project ${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}
	open Telegram_Buck.xcworkspace

project_buckdebug: check_env kill_xcode
	BUCK_DEBUG_MODE=1 $(BUCK) project //:workspace --config custom.mode=project ${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}
	open Telegram_Buck.xcworkspace

temp_project: check_env kill_xcode
	$(BUCK) project //Temp:workspace --config custom.mode=project ${BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}
	open Temp/Telegram_Buck.xcworkspace
