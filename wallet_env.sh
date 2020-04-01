#!/bin/sh

set -e

REQUIRED_BAZEL_VERSION="$(cat build-system/bazel_version)"

if which bazel >/dev/null 2>&1; then
	export BAZEL="$(which bazel)"
else
	echo "bazel not found in PATH"
	echo "Please download bazel version $REQUIRED_BAZEL_VERSION:"
	echo "https://github.com/bazelbuild/bazel/releases"
	exit 1
fi

BAZEL_VERSION="$($BAZEL --version | sed -e 's/^bazel '//)"

if [ "$BAZEL_VERSION" != "$REQUIRED_BAZEL_VERSION" ]; then
	echo "Required bazel version is \"$REQUIRED_BAZEL_VERSION\", you have \"$BAZEL_VERSION\" installed ($BAZEL)"
	exit 1
fi

if [ "$DEVELOPMENT_CODE_SIGN_IDENTITY" == "" ]; then
	echo "Set DEVELOPMENT_CODE_SIGN_IDENTITY to the name of a valid development certificate\nExample: export DEVELOPMENT_CODE_SIGN_IDENTITY=\"iPhone Developer: XXXXXXXXXX (XXXXXXXXXX)\""
	exit 1
fi

if [ "$DISTRIBUTION_CODE_SIGN_IDENTITY" == "" ]; then
	echo "Set DISTRIBUTION_CODE_SIGN_IDENTITY to the name of a valid distribution certificate\nExample: export DISTRIBUTION_CODE_SIGN_IDENTITY=\"iPhone Distribution: XXXXXXXXXX (XXXXXXXXXX)\""
	exit 1
fi

if [ "$WALLET_DEVELOPMENT_TEAM" == "" ]; then
	echo "Set WALLET_DEVELOPMENT_TEAM to the name of your development team\nExample: export WALLET_DEVELOPMENT_TEAM=\"XXXXXXXXXX\""
	exit 1
fi

if [ "$WALLET_BUNDLE_ID" == "" ]; then
	echo "Set WALLET_BUNDLE_ID to a valid bundle ID\nExample: export WALLET_BUNDLE_ID=\"org.mycompany.TonWallet-iOS\""
	exit 1
fi

if [ "$WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP" == "" ]; then
	echo "Set WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP to the name of a valid development provisioning profile corresponding to the chosen bundle ID ($WALLET_BUNDLE_ID)\nExample: export WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP=\"Development $WALLET_BUNDLE_ID\""
	exit 1
fi

if [ "$WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP" == "" ]; then
	echo "Set WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP to the name of a valid distribution provisioning profile corresponding to the chosen bundle ID ($WALLET_BUNDLE_ID)\nExample: export WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP=\"AppStore $WALLET_BUNDLE_ID\""
	exit 1
fi

export DEVELOPMENT_CODE_SIGN_IDENTITY="$DEVELOPMENT_CODE_SIGN_IDENTITY"
export DISTRIBUTION_CODE_SIGN_IDENTITY="$DISTRIBUTION_CODE_SIGN_IDENTITY"
export WALLET_DEVELOPMENT_TEAM="$WALLET_DEVELOPMENT_TEAM"
export WALLET_BUNDLE_ID="$WALLET_BUNDLE_ID"
export WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP="$WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP"
export WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP="$WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP"

$@
