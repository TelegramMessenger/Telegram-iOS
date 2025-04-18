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
		APP_VERSION \
		BUNDLE_ID \
		DEVELOPMENT_TEAM \
		API_ID \
		API_HASH \
		APP_CENTER_ID \
		IS_INTERNAL_BUILD \
		IS_APPSTORE_BUILD \
		APPSTORE_ID \
		APP_SPECIFIC_URL_SCHEME \
		PREMIUM_IAP_PRODUCT_ID \
		TELEGRAM_DISABLE_EXTENSIONS \
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

	echo "telegram_build_number = \"$BUILD_NUMBER\"" >> "$VARIABLES_PATH"
	echo "telegram_version = \"$APP_VERSION\"" >> "$VARIABLES_PATH"
	echo "telegram_bundle_id = \"$BUNDLE_ID\"" >> "$VARIABLES_PATH"	
	echo "telegram_api_id = \"$API_ID\"" >> "$VARIABLES_PATH"
	echo "telegram_team_id = \"$DEVELOPMENT_TEAM\"" >> "$VARIABLES_PATH"
	echo "telegram_api_hash = \"$API_HASH\"" >> "$VARIABLES_PATH"
	echo "telegram_app_center_id = \"$APP_CENTER_ID\"" >> "$VARIABLES_PATH"
	echo "telegram_is_internal_build = \"$IS_INTERNAL_BUILD\"" >> "$VARIABLES_PATH"
	echo "telegram_is_appstore_build = \"$IS_APPSTORE_BUILD\"" >> "$VARIABLES_PATH"
	echo "telegram_appstore_id = \"$APPSTORE_ID\"" >> "$VARIABLES_PATH"
	echo "telegram_app_specific_url_scheme = \"$APP_SPECIFIC_URL_SCHEME\"" >> "$VARIABLES_PATH"
	echo "telegram_premium_iap_product_id = \"$PREMIUM_IAP_PRODUCT_ID\"" >> "$VARIABLES_PATH"
	echo "telegram_aps_environment = \"$APS_ENVIRONMENT\"" >> "$VARIABLES_PATH"

	if [  "$TELEGRAM_DISABLE_EXTENSIONS" == "1" ]; then
		echo "telegram_disable_extensions = True" >> "$VARIABLES_PATH"
	else
		echo "telegram_disable_extensions = False" >> "$VARIABLES_PATH"
	fi
}
