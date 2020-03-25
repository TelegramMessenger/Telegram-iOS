include Utils.makefile

APP_VERSION="1.0"
CORE_COUNT=$(shell sysctl -n hw.logicalcpu)
CORE_COUNT_MINUS_ONE=$(shell expr ${CORE_COUNT} \- 1)

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
	--config custom.appCenterId="0" \
	--config custom.isInternalBuild="${IS_INTERNAL_BUILD}" \
	--config custom.isAppStoreBuild="${IS_APPSTORE_BUILD}" \
	--config custom.appStoreId="${APPSTORE_ID}" \
	--config custom.appSpecificUrlScheme="${APP_SPECIFIC_URL_SCHEME}" \
	--config buildfile.name=BUCK

BAZEL=$(shell which bazel)

ifneq ($(BAZEL_CACHE_DIR),)
	export BAZEL_CACHE_FLAGS=\
		--disk_cache="${BAZEL_CACHE_DIR}"
endif

BAZEL_COMMON_FLAGS=\
	--announce_rc \
	--features=swift.use_global_module_cache \
	
BAZEL_DEBUG_FLAGS=\
	--features=swift.enable_batch_mode \
	--swiftcopt=-j${CORE_COUNT_MINUS_ONE} \

BAZEL_OPT_FLAGS=\
	--swiftcopt=-whole-module-optimization \
	--swiftcopt='-num-threads' --swiftcopt='16' \

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

bazel_wallet_debug_arm64:
	WALLET_APP_VERSION="${APP_VERSION}" \
	build-system/prepare-build.sh Wallet distribution
	"${BAZEL}" build Wallet/Wallet ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_DEBUG_FLAGS} \
	-c dbg \
	--ios_multi_cpus=arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--verbose_failures

bazel_wallet:
	WALLET_APP_VERSION="${APP_VERSION}" \
	build-system/prepare-build.sh Wallet distribution
	"${BAZEL}" build Wallet/Wallet ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_OPT_FLAGS} \
	-c opt \
	--ios_multi_cpus=armv7,arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--verbose_failures

bazel_wallet_prepare_development_build:
	WALLET_APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	build-system/prepare-build.sh Wallet development

bazel_wallet_project: kill_xcode bazel_wallet_prepare_development_build
	WALLET_APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	build-system/generate-xcode-project.sh Wallet
