#!/bin/sh

set -e

prepare_build_variables () {
	BUILD_TYPE="$1"
	case "$BUILD_TYPE" in
		development)
	    	APS_ENVIRONMENT="development"
			;;
		distribution)
		    APS_ENVIRONMENT="production"
		    ;;
		*)
		    echo "Unknown build provisioning type: $BUILD_TYPE"
		    exit 1
		    ;;
	esac

	local BAZEL="$(which bazel)"
	if [ "$BAZEL" = "" ]; then
		echo "bazel not found in PATH"
		exit 1
	fi

	local EXPECTED_VARIABLES=(\
		BUILD_NUMBER \
		WALLET_APP_VERSION \
		WALLET_BUNDLE_ID \
		WALLET_DEVELOPMENT_TEAM \
	)

	local MISSING_VARIABLES="0"
	for VARIABLE_NAME in ${EXPECTED_VARIABLES[@]}; do
		if [ "${!VARIABLE_NAME}" = "" ]; then
			echo "$VARIABLE_NAME not defined"
			MISSING_VARIABLES="1"
		fi
	done

	if [ "$MISSING_VARIABLES" == "1" ]; then
		exit 1
	fi

	local VARIABLES_DIRECTORY="build-input/data"
	mkdir -p "$VARIABLES_DIRECTORY"
	local VARIABLES_PATH="$VARIABLES_DIRECTORY/variables.bzl"
	rm -f "$VARIABLES_PATH"

	echo "wallet_build_number = \"$BUILD_NUMBER\"" >> "$VARIABLES_PATH"
	echo "wallet_version = \"$WALLET_APP_VERSION\"" >> "$VARIABLES_PATH"
	echo "wallet_bundle_id = \"$WALLET_BUNDLE_ID\"" >> "$VARIABLES_PATH"	
	echo "wallet_api_id = \"$WALLET_API_ID\"" >> "$VARIABLES_PATH"
	echo "wallet_team_id = \"$WALLET_DEVELOPMENT_TEAM\"" >> "$VARIABLES_PATH"

	echo "telegram_api_id = \"1\"" >> "$VARIABLES_PATH"
	echo "telegram_api_hash = \"1\"" >> "$VARIABLES_PATH"
	echo "telegram_app_center_id = \"1\"" >> "$VARIABLES_PATH"
	echo "telegram_appstore_id = \"1\"" >> "$VARIABLES_PATH"
	echo "telegram_is_internal_build = \"false\"" >> "$VARIABLES_PATH"
	echo "telegram_is_appstore_build = \"true\"" >> "$VARIABLES_PATH"
	echo "telegram_app_specific_url_scheme = \"\"" >> "$VARIABLES_PATH"
}
