#!/bin/sh

set -e

APP_TARGET="$1"
if [ "$APP_TARGET" == "" ]; then
	echo "Usage: sh prepare-build.sh app_target development|distribution"
	exit 1
fi

BUILD_TYPE="$2"
case "$BUILD_TYPE" in
	development)
    	PROFILES_TYPE="development"
		;;
	distribution)
	    PROFILES_TYPE="distribution"
	    ;;
	*)
	    echo "Unknown build provisioning type: $BUILD_TYPE"
	    exit 1
	    ;;
esac

BASE_PATH=$(dirname $0)

COPY_PROVISIONING_PROFILES_SCRIPT="$BASE_PATH/copy-provisioning-profiles-$APP_TARGET.sh"
PREPARE_BUILD_VARIABLES_SCRIPT="$BASE_PATH/prepare-build-variables-$APP_TARGET.sh"

if [ ! -f "$COPY_PROVISIONING_PROFILES_SCRIPT" ]; then
	echo "$COPY_PROVISIONING_PROFILES_SCRIPT not found"
	exit 1
fi

if [ ! -f "$PREPARE_BUILD_VARIABLES_SCRIPT" ]; then
	echo "$PREPARE_BUILD_VARIABLES_SCRIPT not found"
	exit 1
fi

DATA_DIRECTORY="build-input/data"
rm -rf "$DATA_DIRECTORY"
mkdir -p "$DATA_DIRECTORY"
touch "$DATA_DIRECTORY/BUILD"

source "$COPY_PROVISIONING_PROFILES_SCRIPT"
source "$PREPARE_BUILD_VARIABLES_SCRIPT"

echo "Copying provisioning profiles..."
copy_provisioning_profiles "$PROFILES_TYPE"

echo "Preparing build variables..."
prepare_build_variables "$BUILD_TYPE"
