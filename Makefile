.PHONY : build build_arm64 build_verbose targets project kill_xcode clean

BUCK_OPTIONS=--config custom.apiId="${TELEGRAM_API_ID}" --config custom.apiHash="${TELGRAM_API_HASH}" --config custom.hockeyAppId="${TELGRAM_HOCKEYAPP_ID}" --config custom.isInternalBuild="${TELEGRAM_IS_INTERNAL_BUILD}" --config custom.isAppStoreBuild="${TELEGRAM_IS_APPSTORE_BUILD}" --config custom.appStoreId="${TELEGRAM_APPSTORE_ID}" --config custom.appSpecificUrlScheme="${TELEGRAM_APP_SPECIFIC_URL_SCHEME}" --config custom.buildNumber="${TELEGRAM_BUILD_NUMBER}"
BUCK=/Users/peter/build/buck-next/buck/buck-out/gen/programs/buck.pex

check_env:
	sh check_env.sh

build: check_env
	$(BUCK) build //App:AppPackage#iphoneos-arm64,iphoneos-armv7 ${BUCK_OPTIONS}
	sh package_app.sh $(BUCK) "${BUCK_OPTIONS}" iphoneos-arm64,iphoneos-armv7

build_arm64: check_env
	$(BUCK) build //App:AppPackage#iphoneos-arm64 ${BUCK_OPTIONS}
	sh package_app.sh $(BUCK) "${BUCK_OPTIONS}" iphoneos-arm64

build_verbose: check_env
	$(BUCK) build //App:AppPackage#iphoneos-armv7,iphoneos-arm64 --verbose 8 ${BUCK_OPTIONS}

targets:
	$(BUCK) targets //...

kill_xcode:
	killall Xcode || true
	killall Simulator || true

clean: kill_xcode
	sh clean.sh

project: check_env kill_xcode
	$(BUCK) project //App:workspace --config custom.mode=project ${BUCK_OPTIONS}
	open App/Telegram_Buck.xcworkspace
