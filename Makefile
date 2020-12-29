.PHONY : kill_xcode clean bazel_app_debug_arm64 bazel_app_debug_sim_arm64 bazel_app_arm64 bazel_app_armv7 bazel_app check_sandbox_debug_build bazel_project bazel_project_noextensions

APP_VERSION="7.3"
CORE_COUNT=$(shell sysctl -n hw.logicalcpu)
CORE_COUNT_MINUS_ONE=$(shell expr ${CORE_COUNT} \- 1)

BAZEL=$(shell which bazel)

ifneq ($(BAZEL_HTTP_CACHE_URL),)
	export BAZEL_CACHE_FLAGS=\
		--remote_cache="$(BAZEL_HTTP_CACHE_URL)" --experimental_remote_downloader="$(BAZEL_HTTP_CACHE_URL)"
else ifneq ($(BAZEL_CACHE_DIR),)
	export BAZEL_CACHE_FLAGS=\
		--disk_cache="${BAZEL_CACHE_DIR}"
endif

ifneq ($(BAZEL_KEEP_GOING),)
	export BAZEL_KEEP_GOING_FLAGS=\
		-k
else ifneq ($(BAZEL_CACHE_DIR),)
	export BAZEL_KEEP_GOING_FLAGS=
endif

BAZEL_COMMON_FLAGS=\
	--announce_rc \
	--features=swift.use_global_module_cache \
	--features=swift.split_derived_files_generation \
	--features=swift.skip_function_bodies_for_derived_files \
	--jobs=${CORE_COUNT} \
	${BAZEL_KEEP_GOING_FLAGS} \
	
BAZEL_DEBUG_FLAGS=\
	--features=swift.enable_batch_mode \
	--swiftcopt=-j${CORE_COUNT_MINUS_ONE} \
	--experimental_guard_against_concurrent_changes \

BAZEL_SANDBOX_FLAGS=\
	--strategy=Genrule=sandboxed \
	--spawn_strategy=sandboxed \
	--strategy=SwiftCompile=sandboxed \

# --num-threads 0 forces swiftc to generate one object file per module; it:
# 1. resolves issues with the linker caused by swift-objc mixing.
# 2. makes the resulting binaries significantly smaller (up to 9% for this project).
BAZEL_OPT_FLAGS=\
	--features=swift.opt_uses_wmo \
	--features=swift.opt_uses_osize \
	--swiftcopt='-num-threads' --swiftcopt='0' \
	--features=dead_strip \
    --objc_enable_binary_stripping \
    --apple_bitcode=watchos=embedded \

kill_xcode:
	killall Xcode || true

clean:
	"${BAZEL}" clean --expunge

bazel_app_debug_arm64:
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram distribution
	"${BAZEL}" build Telegram/Telegram ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_DEBUG_FLAGS} \
	-c dbg \
	--ios_multi_cpus=arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--verbose_failures

bazel_webrtc:
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram distribution
	"${BAZEL}" build third-party/webrtc:webrtc_lib ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_DEBUG_FLAGS} ${BAZEL_SANDBOX_FLAGS} \
	-c dbg \
	--ios_multi_cpus=arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--verbose_failures

bazel_app_debug_sim_arm64:
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram distribution
	"${BAZEL}" build Telegram/Telegram ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_DEBUG_FLAGS} \
	-c dbg \
	--ios_multi_cpus=sim_arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--verbose_failures

bazel_app_arm64:
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram distribution
	"${BAZEL}" build Telegram/Telegram ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_OPT_FLAGS} \
	-c opt \
	--ios_multi_cpus=arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--apple_generate_dsym \
	--output_groups=+dsyms \
	--verbose_failures

bazel_app_armv7:
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram distribution
	"${BAZEL}" build Telegram/Telegram ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_OPT_FLAGS} \
	-c opt \
	--ios_multi_cpus=armv7 \
	--watchos_cpus=armv7k,arm64_32 \
	--apple_generate_dsym \
	--output_groups=+dsyms \
	--verbose_failures

bazel_app:
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram distribution
	"${BAZEL}" build Telegram/Telegram ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_OPT_FLAGS} \
	-c opt \
	--ios_multi_cpus=armv7,arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--apple_generate_dsym \
	--output_groups=+dsyms \
	--verbose_failures

check_sandbox_debug_build:
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram distribution
	"${BAZEL}" build Telegram/Telegram ${BAZEL_CACHE_FLAGS} ${BAZEL_COMMON_FLAGS} ${BAZEL_DEBUG_FLAGS} \
	-c opt \
	--ios_multi_cpus=arm64 \
	--watchos_cpus=armv7k,arm64_32 \
	--apple_generate_dsym \
	--output_groups=+dsyms \
	--verbose_failures

bazel_project: kill_xcode
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="0" \
	build-system/prepare-build.sh Telegram development
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	build-system/generate-xcode-project.sh Telegram

bazel_project_noextensions: kill_xcode
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	TELEGRAM_DISABLE_EXTENSIONS="1" \
	build-system/prepare-build.sh Telegram development
	APP_VERSION="${APP_VERSION}" \
	BAZEL_CACHE_DIR="${BAZEL_CACHE_DIR}" \
	BAZEL_HTTP_CACHE_URL="${BAZEL_HTTP_CACHE_URL}" \
	build-system/generate-xcode-project.sh Telegram
