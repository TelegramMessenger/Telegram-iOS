#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Continuous integration helper module. This module is meant to be called from
# the .gitlab-ci.yml file during the continuous integration build, as well as
# from the command line for developers.

set -eu

OS=`uname -s`

MYDIR=$(dirname $(realpath "$0"))

### Environment parameters:
TEST_STACK_LIMIT="${TEST_STACK_LIMIT:-256}"
CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-RelWithDebInfo}
CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-}
CMAKE_C_COMPILER_LAUNCHER=${CMAKE_C_COMPILER_LAUNCHER:-}
CMAKE_CXX_COMPILER_LAUNCHER=${CMAKE_CXX_COMPILER_LAUNCHER:-}
CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM:-}
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_TEST="${SKIP_TEST:-0}"
TARGETS="${TARGETS:-all doc}"
TEST_SELECTOR="${TEST_SELECTOR:-}"
BUILD_TARGET="${BUILD_TARGET:-}"
ENABLE_WASM_SIMD="${ENABLE_WASM_SIMD:-0}"
if [[ -n "${BUILD_TARGET}" ]]; then
  BUILD_DIR="${BUILD_DIR:-${MYDIR}/build-${BUILD_TARGET%%-*}}"
else
  BUILD_DIR="${BUILD_DIR:-${MYDIR}/build}"
fi
# Whether we should post a message in the MR when the build fails.
POST_MESSAGE_ON_ERROR="${POST_MESSAGE_ON_ERROR:-1}"

# Set default compilers to clang if not already set
export CC=${CC:-clang}
export CXX=${CXX:-clang++}

# Time limit for the "fuzz" command in seconds (0 means no limit).
FUZZER_MAX_TIME="${FUZZER_MAX_TIME:-0}"

SANITIZER="none"


if [[ "${BUILD_TARGET%%-*}" == "x86_64" ||
    "${BUILD_TARGET%%-*}" == "i686" ]]; then
  # Default to building all targets, even if compiler baseline is SSE4
  HWY_BASELINE_TARGETS=${HWY_BASELINE_TARGETS:-HWY_EMU128}
else
  HWY_BASELINE_TARGETS=${HWY_BASELINE_TARGETS:-}
fi

# Convenience flag to pass both CMAKE_C_FLAGS and CMAKE_CXX_FLAGS
CMAKE_FLAGS=${CMAKE_FLAGS:-}
CMAKE_C_FLAGS="${CMAKE_C_FLAGS:-} ${CMAKE_FLAGS}"
CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS:-} ${CMAKE_FLAGS}"

CMAKE_CROSSCOMPILING_EMULATOR=${CMAKE_CROSSCOMPILING_EMULATOR:-}
CMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS:-}
CMAKE_FIND_ROOT_PATH=${CMAKE_FIND_ROOT_PATH:-}
CMAKE_MODULE_LINKER_FLAGS=${CMAKE_MODULE_LINKER_FLAGS:-}
CMAKE_SHARED_LINKER_FLAGS=${CMAKE_SHARED_LINKER_FLAGS:-}
CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE:-}

if [[ "${ENABLE_WASM_SIMD}" -ne "0" ]]; then
  CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -msimd128"
  CMAKE_C_FLAGS="${CMAKE_C_FLAGS} -msimd128"
  CMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS} -msimd128"
fi

if [[ "${ENABLE_WASM_SIMD}" -eq "2" ]]; then
  CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -DHWY_WANT_WASM2"
  CMAKE_C_FLAGS="${CMAKE_C_FLAGS} -DHWY_WANT_WASM2"
fi

if [[ ! -z "${HWY_BASELINE_TARGETS}" ]]; then
  CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -DHWY_BASELINE_TARGETS=${HWY_BASELINE_TARGETS}"
fi

# Version inferred from the CI variables.
CI_COMMIT_SHA=${CI_COMMIT_SHA:-${GITHUB_SHA:-}}
JPEGXL_VERSION=${JPEGXL_VERSION:-${CI_COMMIT_SHA:0:8}}

# Benchmark parameters
STORE_IMAGES=${STORE_IMAGES:-1}
BENCHMARK_CORPORA="${MYDIR}/third_party/corpora"

# Local flags passed to sanitizers.
UBSAN_FLAGS=(
  -fsanitize=alignment
  -fsanitize=bool
  -fsanitize=bounds
  -fsanitize=builtin
  -fsanitize=enum
  -fsanitize=float-cast-overflow
  -fsanitize=float-divide-by-zero
  -fsanitize=integer-divide-by-zero
  -fsanitize=null
  -fsanitize=object-size
  -fsanitize=pointer-overflow
  -fsanitize=return
  -fsanitize=returns-nonnull-attribute
  -fsanitize=shift-base
  -fsanitize=shift-exponent
  -fsanitize=unreachable
  -fsanitize=vla-bound

  -fno-sanitize-recover=undefined
  # Brunsli uses unaligned accesses to uint32_t, so alignment is just a warning.
  -fsanitize-recover=alignment
)
# -fsanitize=function doesn't work on aarch64 and arm.
if [[ "${BUILD_TARGET%%-*}" != "aarch64" &&
    "${BUILD_TARGET%%-*}" != "arm" ]]; then
  UBSAN_FLAGS+=(
    -fsanitize=function
  )
fi
if [[ "${BUILD_TARGET%%-*}" != "arm" ]]; then
  UBSAN_FLAGS+=(
    -fsanitize=signed-integer-overflow
  )
fi

CLANG_TIDY_BIN=$(which clang-tidy-6.0 clang-tidy-7 clang-tidy-8 clang-tidy | head -n 1)
# Default to "cat" if "colordiff" is not installed or if stdout is not a tty.
if [[ -t 1 ]]; then
  COLORDIFF_BIN=$(which colordiff cat | head -n 1)
else
  COLORDIFF_BIN="cat"
fi
FIND_BIN=$(which gfind find | head -n 1)
# "false" will disable wine64 when not installed. This won't allow
# cross-compiling.
WINE_BIN=$(which wine64 false | head -n 1)

CLANG_VERSION="${CLANG_VERSION:-}"
# Detect the clang version suffix and store it in CLANG_VERSION. For example,
# "6.0" for clang 6 or "7" for clang 7.
detect_clang_version() {
  if [[ -n "${CLANG_VERSION}" ]]; then
    return 0
  fi
  local clang_version=$("${CC:-clang}" --version | head -n1)
  clang_version=${clang_version#"Debian "}
  clang_version=${clang_version#"Ubuntu "}
  local llvm_tag
  case "${clang_version}" in
    "clang version 6."*)
      CLANG_VERSION="6.0"
      ;;
    "clang version "*)
      # Any other clang version uses just the major version number.
      local suffix="${clang_version#clang version }"
      CLANG_VERSION="${suffix%%.*}"
      ;;
    "emcc"*)
      # We can't use asan or msan in the emcc case.
      ;;
    *)
      echo "Unknown clang version: ${clang_version}" >&2
      return 1
  esac
}

# Temporary files cleanup hooks.
CLEANUP_FILES=()
cleanup() {
  if [[ ${#CLEANUP_FILES[@]} -ne 0 ]]; then
    rm -fr "${CLEANUP_FILES[@]}"
  fi
}

# Executed on exit.
on_exit() {
  local retcode="$1"
  # Always cleanup the CLEANUP_FILES.
  cleanup

  # Post a message in the MR when requested with POST_MESSAGE_ON_ERROR but only
  # if the run failed and we are not running from a MR pipeline.
  if [[ ${retcode} -ne 0 && -n "${CI_BUILD_NAME:-}" &&
        -n "${POST_MESSAGE_ON_ERROR}" && -z "${CI_MERGE_REQUEST_ID:-}" &&
        "${CI_BUILD_REF_NAME}" = "master" ]]; then
    load_mr_vars_from_commit
    { set +xeu; } 2>/dev/null
    local message="**Run ${CI_BUILD_NAME} @ ${CI_COMMIT_SHORT_SHA} failed.**

Check the output of the job at ${CI_JOB_URL:-} to see if this was your problem.
If it was, please rollback this change or fix the problem ASAP, broken builds
slow down development. Check if the error already existed in the previous build
as well.

Pipeline: ${CI_PIPELINE_URL}

Previous build commit: ${CI_COMMIT_BEFORE_SHA}
"
    cmd_post_mr_comment "${message}"
  fi
}

trap 'retcode=$?; { set +x; } 2>/dev/null; on_exit ${retcode}' INT TERM EXIT


# These variables are populated when calling merge_request_commits().

# The current hash at the top of the current branch or merge request branch (if
# running from a merge request pipeline).
MR_HEAD_SHA=""
# The common ancestor between the current commit and the tracked branch, such
# as master. This includes a list
MR_ANCESTOR_SHA=""

# Populate MR_HEAD_SHA and MR_ANCESTOR_SHA.
merge_request_commits() {
  { set +x; } 2>/dev/null
  # GITHUB_SHA is the current reference being build in GitHub Actions.
  if [[ -n "${GITHUB_SHA:-}" ]]; then
    # GitHub normally does a checkout of a merge commit on a shallow repository
    # by default. We want to get a bit more of the history to be able to diff
    # changes on the Pull Request if needed. This fetches 10 more commits which
    # should be enough given that PR normally should have 1 commit.
    git -C "${MYDIR}" fetch -q origin "${GITHUB_SHA}" --depth 10
    MR_HEAD_SHA="$(git rev-parse "FETCH_HEAD^2" 2>/dev/null ||
                   echo "${GITHUB_SHA}")"
  else
    # CI_BUILD_REF is the reference currently being build in the CI workflow.
    MR_HEAD_SHA=$(git -C "${MYDIR}" rev-parse -q "${CI_BUILD_REF:-HEAD}")
  fi

  if [[ -n "${CI_MERGE_REQUEST_IID:-}" ]]; then
    # Merge request pipeline in CI. In this case the upstream is called "origin"
    # but it refers to the forked project that's the source of the merge
    # request. We need to get the target of the merge request, for which we need
    # to query that repository using our CI_JOB_TOKEN.
    echo "machine gitlab.com login gitlab-ci-token password ${CI_JOB_TOKEN}" \
      >> "${HOME}/.netrc"
    git -C "${MYDIR}" fetch "${CI_MERGE_REQUEST_PROJECT_URL}" \
      "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
    MR_ANCESTOR_SHA=$(git -C "${MYDIR}" rev-parse -q FETCH_HEAD)
  elif [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    # Pull request workflow in GitHub Actions. GitHub checkout action uses
    # "origin" as the remote for the git checkout.
    git -C "${MYDIR}" fetch -q origin "${GITHUB_BASE_REF}"
    MR_ANCESTOR_SHA=$(git -C "${MYDIR}" rev-parse -q FETCH_HEAD)
  else
    # We are in a local branch, not a merge request.
    MR_ANCESTOR_SHA=$(git -C "${MYDIR}" rev-parse -q HEAD@{upstream} || true)
  fi

  if [[ -z "${MR_ANCESTOR_SHA}" ]]; then
    echo "Warning, not tracking any branch, using the last commit in HEAD.">&2
    # This prints the return value with just HEAD.
    MR_ANCESTOR_SHA=$(git -C "${MYDIR}" rev-parse -q "${MR_HEAD_SHA}^")
  else
    # GitHub runs the pipeline on a merge commit, no need to look for the common
    # ancestor in that case.
    if [[ -z "${GITHUB_BASE_REF:-}" ]]; then
      MR_ANCESTOR_SHA=$(git -C "${MYDIR}" merge-base \
        "${MR_ANCESTOR_SHA}" "${MR_HEAD_SHA}")
    fi
  fi
  set -x
}

# Load the MR iid from the landed commit message when running not from a
# merge request workflow. This is useful to post back results at the merge
# request when running pipelines from master.
load_mr_vars_from_commit() {
  { set +x; } 2>/dev/null
  if [[ -z "${CI_MERGE_REQUEST_IID:-}" ]]; then
    local mr_iid=$(git rev-list --format=%B --max-count=1 HEAD |
      grep -F "${CI_PROJECT_URL}" | grep -F "/merge_requests" | head -n 1)
    # mr_iid contains a string like this if it matched:
    #  Part-of: <https://gitlab.com/wg1/jpeg-xlm/merge_requests/123456>
    if [[ -n "${mr_iid}" ]]; then
      mr_iid=$(echo "${mr_iid}" |
        sed -E 's,^.*merge_requests/([0-9]+)>.*$,\1,')
      CI_MERGE_REQUEST_IID="${mr_iid}"
      CI_MERGE_REQUEST_PROJECT_ID=${CI_PROJECT_ID}
    fi
  fi
  set -x
}

# Posts a comment to the current merge request.
cmd_post_mr_comment() {
  { set +x; } 2>/dev/null
  local comment="$1"
  if [[ -n "${BOT_TOKEN:-}" && -n "${CI_MERGE_REQUEST_IID:-}" ]]; then
    local url="${CI_API_V4_URL}/projects/${CI_MERGE_REQUEST_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/notes"
    curl -X POST -g \
      -H "PRIVATE-TOKEN: ${BOT_TOKEN}" \
      --data-urlencode "body=${comment}" \
      --output /dev/null \
      "${url}"
  fi
  set -x
}

# Set up and export the environment variables needed by the child processes.
export_env() {
  if [[ "${BUILD_TARGET}" == *mingw32 ]]; then
    # Wine needs to know the paths to the mingw dlls. These should be
    # separated by ';'.
    WINEPATH=$("${CC:-clang}" -print-search-dirs --target="${BUILD_TARGET}" \
      | grep -F 'libraries: =' | cut -f 2- -d '=' | tr ':' ';')
    # We also need our own libraries in the wine path.
    local real_build_dir=$(realpath "${BUILD_DIR}")
    # Some library .dll dependencies are installed in /bin:
    export WINEPATH="${WINEPATH};${real_build_dir};${real_build_dir}/third_party/brotli;/usr/${BUILD_TARGET}/bin"

    local prefix="${BUILD_DIR}/wineprefix"
    mkdir -p "${prefix}"
    export WINEPREFIX=$(realpath "${prefix}")
  fi
  # Sanitizers need these variables to print and properly format the stack
  # traces:
  LLVM_SYMBOLIZER=$("${CC:-clang}" -print-prog-name=llvm-symbolizer || true)
  if [[ -n "${LLVM_SYMBOLIZER}" ]]; then
    export ASAN_SYMBOLIZER_PATH="${LLVM_SYMBOLIZER}"
    export MSAN_SYMBOLIZER_PATH="${LLVM_SYMBOLIZER}"
    export UBSAN_SYMBOLIZER_PATH="${LLVM_SYMBOLIZER}"
  fi
}

cmake_configure() {
  export_env

  if [[ "${STACK_SIZE:-0}" == 1 ]]; then
    # Dump the stack size of each function in the .stack_sizes section for
    # analysis.
    CMAKE_C_FLAGS+=" -fstack-size-section"
    CMAKE_CXX_FLAGS+=" -fstack-size-section"
  fi

  local args=(
    -B"${BUILD_DIR}" -H"${MYDIR}"
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    -G Ninja
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}"
    -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}"
    -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}"
    -DCMAKE_MODULE_LINKER_FLAGS="${CMAKE_MODULE_LINKER_FLAGS}"
    -DCMAKE_SHARED_LINKER_FLAGS="${CMAKE_SHARED_LINKER_FLAGS}"
    -DJPEGXL_VERSION="${JPEGXL_VERSION}"
    -DSANITIZER="${SANITIZER}"
    # These are not enabled by default in cmake.
    -DJPEGXL_ENABLE_VIEWERS=ON
    -DJPEGXL_ENABLE_PLUGINS=ON
    -DJPEGXL_ENABLE_DEVTOOLS=ON
    # We always use libfuzzer in the ci.sh wrapper.
    -DJPEGXL_FUZZER_LINK_FLAGS="-fsanitize=fuzzer"
  )
  if [[ "${BUILD_TARGET}" != *mingw32 ]]; then
    args+=(
      -DJPEGXL_WARNINGS_AS_ERRORS=ON
    )
  fi
  if [[ -n "${BUILD_TARGET}" ]]; then
    local system_name="Linux"
    if [[ "${BUILD_TARGET}" == *mingw32 ]]; then
      # When cross-compiling with mingw the target must be set to Windows and
      # run programs with wine.
      system_name="Windows"
      args+=(
        -DCMAKE_CROSSCOMPILING_EMULATOR="${WINE_BIN}"
        # Normally CMake automatically defines MINGW=1 when building with the
        # mingw compiler (x86_64-w64-mingw32-gcc) but we are normally compiling
        # with clang.
        -DMINGW=1
      )
    fi
    # EMSCRIPTEN toolchain sets the right values itself
    if [[ "${BUILD_TARGET}" != wasm* ]]; then
      # If set, BUILD_TARGET must be the target triplet such as
      # x86_64-unknown-linux-gnu.
      args+=(
        -DCMAKE_C_COMPILER_TARGET="${BUILD_TARGET}"
        -DCMAKE_CXX_COMPILER_TARGET="${BUILD_TARGET}"
        # Only the first element of the target triplet.
        -DCMAKE_SYSTEM_PROCESSOR="${BUILD_TARGET%%-*}"
        -DCMAKE_SYSTEM_NAME="${system_name}"
        -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TOOLCHAIN_FILE}"
      )
    else
      args+=(
        # sjpeg confuses WASM SIMD with SSE.
        -DSJPEG_ENABLE_SIMD=OFF
        # Building shared libs is not very useful for WASM.
        -DBUILD_SHARED_LIBS=OFF
      )
    fi
    args+=(
      # These are needed to make googletest work when cross-compiling.
      -DCMAKE_CROSSCOMPILING=1
      -DHAVE_STD_REGEX=0
      -DHAVE_POSIX_REGEX=0
      -DHAVE_GNU_POSIX_REGEX=0
      -DHAVE_STEADY_CLOCK=0
      -DHAVE_THREAD_SAFETY_ATTRIBUTES=0
    )
    if [[ -z "${CMAKE_FIND_ROOT_PATH}" ]]; then
      # find_package() will look in this prefix for libraries.
      CMAKE_FIND_ROOT_PATH="/usr/${BUILD_TARGET}"
    fi
    if [[ -z "${CMAKE_PREFIX_PATH}" ]]; then
      CMAKE_PREFIX_PATH="/usr/${BUILD_TARGET}"
    fi
    # Use pkg-config for the target. If there's no pkg-config available for the
    # target we can set the PKG_CONFIG_PATH to the appropriate path in most
    # linux distributions.
    local pkg_config=$(which "${BUILD_TARGET}-pkg-config" || true)
    if [[ -z "${pkg_config}" ]]; then
      pkg_config=$(which pkg-config)
      export PKG_CONFIG_LIBDIR="/usr/${BUILD_TARGET}/lib/pkgconfig"
    fi
    if [[ -n "${pkg_config}" ]]; then
      args+=(-DPKG_CONFIG_EXECUTABLE="${pkg_config}")
    fi
  fi
  if [[ -n "${CMAKE_CROSSCOMPILING_EMULATOR}" ]]; then
    args+=(
      -DCMAKE_CROSSCOMPILING_EMULATOR="${CMAKE_CROSSCOMPILING_EMULATOR}"
    )
  fi
  if [[ -n "${CMAKE_FIND_ROOT_PATH}" ]]; then
    args+=(
      -DCMAKE_FIND_ROOT_PATH="${CMAKE_FIND_ROOT_PATH}"
    )
  fi
  if [[ -n "${CMAKE_PREFIX_PATH}" ]]; then
    args+=(
      -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}"
    )
  fi
  if [[ -n "${CMAKE_C_COMPILER_LAUNCHER}" ]]; then
    args+=(
      -DCMAKE_C_COMPILER_LAUNCHER="${CMAKE_C_COMPILER_LAUNCHER}"
    )
  fi
  if [[ -n "${CMAKE_CXX_COMPILER_LAUNCHER}" ]]; then
    args+=(
      -DCMAKE_CXX_COMPILER_LAUNCHER="${CMAKE_CXX_COMPILER_LAUNCHER}"
    )
  fi
  if [[ -n "${CMAKE_MAKE_PROGRAM}" ]]; then
    args+=(
      -DCMAKE_MAKE_PROGRAM="${CMAKE_MAKE_PROGRAM}"
    )
  fi
  if [[ "${BUILD_TARGET}" == wasm* ]]; then
    emcmake cmake "${args[@]}" "$@"
  else
    cmake "${args[@]}" "$@"
  fi
}

cmake_build_and_test() {
  if [[ "${SKIP_BUILD}" -eq "1" ]]; then
      return 0
  fi
  # gtest_discover_tests() runs the test binaries to discover the list of tests
  # at build time, which fails under qemu.
  ASAN_OPTIONS=detect_leaks=0 cmake --build "${BUILD_DIR}" -- $TARGETS
  # Pack test binaries if requested.
  if [[ "${PACK_TEST:-}" == "1" ]]; then
    (cd "${BUILD_DIR}"
     ${FIND_BIN} -name '*.cmake' -a '!' -path '*CMakeFiles*'
     # gtest / gmock / gtest_main shared libs
     ${FIND_BIN} lib/ -name 'libg*.so*'
     ${FIND_BIN} -type d -name tests -a '!' -path '*CMakeFiles*'
    ) | tar -C "${BUILD_DIR}" -cf "${BUILD_DIR}/tests.tar.xz" -T - \
      --use-compress-program="xz --threads=$(nproc --all || echo 1) -6"
    du -h "${BUILD_DIR}/tests.tar.xz"
    # Pack coverage data if also available.
    touch "${BUILD_DIR}/gcno.sentinel"
    (cd "${BUILD_DIR}"; echo gcno.sentinel; ${FIND_BIN} -name '*gcno') | \
      tar -C "${BUILD_DIR}" -cvf "${BUILD_DIR}/gcno.tar.xz" -T - \
        --use-compress-program="xz --threads=$(nproc --all || echo 1) -6"
  fi

  if [[ "${SKIP_TEST}" -ne "1" ]]; then
    (cd "${BUILD_DIR}"
     export UBSAN_OPTIONS=print_stacktrace=1
     [[ "${TEST_STACK_LIMIT}" == "none" ]] || ulimit -s "${TEST_STACK_LIMIT}"
     ctest -j $(nproc --all || echo 1) ${TEST_SELECTOR} --output-on-failure)
  fi
}

# Configure the build to strip unused functions. This considerably reduces the
# output size, specially for tests which only use a small part of the whole
# library.
strip_dead_code() {
  # Emscripten does tree shaking without any extra flags.
  if [[ "${BUILD_TARGET}" == wasm* ]]; then
    return 0
  fi
  # -ffunction-sections, -fdata-sections and -Wl,--gc-sections effectively
  # discard all unreachable code, reducing the code size. For this to work, we
  # need to also pass --no-export-dynamic to prevent it from exporting all the
  # internal symbols (like functions) making them all reachable and thus not a
  # candidate for removal.
  CMAKE_CXX_FLAGS+=" -ffunction-sections -fdata-sections"
  CMAKE_C_FLAGS+=" -ffunction-sections -fdata-sections"
  if [[ "${OS}" == "Darwin" ]]; then
    CMAKE_EXE_LINKER_FLAGS+=" -dead_strip"
    CMAKE_SHARED_LINKER_FLAGS+=" -dead_strip"
  else
    CMAKE_EXE_LINKER_FLAGS+=" -Wl,--gc-sections -Wl,--no-export-dynamic"
    CMAKE_SHARED_LINKER_FLAGS+=" -Wl,--gc-sections -Wl,--no-export-dynamic"
  fi
}

### Externally visible commands

cmd_debug() {
  CMAKE_BUILD_TYPE="Debug"
  cmake_configure "$@"
  cmake_build_and_test
}

cmd_release() {
  CMAKE_BUILD_TYPE="Release"
  strip_dead_code
  cmake_configure "$@"
  cmake_build_and_test
}

cmd_opt() {
  CMAKE_BUILD_TYPE="RelWithDebInfo"
  CMAKE_CXX_FLAGS+=" -DJXL_DEBUG_WARNING -DJXL_DEBUG_ON_ERROR"
  cmake_configure "$@"
  cmake_build_and_test
}

cmd_coverage() {
  # -O0 prohibits stack space reuse -> causes stack-overflow on dozens of tests.
  TEST_STACK_LIMIT="none"

  cmd_release -DJPEGXL_ENABLE_COVERAGE=ON "$@"

  if [[ "${SKIP_TEST}" -ne "1" ]]; then
    # If we didn't run the test we also don't print a coverage report.
    cmd_coverage_report
  fi
}

cmd_coverage_report() {
  LLVM_COV=$("${CC:-clang}" -print-prog-name=llvm-cov)
  local real_build_dir=$(realpath "${BUILD_DIR}")
  local gcovr_args=(
    -r "${real_build_dir}"
    --gcov-executable "${LLVM_COV} gcov"
    # Only print coverage information for the libjxl directories. The rest
    # is not part of the code under test.
    --filter '.*jxl/.*'
    --exclude '.*_gbench.cc'
    --exclude '.*_test.cc'
    --exclude '.*_testonly..*'
    --exclude '.*_debug.*'
    --exclude '.*test_utils..*'
    --object-directory "${real_build_dir}"
  )

  (
   cd "${real_build_dir}"
    gcovr "${gcovr_args[@]}" --html --html-details \
      --output="${real_build_dir}/coverage.html"
    gcovr "${gcovr_args[@]}" --print-summary |
      tee "${real_build_dir}/coverage.txt"
    gcovr "${gcovr_args[@]}" --xml --output="${real_build_dir}/coverage.xml"
  )
}

cmd_test() {
  export_env
  # Unpack tests if needed.
  if [[ -e "${BUILD_DIR}/tests.tar.xz" && ! -d "${BUILD_DIR}/tests" ]]; then
    tar -C "${BUILD_DIR}" -Jxvf "${BUILD_DIR}/tests.tar.xz"
  fi
  if [[ -e "${BUILD_DIR}/gcno.tar.xz" && ! -d "${BUILD_DIR}/gcno.sentinel" ]]; then
    tar -C "${BUILD_DIR}" -Jxvf "${BUILD_DIR}/gcno.tar.xz"
  fi
  (cd "${BUILD_DIR}"
   export UBSAN_OPTIONS=print_stacktrace=1
   [[ "${TEST_STACK_LIMIT}" == "none" ]] || ulimit -s "${TEST_STACK_LIMIT}"
   ctest -j $(nproc --all || echo 1) ${TEST_SELECTOR} --output-on-failure "$@")
}

cmd_gbench() {
  export_env
  (cd "${BUILD_DIR}"
   export UBSAN_OPTIONS=print_stacktrace=1
   lib/jxl_gbench \
     --benchmark_counters_tabular=true \
     --benchmark_out_format=json \
     --benchmark_out=gbench.json "$@"
  )
}

cmd_asanfuzz() {
  CMAKE_CXX_FLAGS+=" -fsanitize=fuzzer-no-link -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION=1"
  CMAKE_C_FLAGS+=" -fsanitize=fuzzer-no-link -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION=1"
  cmd_asan -DJPEGXL_ENABLE_FUZZERS=ON "$@"
}

cmd_msanfuzz() {
  # Install msan if needed before changing the flags.
  detect_clang_version
  local msan_prefix="${HOME}/.msan/${CLANG_VERSION}"
  if [[ ! -d "${msan_prefix}" || -e "${msan_prefix}/lib/libc++abi.a" ]]; then
    # Install msan libraries for this version if needed or if an older version
    # with libc++abi was installed.
    cmd_msan_install
  fi

  CMAKE_CXX_FLAGS+=" -fsanitize=fuzzer-no-link -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION=1"
  CMAKE_C_FLAGS+=" -fsanitize=fuzzer-no-link -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION=1"
  cmd_msan -DJPEGXL_ENABLE_FUZZERS=ON "$@"
}

cmd_asan() {
  SANITIZER="asan"
  CMAKE_C_FLAGS+=" -DJXL_ENABLE_ASSERT=1 -g -DADDRESS_SANITIZER \
    -fsanitize=address ${UBSAN_FLAGS[@]}"
  CMAKE_CXX_FLAGS+=" -DJXL_ENABLE_ASSERT=1 -g -DADDRESS_SANITIZER \
    -fsanitize=address ${UBSAN_FLAGS[@]}"
  strip_dead_code
  cmake_configure "$@" -DJPEGXL_ENABLE_TCMALLOC=OFF
  cmake_build_and_test
}

cmd_tsan() {
  SANITIZER="tsan"
  local tsan_args=(
    -DJXL_ENABLE_ASSERT=1
    -g
    -DTHREAD_SANITIZER
    ${UBSAN_FLAGS[@]}
    -fsanitize=thread
  )
  CMAKE_C_FLAGS+=" ${tsan_args[@]}"
  CMAKE_CXX_FLAGS+=" ${tsan_args[@]}"

  CMAKE_BUILD_TYPE="RelWithDebInfo"
  cmake_configure "$@" -DJPEGXL_ENABLE_TCMALLOC=OFF
  cmake_build_and_test
}

cmd_msan() {
  SANITIZER="msan"
  detect_clang_version
  local msan_prefix="${HOME}/.msan/${CLANG_VERSION}"
  if [[ ! -d "${msan_prefix}" || -e "${msan_prefix}/lib/libc++abi.a" ]]; then
    # Install msan libraries for this version if needed or if an older version
    # with libc++abi was installed.
    cmd_msan_install
  fi

  local msan_c_flags=(
    -fsanitize=memory
    -fno-omit-frame-pointer
    -fsanitize-memory-track-origins

    -DJXL_ENABLE_ASSERT=1
    -g
    -DMEMORY_SANITIZER

    # Force gtest to not use the cxxbai.
    -DGTEST_HAS_CXXABI_H_=0
  )
  local msan_cxx_flags=(
    "${msan_c_flags[@]}"

    # Some C++ sources don't use the std at all, so the -stdlib=libc++ is unused
    # in those cases. Ignore the warning.
    -Wno-unused-command-line-argument
    -stdlib=libc++

    # We include the libc++ from the msan directory instead, so we don't want
    # the std includes.
    -nostdinc++
    -cxx-isystem"${msan_prefix}/include/c++/v1"
  )

  local msan_linker_flags=(
    -L"${msan_prefix}"/lib
    -Wl,-rpath -Wl,"${msan_prefix}"/lib/
  )

  CMAKE_C_FLAGS+=" ${msan_c_flags[@]} ${UBSAN_FLAGS[@]}"
  CMAKE_CXX_FLAGS+=" ${msan_cxx_flags[@]} ${UBSAN_FLAGS[@]}"
  CMAKE_EXE_LINKER_FLAGS+=" ${msan_linker_flags[@]}"
  CMAKE_MODULE_LINKER_FLAGS+=" ${msan_linker_flags[@]}"
  CMAKE_SHARED_LINKER_FLAGS+=" ${msan_linker_flags[@]}"
  strip_dead_code
  cmake_configure "$@" \
    -DCMAKE_CROSSCOMPILING=1 -DRUN_HAVE_STD_REGEX=0 -DRUN_HAVE_POSIX_REGEX=0 \
    -DJPEGXL_ENABLE_TCMALLOC=OFF -DJPEGXL_WARNINGS_AS_ERRORS=OFF \
    -DCMAKE_REQUIRED_LINK_OPTIONS="${msan_linker_flags[@]}"
  cmake_build_and_test
}

# Install libc++ libraries compiled with msan in the msan_prefix for the current
# compiler version.
cmd_msan_install() {
  local tmpdir=$(mktemp -d)
  CLEANUP_FILES+=("${tmpdir}")
  # Detect the llvm to install:
  export CC="${CC:-clang}"
  export CXX="${CXX:-clang++}"
  detect_clang_version
  # Allow overriding the LLVM checkout.
  local llvm_root="${LLVM_ROOT:-}"
  if [ -z "${llvm_root}" ]; then
    local llvm_tag="llvmorg-${CLANG_VERSION}.0.0"
    case "${CLANG_VERSION}" in
      "6.0")
        llvm_tag="llvmorg-6.0.1"
        ;;
      "7")
        llvm_tag="llvmorg-7.0.1"
        ;;
    esac
    local llvm_targz="${tmpdir}/${llvm_tag}.tar.gz"
    curl -L --show-error -o "${llvm_targz}" \
      "https://github.com/llvm/llvm-project/archive/${llvm_tag}.tar.gz"
    tar -C "${tmpdir}" -zxf "${llvm_targz}"
    llvm_root="${tmpdir}/llvm-project-${llvm_tag}"
  fi

  local msan_prefix="${HOME}/.msan/${CLANG_VERSION}"
  rm -rf "${msan_prefix}"

  declare -A CMAKE_EXTRAS
  CMAKE_EXTRAS[libcxx]="\
    -DLIBCXX_CXX_ABI=libstdc++ \
    -DLIBCXX_INSTALL_EXPERIMENTAL_LIBRARY=ON"

  for project in libcxx; do
    local proj_build="${tmpdir}/build-${project}"
    local proj_dir="${llvm_root}/${project}"
    mkdir -p "${proj_build}"
    cmake -B"${proj_build}" -H"${proj_dir}" \
      -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_USE_SANITIZER=Memory \
      -DLLVM_PATH="${llvm_root}/llvm" \
      -DLLVM_CONFIG_PATH="$(which llvm-config llvm-config-7 llvm-config-6.0 | \
                            head -n1)" \
      -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}" \
      -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
      -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}" \
      -DCMAKE_SHARED_LINKER_FLAGS="${CMAKE_SHARED_LINKER_FLAGS}" \
      -DCMAKE_INSTALL_PREFIX="${msan_prefix}" \
      ${CMAKE_EXTRAS[${project}]}
    cmake --build "${proj_build}"
    ninja -C "${proj_build}" install
  done
}

# Internal build step shared between all cmd_ossfuzz_* commands.
_cmd_ossfuzz() {
  local sanitizer="$1"
  shift
  mkdir -p "${BUILD_DIR}"
  local real_build_dir=$(realpath "${BUILD_DIR}")

  # oss-fuzz defines three directories:
  # * /work, with the working directory to do re-builds
  # * /src, with the source code to build
  # * /out, with the output directory where to copy over the built files.
  # We use $BUILD_DIR as the /work and the script directory as the /src. The
  # /out directory is ignored as developers are used to look for the fuzzers in
  # $BUILD_DIR/tools/ directly.

  if [[ "${sanitizer}" = "memory" && ! -d "${BUILD_DIR}/msan" ]]; then
    sudo docker run --rm -i \
      --user $(id -u):$(id -g) \
      -v "${real_build_dir}":/work \
      gcr.io/oss-fuzz-base/msan-libs-builder \
      bash -c "cp -r /msan /work"
  fi

  # Args passed to ninja. These will be evaluated as a string separated by
  # spaces.
  local jpegxl_extra_args="$@"

  sudo docker run --rm -i \
    -e JPEGXL_UID=$(id -u) \
    -e JPEGXL_GID=$(id -g) \
    -e FUZZING_ENGINE="${FUZZING_ENGINE:-libfuzzer}" \
    -e SANITIZER="${sanitizer}" \
    -e ARCHITECTURE=x86_64 \
    -e FUZZING_LANGUAGE=c++ \
    -e MSAN_LIBS_PATH="/work/msan" \
    -e JPEGXL_EXTRA_ARGS="${jpegxl_extra_args}" \
    -v "${MYDIR}":/src/libjxl \
    -v "${MYDIR}/tools/scripts/ossfuzz-build.sh":/src/build.sh \
    -v "${real_build_dir}":/work \
    gcr.io/oss-fuzz/libjxl
}

cmd_ossfuzz_asan() {
  _cmd_ossfuzz address "$@"
}
cmd_ossfuzz_msan() {
  _cmd_ossfuzz memory "$@"
}
cmd_ossfuzz_ubsan() {
  _cmd_ossfuzz undefined "$@"
}

cmd_ossfuzz_ninja() {
  [[ -e "${BUILD_DIR}/build.ninja" ]]
  local real_build_dir=$(realpath "${BUILD_DIR}")

  if [[ -e "${BUILD_DIR}/msan" ]]; then
    echo "ossfuzz_ninja doesn't work with msan builds. Use ossfuzz_msan." >&2
    exit 1
  fi

  sudo docker run --rm -i \
    --user $(id -u):$(id -g) \
    -v "${MYDIR}":/src/libjxl \
    -v "${real_build_dir}":/work \
    gcr.io/oss-fuzz/libjxl \
    ninja -C /work "$@"
}

cmd_fast_benchmark() {
  local small_corpus_tar="${BENCHMARK_CORPORA}/jyrki-full.tar"
  mkdir -p "${BENCHMARK_CORPORA}"
  curl --show-error -o "${small_corpus_tar}" -z "${small_corpus_tar}" \
    "https://storage.googleapis.com/artifacts.jpegxl.appspot.com/corpora/jyrki-full.tar"

  local tmpdir=$(mktemp -d)
  CLEANUP_FILES+=("${tmpdir}")
  tar -xf "${small_corpus_tar}" -C "${tmpdir}"

  run_benchmark "${tmpdir}" 1048576
}

cmd_benchmark() {
  local nikon_corpus_tar="${BENCHMARK_CORPORA}/nikon-subset.tar"
  mkdir -p "${BENCHMARK_CORPORA}"
  curl --show-error -o "${nikon_corpus_tar}" -z "${nikon_corpus_tar}" \
    "https://storage.googleapis.com/artifacts.jpegxl.appspot.com/corpora/nikon-subset.tar"

  local tmpdir=$(mktemp -d)
  CLEANUP_FILES+=("${tmpdir}")
  tar -xvf "${nikon_corpus_tar}" -C "${tmpdir}"

  local sem_id="jpegxl_benchmark-$$"
  local nprocs=$(nproc --all || echo 1)
  images=()
  local filename
  while IFS= read -r filename; do
    # This removes the './'
    filename="${filename:2}"
    local mode
    if [[ "${filename:0:4}" == "srgb" ]]; then
      mode="RGB_D65_SRG_Rel_SRG"
    elif [[ "${filename:0:5}" == "adobe" ]]; then
      mode="RGB_D65_Ado_Rel_Ado"
    else
      echo "Unknown image colorspace: ${filename}" >&2
      exit 1
    fi
    png_filename="${filename%.ppm}.png"
    png_filename=$(echo "${png_filename}" | tr '/' '_')
    sem --bg --id "${sem_id}" -j"${nprocs}" -- \
      "${BUILD_DIR}/tools/decode_and_encode" \
        "${tmpdir}/${filename}" "${mode}" "${tmpdir}/${png_filename}"
    images+=( "${png_filename}" )
  done < <(cd "${tmpdir}"; ${FIND_BIN} . -name '*.ppm' -type f)
  sem --id "${sem_id}" --wait

  # We need about 10 GiB per thread on these images.
  run_benchmark "${tmpdir}" 10485760
}

get_mem_available() {
  if [[ "${OS}" == "Darwin" ]]; then
    echo $(vm_stat | grep -F 'Pages free:' | awk '{print $3 * 4}')
  else
    echo $(grep -F MemAvailable: /proc/meminfo | awk '{print $2}')
  fi
}

run_benchmark() {
  local src_img_dir="$1"
  local mem_per_thread="${2:-10485760}"

  local output_dir="${BUILD_DIR}/benchmark_results"
  mkdir -p "${output_dir}"

  # The memory available at the beginning of the benchmark run in kB. The number
  # of threads depends on the available memory, and the passed memory per
  # thread. We also add a 2 GiB of constant memory.
  local mem_available="$(get_mem_available)"
  # Check that we actually have a MemAvailable value.
  [[ -n "${mem_available}" ]]
  local num_threads=$(( (${mem_available} - 1048576) / ${mem_per_thread} ))
  if [[ ${num_threads} -le 0 ]]; then
    num_threads=1
  fi

  local benchmark_args=(
    --input "${src_img_dir}/*.png"
    --codec=jpeg:yuv420:q85,webp:q80,jxl:d1:6,jxl:d1:6:downsampling=8,jxl:d5:6,jxl:d5:6:downsampling=8,jxl:m:d0:2,jxl:m:d0:3,jxl:m:d2:2
    --output_dir "${output_dir}"
    --show_progress
    --num_threads="${num_threads}"
  )
  if [[ "${STORE_IMAGES}" == "1" ]]; then
    benchmark_args+=(--save_decompressed --save_compressed)
  fi
  (
    [[ "${TEST_STACK_LIMIT}" == "none" ]] || ulimit -s "${TEST_STACK_LIMIT}"
    "${BUILD_DIR}/tools/benchmark_xl" "${benchmark_args[@]}" | \
       tee "${output_dir}/results.txt"

    # Check error code for benckmark_xl command. This will exit if not.
    return ${PIPESTATUS[0]}
  )

  if [[ -n "${CI_BUILD_NAME:-}" ]]; then
    { set +x; } 2>/dev/null
    local message="Results for ${CI_BUILD_NAME} @ ${CI_COMMIT_SHORT_SHA} (job ${CI_JOB_URL:-}):

$(cat "${output_dir}/results.txt")
"
    cmd_post_mr_comment "${message}"
    set -x
  fi
}

# Helper function to wait for the CPU temperature to cool down on ARM.
wait_for_temp() {
  { set +x; } 2>/dev/null
  local temp_limit=${1:-38000}
  if [[ -z "${THERMAL_FILE:-}" ]]; then
    echo "Must define the THERMAL_FILE with the thermal_zoneX/temp file" \
      "to read the temperature from. This is normally set in the runner." >&2
    exit 1
  fi
  local org_temp=$(cat "${THERMAL_FILE}")
  if [[ "${org_temp}" -ge "${temp_limit}" ]]; then
    echo -n "Waiting for temp to get down from ${org_temp}... "
  fi
  local temp="${org_temp}"
  local secs=0
  while [[ "${temp}" -ge "${temp_limit}" ]]; do
    sleep 1
    temp=$(cat "${THERMAL_FILE}")
    echo -n "${temp} "
    secs=$((secs + 1))
    if [[ ${secs} -ge 5 ]]; then
      break
    fi
  done
  if [[ "${org_temp}" -ge "${temp_limit}" ]]; then
    echo "Done, temp=${temp}"
  fi
  set -x
}

# Helper function to set the cpuset restriction of the current process.
cmd_cpuset() {
  [[ "${SKIP_CPUSET:-}" != "1" ]] || return 0
  local newset="$1"
  local mycpuset=$(cat /proc/self/cpuset)
  mycpuset="/dev/cpuset${mycpuset}"
  # Check that the directory exists:
  [[ -d "${mycpuset}" ]]
  if [[ -e "${mycpuset}/cpuset.cpus" ]]; then
    echo "${newset}" >"${mycpuset}/cpuset.cpus"
  else
    echo "${newset}" >"${mycpuset}/cpus"
  fi
}

# Return the encoding/decoding speed from the Stats output.
_speed_from_output() {
  local speed="$1"
  local unit="${2:-MP/s}"
  if [[ "${speed}" == *"${unit}"* ]]; then
    speed="${speed%% ${unit}*}"
    speed="${speed##* }"
    echo "${speed}"
  fi
}


# Run benchmarks on ARM for the big and little CPUs.
cmd_arm_benchmark() {
  # Flags used for cjxl encoder with .png inputs
  local jxl_png_benchmarks=(
    # Lossy options:
    "--epf=0 --distance=1.0 --speed=cheetah"
    "--epf=2 --distance=1.0 --speed=cheetah"
    "--epf=0 --distance=8.0 --speed=cheetah"
    "--epf=1 --distance=8.0 --speed=cheetah"
    "--epf=2 --distance=8.0 --speed=cheetah"
    "--epf=3 --distance=8.0 --speed=cheetah"
    "--modular -Q 90"
    "--modular -Q 50"
    # Lossless options:
    "--modular"
    "--modular -E 0 -I 0"
    "--modular -P 5"
    "--modular --responsive=1"
    # Near-lossless options:
    "--epf=0 --distance=0.3 --speed=fast"
    "--modular -Q 97"
  )

  # Flags used for cjxl encoder with .jpg inputs. These should do lossless
  # JPEG recompression (of pixels or full jpeg).
  local jxl_jpeg_benchmarks=(
    "--num_reps=3"
  )

  local images=(
    "testdata/jxl/flower/flower.png"
  )

  local jpg_images=(
    "testdata/jxl/flower/flower.png.im_q85_420.jpg"
  )

  if [[ "${SKIP_CPUSET:-}" == "1" ]]; then
    # Use a single cpu config in this case.
    local cpu_confs=("?")
  else
    # Otherwise the CPU config comes from the environment:
    local cpu_confs=(
      "${RUNNER_CPU_LITTLE}"
      "${RUNNER_CPU_BIG}"
      # The CPU description is something like 3-7, so these configurations only
      # take the first CPU of the group.
      "${RUNNER_CPU_LITTLE%%-*}"
      "${RUNNER_CPU_BIG%%-*}"
    )
    # Check that RUNNER_CPU_ALL is defined. In the SKIP_CPUSET=1 case this will
    # be ignored but still evaluated when calling cmd_cpuset.
    [[ -n "${RUNNER_CPU_ALL}" ]]
  fi

  local jpg_dirname="third_party/corpora/jpeg"
  mkdir -p "${jpg_dirname}"
  local jpg_qualities=( 50 80 95 )
  for src_img in "${images[@]}"; do
    for q in "${jpg_qualities[@]}"; do
      local jpeg_name="${jpg_dirname}/"$(basename "${src_img}" .png)"-q${q}.jpg"
      convert -sampling-factor 1x1 -quality "${q}" \
        "${src_img}" "${jpeg_name}"
      jpg_images+=("${jpeg_name}")
    done
  done

  local output_dir="${BUILD_DIR}/benchmark_results"
  mkdir -p "${output_dir}"
  local runs_file="${output_dir}/runs.txt"

  if [[ ! -e "${runs_file}" ]]; then
    echo -e "binary\tflags\tsrc_img\tsrc size\tsrc pixels\tcpuset\tenc size (B)\tenc speed (MP/s)\tdec speed (MP/s)\tJPG dec speed (MP/s)\tJPG dec speed (MB/s)" |
      tee -a "${runs_file}"
  fi

  mkdir -p "${BUILD_DIR}/arm_benchmark"
  local flags
  local src_img
  for src_img in "${jpg_images[@]}" "${images[@]}"; do
    local src_img_hash=$(sha1sum "${src_img}" | cut -f 1 -d ' ')
    local enc_binaries=("${BUILD_DIR}/tools/cjxl")
    local src_ext="${src_img##*.}"
    for enc_binary in "${enc_binaries[@]}"; do
      local enc_binary_base=$(basename "${enc_binary}")

      # Select the list of flags to use for the current encoder/image pair.
      local img_benchmarks
      if [[ "${src_ext}" == "jpg" ]]; then
        img_benchmarks=("${jxl_jpeg_benchmarks[@]}")
      else
        img_benchmarks=("${jxl_png_benchmarks[@]}")
      fi

      for flags in "${img_benchmarks[@]}"; do
        # Encoding step.
        local enc_file_hash="${enc_binary_base} || $flags || ${src_img} || ${src_img_hash}"
        enc_file_hash=$(echo "${enc_file_hash}" | sha1sum | cut -f 1 -d ' ')
        local enc_file="${BUILD_DIR}/arm_benchmark/${enc_file_hash}.jxl"

        for cpu_conf in "${cpu_confs[@]}"; do
          cmd_cpuset "${cpu_conf}"
          # nproc returns the number of active CPUs, which is given by the cpuset
          # mask.
          local num_threads="$(nproc)"

          echo "Encoding with: ${enc_binary_base} img=${src_img} cpus=${cpu_conf} enc_flags=${flags}"
          local enc_output
          if [[ "${flags}" == *"modular"* ]]; then
            # We don't benchmark encoding speed in this case.
            if [[ ! -f "${enc_file}" ]]; then
              cmd_cpuset "${RUNNER_CPU_ALL:-}"
              "${enc_binary}" ${flags} "${src_img}" "${enc_file}.tmp"
              mv "${enc_file}.tmp" "${enc_file}"
              cmd_cpuset "${cpu_conf}"
            fi
            enc_output=" ?? MP/s"
          else
            wait_for_temp
            enc_output=$("${enc_binary}" ${flags} "${src_img}" "${enc_file}.tmp" \
              2>&1 | tee /dev/stderr | grep -F "MP/s [")
            mv "${enc_file}.tmp" "${enc_file}"
          fi
          local enc_speed=$(_speed_from_output "${enc_output}")
          local enc_size=$(stat -c "%s" "${enc_file}")

          echo "Decoding with: img=${src_img} cpus=${cpu_conf} enc_flags=${flags}"

          local dec_output
          wait_for_temp
          dec_output=$("${BUILD_DIR}/tools/djxl" "${enc_file}" \
            --num_reps=5 --num_threads="${num_threads}" 2>&1 | tee /dev/stderr |
            grep -E "M[BP]/s \[")
          local img_size=$(echo "${dec_output}" | cut -f 1 -d ',')
          local img_size_x=$(echo "${img_size}" | cut -f 1 -d ' ')
          local img_size_y=$(echo "${img_size}" | cut -f 3 -d ' ')
          local img_size_px=$(( ${img_size_x} * ${img_size_y} ))
          local dec_speed=$(_speed_from_output "${dec_output}")

          # For JPEG lossless recompression modes (where the original is a JPEG)
          # decode to JPG as well.
          local jpeg_dec_mps_speed=""
          local jpeg_dec_mbs_speed=""
          if [[ "${src_ext}" == "jpg" ]]; then
            wait_for_temp
            local dec_file="${BUILD_DIR}/arm_benchmark/${enc_file_hash}.jpg"
            dec_output=$("${BUILD_DIR}/tools/djxl" "${enc_file}" \
              "${dec_file}" --num_reps=5 --num_threads="${num_threads}" 2>&1 | \
                tee /dev/stderr | grep -E "M[BP]/s \[")
            local jpeg_dec_mps_speed=$(_speed_from_output "${dec_output}")
            local jpeg_dec_mbs_speed=$(_speed_from_output "${dec_output}" MB/s)
            if ! cmp --quiet "${src_img}" "${dec_file}"; then
              # Add a start at the end to signal that the files are different.
              jpeg_dec_mbs_speed+="*"
            fi
          fi

          # Record entry in a tab-separated file.
          local src_img_base=$(basename "${src_img}")
          echo -e "${enc_binary_base}\t${flags}\t${src_img_base}\t${img_size}\t${img_size_px}\t${cpu_conf}\t${enc_size}\t${enc_speed}\t${dec_speed}\t${jpeg_dec_mps_speed}\t${jpeg_dec_mbs_speed}" |
            tee -a "${runs_file}"
        done
      done
    done
  done
  cmd_cpuset "${RUNNER_CPU_ALL:-}"
  cat "${runs_file}"

  if [[ -n "${CI_BUILD_NAME:-}" ]]; then
    load_mr_vars_from_commit
    { set +x; } 2>/dev/null
    local message="Results for ${CI_BUILD_NAME} @ ${CI_COMMIT_SHORT_SHA} (job ${CI_JOB_URL:-}):

\`\`\`
$(column -t -s "	" "${runs_file}")
\`\`\`
"
    cmd_post_mr_comment "${message}"
    set -x
  fi
}

# Generate a corpus and run the fuzzer on that corpus.
cmd_fuzz() {
  local corpus_dir=$(realpath "${BUILD_DIR}/fuzzer_corpus")
  local fuzzer_crash_dir=$(realpath "${BUILD_DIR}/fuzzer_crash")
  mkdir -p "${corpus_dir}" "${fuzzer_crash_dir}"
  # Generate step.
  "${BUILD_DIR}/tools/fuzzer_corpus" "${corpus_dir}"
  # Run step:
  local nprocs=$(nproc --all || echo 1)
  (
   cd "${BUILD_DIR}"
   "tools/djxl_fuzzer" "${fuzzer_crash_dir}" "${corpus_dir}" \
     -max_total_time="${FUZZER_MAX_TIME}" -jobs=${nprocs} \
     -artifact_prefix="${fuzzer_crash_dir}/"
  )
}

# Runs the linters (clang-format, build_cleaner, buildirier) on the pending CLs.
cmd_lint() {
  merge_request_commits
  { set +x; } 2>/dev/null
  local versions=(${1:-16 15 14 13 12 11 10 9 8 7 6.0})
  local clang_format_bins=("${versions[@]/#/clang-format-}" clang-format)
  local tmpdir=$(mktemp -d)
  CLEANUP_FILES+=("${tmpdir}")

  local ret=0
  local build_patch="${tmpdir}/build_cleaner.patch"
  if ! "${MYDIR}/tools/scripts/build_cleaner.py" >"${build_patch}"; then
    ret=1
    echo "build_cleaner.py findings:" >&2
    "${COLORDIFF_BIN}" <"${build_patch}"
    echo "Run \`tools/scripts/build_cleaner.py --update\` to apply them" >&2
  fi

  # It is ok, if buildifier is not installed.
  if which buildifier >/dev/null; then
    local buildifier_patch="${tmpdir}/buildifier.patch"
    local bazel_files=`git -C ${MYDIR} ls-files | grep -E "/BUILD$|WORKSPACE|.bzl$"`
    set -x
    buildifier -d ${bazel_files} >"${buildifier_patch}"|| true
    { set +x; } 2>/dev/null
    if [ -s "${buildifier_patch}" ]; then
      ret=1
      echo 'buildifier have found some problems in Bazel build files:' >&2
      "${COLORDIFF_BIN}" <"${buildifier_patch}"
      echo 'To fix them run (from the base directory):' >&2
      echo '  buildifier `git ls-files | grep -E "/BUILD$|WORKSPACE|.bzl$"`' >&2
    fi
  fi

  local installed=()
  local clang_patch
  local clang_format
  for clang_format in "${clang_format_bins[@]}"; do
    if ! which "${clang_format}" >/dev/null; then
      continue
    fi
    installed+=("${clang_format}")
    local tmppatch="${tmpdir}/${clang_format}.patch"
    # We include in this linter all the changes including the uncommitted changes
    # to avoid printing changes already applied.
    set -x
    # Ignoring the error that git-clang-format outputs.
    git -C "${MYDIR}" "${clang_format}" --binary "${clang_format}" \
      --style=file --diff "${MR_ANCESTOR_SHA}" -- >"${tmppatch}" || true
    { set +x; } 2>/dev/null
    if grep -E '^--- ' "${tmppatch}" | grep -v 'a/third_party' >/dev/null; then
      if [[ -n "${LINT_OUTPUT:-}" ]]; then
        cp "${tmppatch}" "${LINT_OUTPUT}"
      fi
      clang_patch="${tmppatch}"
    else
      echo "clang-format check OK" >&2
      return ${ret}
    fi
  done

  if [[ ${#installed[@]} -eq 0 ]]; then
    echo "You must install clang-format for \"git clang-format\"" >&2
    exit 1
  fi

  # clang-format is installed but found problems.
  echo "clang-format findings:" >&2
  "${COLORDIFF_BIN}" < "${clang_patch}"

  echo "clang-format found issues in your patches from ${MR_ANCESTOR_SHA}" \
    "to the current patch. Run \`./ci.sh lint | patch -p1\` from the base" \
    "directory to apply them." >&2
  exit 1
}

# Runs clang-tidy on the pending CLs. If the "all" argument is passed it runs
# clang-tidy over all the source files instead.
cmd_tidy() {
  local what="${1:-}"

  if [[ -z "${CLANG_TIDY_BIN}" ]]; then
    echo "ERROR: You must install clang-tidy-7 or newer to use ci.sh tidy" >&2
    exit 1
  fi

  local git_args=()
  if [[ "${what}" == "all" ]]; then
    git_args=(ls-files)
    shift
  else
    merge_request_commits
    git_args=(
        diff-tree --no-commit-id --name-only -r "${MR_ANCESTOR_SHA}"
        "${MR_HEAD_SHA}"
    )
  fi

  # Clang-tidy needs the compilation database generated by cmake.
  if [[ ! -e "${BUILD_DIR}/compile_commands.json" ]]; then
    # Generate the build options in debug mode, since we need the debug asserts
    # enabled for the clang-tidy analyzer to use them.
    CMAKE_BUILD_TYPE="Debug"
    cmake_configure
    # Build the autogen targets to generate the .h files from the .ui files.
    local autogen_targets=(
        $(ninja -C "${BUILD_DIR}" -t targets | grep -F _autogen: |
          cut -f 1 -d :)
    )
    if [[ ${#autogen_targets[@]} != 0 ]]; then
      ninja -C "${BUILD_DIR}" "${autogen_targets[@]}"
    fi
  fi

  cd "${MYDIR}"
  local nprocs=$(nproc --all || echo 1)
  local ret=0
  if ! parallel -j"${nprocs}" --keep-order -- \
      "${CLANG_TIDY_BIN}" -p "${BUILD_DIR}" -format-style=file -quiet "$@" {} \
      < <(git "${git_args[@]}" | grep -E '(\.cc|\.cpp)$') \
      >"${BUILD_DIR}/clang-tidy.txt"; then
    ret=1
  fi
  { set +x; } 2>/dev/null
  echo "Findings statistics:" >&2
  grep -E ' \[[A-Za-z\.,\-]+\]' -o "${BUILD_DIR}/clang-tidy.txt" | sort \
    | uniq -c >&2

  if [[ $ret -ne 0 ]]; then
    cat >&2 <<EOF
Errors found, see ${BUILD_DIR}/clang-tidy.txt for details.
To automatically fix them, run:

  SKIP_TEST=1 ./ci.sh debug
  ${CLANG_TIDY_BIN} -p ${BUILD_DIR} -fix -format-style=file -quiet $@ \$(git ${git_args[@]} | grep -E '(\.cc|\.cpp)\$')
EOF
  fi

  return ${ret}
}

# Print stats about all the packages built in ${BUILD_DIR}/debs/.
cmd_debian_stats() {
  { set +x; } 2>/dev/null
  local debsdir="${BUILD_DIR}/debs"
  local f
  while IFS='' read -r -d '' f; do
    echo "====================================================================="
    echo "Package $f:"
    dpkg --info $f
    dpkg --contents $f
  done < <(find "${BUILD_DIR}/debs" -maxdepth 1 -mindepth 1 -type f \
           -name '*.deb' -print0)
}

build_debian_pkg() {
  local srcdir="$1"
  local srcpkg="$2"

  local debsdir="${BUILD_DIR}/debs"
  local builddir="${debsdir}/${srcpkg}"

  # debuild doesn't have an easy way to build out of tree, so we make a copy
  # of with all symlinks on the first level.
  mkdir -p "${builddir}"
  for f in $(find "${srcdir}" -mindepth 1 -maxdepth 1 -printf '%P\n'); do
    if [[ ! -L "${builddir}/$f" ]]; then
      rm -f "${builddir}/$f"
      ln -s "${srcdir}/$f" "${builddir}/$f"
    fi
  done
  (
    cd "${builddir}"
    debuild -b -uc -us
  )
}

cmd_debian_build() {
  local srcpkg="${1:-}"

  case "${srcpkg}" in
    jpeg-xl)
      build_debian_pkg "${MYDIR}" "jpeg-xl"
      ;;
    highway)
      build_debian_pkg "${MYDIR}/third_party/highway" "highway"
      ;;
    *)
      echo "ERROR: Must pass a valid source package name to build." >&2
      ;;
  esac
}

get_version() {
  local varname=$1
  local line=$(grep -F "set(${varname} " lib/CMakeLists.txt | head -n 1)
  [[ -n "${line}" ]]
  line="${line#set(${varname} }"
  line="${line%)}"
  echo "${line}"
}

cmd_bump_version() {
  local newver="${1:-}"

  if ! which dch >/dev/null; then
    echo "Missing dch\nTo install it run:\n  sudo apt install devscripts"
    exit 1
  fi

  if [[ -z "${newver}" ]]; then
    local major=$(get_version JPEGXL_MAJOR_VERSION)
    local minor=$(get_version JPEGXL_MINOR_VERSION)
    local patch=0
    minor=$(( ${minor}  + 1))
  else
    local major="${newver%%.*}"
    newver="${newver#*.}"
    local minor="${newver%%.*}"
    newver="${newver#${minor}}"
    local patch="${newver#.}"
    if [[ -z "${patch}" ]]; then
      patch=0
    fi
  fi

  newver="${major}.${minor}.${patch}"

  echo "Bumping version to ${newver} (${major}.${minor}.${patch})"
  sed -E \
    -e "s/(set\\(JPEGXL_MAJOR_VERSION) [0-9]+\\)/\\1 ${major})/" \
    -e "s/(set\\(JPEGXL_MINOR_VERSION) [0-9]+\\)/\\1 ${minor})/" \
    -e "s/(set\\(JPEGXL_PATCH_VERSION) [0-9]+\\)/\\1 ${patch})/" \
    -i lib/CMakeLists.txt
  sed -E \
    -e "s/(LIBJXL_VERSION: )[0-9\\.]+/\\1 ${major}.${minor}.${patch}/" \
    -e "s/(LIBJXL_ABI_VERSION: )[0-9\\.]+/\\1 ${major}.${minor}/" \
    -i .github/workflows/conformance.yml

  # Update lib.gni
  tools/scripts/build_cleaner.py --update

  # Mark the previous version as "unstable".
  DEBCHANGE_RELEASE_HEURISTIC=log dch -M --distribution unstable --release ''
  DEBCHANGE_RELEASE_HEURISTIC=log dch -M \
    --newversion "${newver}" \
    "Bump JPEG XL version to ${newver}."
}

# Check that the AUTHORS file contains the email of the committer.
cmd_authors() {
  merge_request_commits
  local emails
  local names
  readarray -t emails < <(git log --format='%ae' "${MR_ANCESTOR_SHA}..${MR_HEAD_SHA}")
  readarray -t names < <(git log --format='%an' "${MR_ANCESTOR_SHA}..${MR_HEAD_SHA}")
  for i in "${!names[@]}"; do
    echo "Checking name '${names[$i]}' with email '${emails[$i]}' ..."
    "${MYDIR}"/tools/scripts/check_author.py "${emails[$i]}" "${names[$i]}"
  done
}

main() {
  local cmd="${1:-}"
  if [[ -z "${cmd}" ]]; then
    cat >&2 <<EOF
Use: $0 CMD

Where cmd is one of:
 opt       Build and test a Release with symbols build.
 debug     Build and test a Debug build (NDEBUG is not defined).
 release   Build and test a striped Release binary without debug information.
 asan      Build and test an ASan (AddressSanitizer) build.
 msan      Build and test an MSan (MemorySanitizer) build. Needs to have msan
           c++ libs installed with msan_install first.
 tsan      Build and test a TSan (ThreadSanitizer) build.
 asanfuzz  Build and test an ASan (AddressSanitizer) build for fuzzing.
 msanfuzz  Build and test an MSan (MemorySanitizer) build for fuzzing.
 test      Run the tests build by opt, debug, release, asan or msan. Useful when
           building with SKIP_TEST=1.
 gbench    Run the Google benchmark tests.
 fuzz      Generate the fuzzer corpus and run the fuzzer on it. Useful after
           building with asan or msan.
 benchmark Run the benchmark over the default corpus.
 fast_benchmark Run the benchmark over the small corpus.

 coverage  Build and run tests with coverage support. Runs coverage_report as
           well.
 coverage_report Generate HTML, XML and text coverage report after a coverage
           run.

 lint      Run the linter checks on the current commit or merge request.
 tidy      Run clang-tidy on the current commit or merge request.
 authors   Check that the last commit's author is listed in the AUTHORS file.

 msan_install Install the libc++ libraries required to build in msan mode. This
              needs to be done once.

 debian_build <srcpkg> Build the given source package.
 debian_stats  Print stats about the built packages.

oss-fuzz commands:
 ossfuzz_asan   Build the local source inside oss-fuzz docker with asan.
 ossfuzz_msan   Build the local source inside oss-fuzz docker with msan.
 ossfuzz_ubsan  Build the local source inside oss-fuzz docker with ubsan.
 ossfuzz_ninja  Run ninja on the BUILD_DIR inside the oss-fuzz docker. Extra
                parameters are passed to ninja, for example "djxl_fuzzer" will
                only build that ninja target. Use for faster build iteration
                after one of the ossfuzz_*san commands.

You can pass some optional environment variables as well:
 - BUILD_DIR: The output build directory (by default "$$repo/build")
 - BUILD_TARGET: The target triplet used when cross-compiling.
 - CMAKE_FLAGS: Convenience flag to pass both CMAKE_C_FLAGS and CMAKE_CXX_FLAGS.
 - CMAKE_PREFIX_PATH: Installation prefixes to be searched by the find_package.
 - ENABLE_WASM_SIMD=1: enable experimental SIMD in WASM build (only).
 - FUZZER_MAX_TIME: "fuzz" command fuzzer running timeout in seconds.
 - LINT_OUTPUT: Path to the output patch from the "lint" command.
 - SKIP_CPUSET=1: Skip modifying the cpuset in the arm_benchmark.
 - SKIP_BUILD=1: Skip the build stage, cmake configure only.
 - SKIP_TEST=1: Skip the test stage.
 - STORE_IMAGES=0: Makes the benchmark discard the computed images.
 - TEST_STACK_LIMIT: Stack size limit (ulimit -s) during tests, in KiB.
 - TEST_SELECTOR: pass additional arguments to ctest, e.g. "-R .Resample.".
 - STACK_SIZE=1: Generate binaries with the .stack_sizes sections.

These optional environment variables are forwarded to the cmake call as
parameters:
 - CMAKE_BUILD_TYPE
 - CMAKE_C_FLAGS
 - CMAKE_CXX_FLAGS
 - CMAKE_C_COMPILER_LAUNCHER
 - CMAKE_CXX_COMPILER_LAUNCHER
 - CMAKE_CROSSCOMPILING_EMULATOR
 - CMAKE_FIND_ROOT_PATH
 - CMAKE_EXE_LINKER_FLAGS
 - CMAKE_MAKE_PROGRAM
 - CMAKE_MODULE_LINKER_FLAGS
 - CMAKE_SHARED_LINKER_FLAGS
 - CMAKE_TOOLCHAIN_FILE

Example:
  BUILD_DIR=/tmp/build $0 opt
EOF
    exit 1
  fi

  cmd="cmd_${cmd}"
  shift
  set -x
  "${cmd}" "$@"
}

main "$@"
