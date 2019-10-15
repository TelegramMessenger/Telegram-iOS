include Utils.makefile

WALLET_BUCK_OPTIONS=\
	--config custom.appVersion="1.0" \
	--config custom.developmentCodeSignIdentity="${DEVELOPMENT_CODE_SIGN_IDENTITY}" \
	--config custom.distributionCodeSignIdentity="${DISTRIBUTION_CODE_SIGN_IDENTITY}" \
	--config custom.developmentTeam="${DEVELOPMENT_TEAM}" \
	--config custom.baseApplicationBundleId="${WALLET_BUNDLE_ID}" \
	--config custom.buildNumber="${BUILD_NUMBER}" \
	--config custom.entitlementsApp="${WALLET_ENTITLEMENTS_APP}" \
	--config custom.developmentProvisioningProfileApp="${WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP}" \
	--config custom.distributionProvisioningProfileApp="${WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP}" \
	--config custom.apiId="${API_ID}" \
	--config custom.apiHash="${API_HASH}" \
	--config custom.hockeyAppId="${HOCKEYAPP_ID}" \
	--config custom.isInternalBuild="${IS_INTERNAL_BUILD}" \
	--config custom.isAppStoreBuild="${IS_APPSTORE_BUILD}" \
	--config custom.appStoreId="${APPSTORE_ID}" \
	--config custom.appSpecificUrlScheme="${APP_SPECIFIC_URL_SCHEME}"

wallet_deps: check_env
	$(BUCK) query "deps(//Wallet:AppPackage)" --output-attribute buck.type \
	${WALLET_BUCK_OPTIONS} ${BUCK_RELEASE_OPTIONS}

wallet_project: check_env kill_xcode
	$(BUCK) project //Wallet:workspace --config custom.mode=project ${WALLET_BUCK_OPTIONS} ${BUCK_DEBUG_OPTIONS}
	open Wallet/WalletWorkspace.xcworkspace

build_wallet: check_env
	$(BUCK) build \
	//Wallet:AppPackage#iphoneos-arm64,iphoneos-armv7 \
	//Wallet:Wallet#dwarf-and-dsym,iphoneos-arm64,iphoneos-armv7 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/AsyncDisplayKit:AsyncDisplayKit#shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/Display:Display#dwarf-and-dsym,shared,iphoneos-arm64,iphoneos-armv7 \
	//submodules/Display:Display#shared,iphoneos-arm64,iphoneos-armv7 \
	${WALLET_BUCK_OPTIONS} ${BUCK_RELEASE_OPTIONS} ${BUCK_THREADS_OPTIONS} ${BUCK_CACHE_OPTIONS}

wallet_package:
	PACKAGE_DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
	PACKAGE_CODE_SIGN_IDENTITY="${DISTRIBUTION_CODE_SIGN_IDENTITY}" \
	PACKAGE_PROVISIONING_PROFILE_APP="${WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP}" \
	PACKAGE_ENTITLEMENTS_APP="Wallet/${WALLET_ENTITLEMENTS_APP}" \
	PACKAGE_BUNDLE_ID="${WALLET_BUNDLE_ID}" \
	sh package_app.sh iphoneos-arm64,iphoneos-armv7 $(BUCK) "wallet" $(WALLET_BUCK_OPTIONS) ${BUCK_RELEASE_OPTIONS}

wallet_app: build_wallet wallet_package

