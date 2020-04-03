APP_VERSION="1.0"
CORE_COUNT=$(shell sysctl -n hw.logicalcpu)
CORE_COUNT_MINUS_ONE=$(shell expr ${CORE_COUNT} \- 1)

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

kill_xcode:
	killall Xcode || true

wallet_app_debug_arm64:
	WALLET_APP_VERSION="${APP_VERSION}" \
	build-system/prepare-build.sh Wallet distribution
	"${BAZEL}" build Wallet/Wallet ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_DEBUG_FLAGS} \
	-c dbg \
	--ios_multi_cpus=arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--verbose_failures

wallet_app:
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

wallet_project: kill_xcode bazel_wallet_prepare_development_build
	WALLET_APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	build-system/generate-xcode-project.sh Wallet
