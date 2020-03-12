#!/bin/sh

set -e

BUILD_TYPE="$1"
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

DATA_DIRECTORY="build-input/data"
rm -rf "$DATA_DIRECTORY"
mkdir -p "$DATA_DIRECTORY"
touch "$DATA_DIRECTORY/BUILD"

source "$BASE_PATH/copy-provisioning-profiles.sh"
source "$BASE_PATH/prepare-build-variables.sh"

echo "Copying provisioning profiles..."
copy_provisioning_profiles "$PROFILES_TYPE"

echo "Preparing build variables..."
prepare_build_variables "$BUILD_TYPE"
