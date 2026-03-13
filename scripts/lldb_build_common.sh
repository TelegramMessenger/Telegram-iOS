#!/bin/bash

# Stores common functionality for build and launch tasks.

set -e

export WORKSPACE_ROOT
WORKSPACE_ROOT=$(pwd)

BAZEL_CMD="./build-input/bazel-8.4.2-darwin-arm64"

export ADDITIONAL_FLAGS=()

ADDITIONAL_FLAGS+=("--keep_going")
ADDITIONAL_FLAGS+=("--color=yes")

if [ -n "${BAZEL_EXTRA_BUILD_FLAGS:-}" ]; then
  ADDITIONAL_FLAGS+=("${BAZEL_EXTRA_BUILD_FLAGS[@]}")
fi

LAUNCH_ARGS_ARRAY=()
if [ -n "${BAZEL_LAUNCH_ARGS:-}" ]; then
  read -ra LAUNCH_ARGS_ARRAY <<< "$BAZEL_LAUNCH_ARGS"
fi

function run_bazel() {
  local command="$1"
  ${BAZEL_CMD} "${command}" "${BAZEL_LABEL_TO_RUN}" "${ADDITIONAL_FLAGS[@]}" ${LAUNCH_ARGS_ARRAY[@]:+-- "${LAUNCH_ARGS_ARRAY[@]}"}
}
