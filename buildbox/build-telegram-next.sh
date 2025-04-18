#!/bin/bash

set -e

MACOS_VERSION="12"
XCODE_VERSION="13.2.1"
GUEST_SHELL="bash"

if [ -z "$VIRTUALBUILD_HOST" ]; then
	echo "VIRTUALBUILD_HOST is not defined"
	exit 1
fi

VM_BASE_NAME="macos$(echo $MACOS_VERSION | sed -e 's/\.'/_/g)-Xcode$(echo $XCODE_VERSION | sed -e 's/\.'/_/g)"
echo "Base VM: \"$VM_BASE_NAME\""

if [ -z "$BAZEL" ]; then
	echo "BAZEL is not defined"
	exit 1
fi

if [ ! -f "$BAZEL" ]; then
	echo "bazel not found at $BAZEL"
	exit 1
fi

BUILDBOX_DIR="buildbox"

mkdir -p "$BUILDBOX_DIR/transient-data"

rm -f "tools/bazel"
cp "$BAZEL" "tools/bazel"

BUILD_CONFIGURATION="$1"

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental-2" ] || [ "$BUILD_CONFIGURATION" == "App Store-development" ]; then
	CODESIGNING_SUBPATH="$BUILDBOX_DIR/transient-data/telegram-codesigning/codesigning"
elif [ "$BUILD_CONFIGURATION" == "appstore" ]; then
	CODESIGNING_SUBPATH="$BUILDBOX_DIR/transient-data/telegram-codesigning/codesigning"
elif [ "$BUILD_CONFIGURATION" == "verify" ]; then
	CODESIGNING_SUBPATH="build-system/fake-codesigning"
else
	echo "Unknown configuration $1"
	exit 1
fi

COMMIT_COMMENT="$(git log -1 --pretty=%B)"
case "$COMMIT_COMMENT" in 
  *"[nocache]"*)
	export BAZEL_HTTP_CACHE_URL=""
    ;;
esac

COMMIT_ID="$(git rev-parse HEAD)"
COMMIT_AUTHOR=$(git log -1 --pretty=format:'%an')
if [ -z "$2" ]; then
	COMMIT_COUNT=$(git rev-list --count HEAD)
	BUILD_NUMBER_OFFSET="$(cat build_number_offset)"
	COMMIT_COUNT="$(($COMMIT_COUNT+$BUILD_NUMBER_OFFSET))"
	BUILD_NUMBER="$COMMIT_COUNT"
else
	BUILD_NUMBER="$2"
fi

BASE_DIR=$(pwd)

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental-2" ] || [ "$BUILD_CONFIGURATION" == "appstore" ] || [ "$BUILD_CONFIGURATION" == "appstore-development" ]; then
	if [ ! `which generate-configuration.sh` ]; then
		echo "generate-configuration.sh not found in PATH $PATH"
		exit 1
	fi

	mkdir -p "$BASE_DIR/$BUILDBOX_DIR/transient-data/telegram-codesigning"
	mkdir -p "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration"

	case "$BUILD_CONFIGURATION" in
		"hockeyapp"|"appcenter-experimental"|"appcenter-experimental-2")
			generate-configuration.sh internal release "$BASE_DIR/$BUILDBOX_DIR/transient-data/telegram-codesigning" "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration"
			;;

		"appstore")
			generate-configuration.sh appstore release "$BASE_DIR/$BUILDBOX_DIR/transient-data/telegram-codesigning" "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration"
			;;

		"appstore-development")
			generate-configuration.sh appstore development "$BASE_DIR/$BUILDBOX_DIR/transient-data/telegram-codesigning" "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration"
			;;

		*)
			echo "Unknown build configuration $BUILD_CONFIGURATION"
			exit 1
			;;
	esac
elif [ "$BUILD_CONFIGURATION" == "verify" ]; then
	mkdir -p "$BASE_DIR/$BUILDBOX_DIR/transient-data/telegram-codesigning"
	mkdir -p "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration"

	cp -R build-system/fake-codesigning/* "$BASE_DIR/$BUILDBOX_DIR/transient-data/telegram-codesigning/"
	cp -R build-system/example-configuration/* "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration/"
fi

if [ ! -d "$CODESIGNING_SUBPATH" ]; then
	echo "$CODESIGNING_SUBPATH does not exist"
	exit 1
fi

SOURCE_DIR=$(basename "$BASE_DIR")
rm -f "$BUILDBOX_DIR/transient-data/source.tar"
set -x
find . -type f -a -not -regex "\\." -a -not -regex ".*\\./git" -a -not -regex ".*\\./git/.*" -a -not -regex "\\./bazel-bin" -a -not -regex "\\./bazel-bin/.*" -a -not -regex "\\./bazel-out" -a -not -regex "\\./bazel-out/.*" -a -not -regex "\\./bazel-testlogs" -a -not -regex "\\./bazel-testlogs/.*" -a -not -regex "\\./bazel-telegram-ios" -a -not -regex "\\./bazel-telegram-ios/.*" -a -not -regex "\\./buildbox" -a -not -regex "\\./buildbox/.*" -a -not -regex "\\./buck-out" -a -not -regex "\\./buck-out/.*" -a -not -regex "\\./\\.buckd" -a -not -regex "\\./\\.buckd/.*" -a -not -regex "\\./build" -a -not -regex "\\./build/.*" -print0 | tar cf "$BUILDBOX_DIR/transient-data/source.tar" --null -T -

PROCESS_ID="$$"

initialization_params="$VM_BASE_NAME"
initialization_params="$initialization_params&watchpid=$PROCESS_ID"

ssh_credentials=$(curl --fail --insecure "https://$VIRTUALBUILD_HOST/run-image?name=$initialization_params")

ssh_username=$(echo "$ssh_credentials" | python3 -c "import sys, json; print(json.load(sys.stdin)['sshCredentials']['username'])")
ssh_host=$(echo "$ssh_credentials" | python3 -c "import sys, json; print(json.load(sys.stdin)['sshCredentials']['host'])")
ssh_privateKey=$(echo "$ssh_credentials" | python3 -c "import sys, json; print(json.load(sys.stdin)['sshCredentials']['privateKey'])")

ssh_privateKeyFile=$(mktemp)
echo "$ssh_privateKey" | base64 --decode > "$ssh_privateKeyFile"

scp -i "$ssh_privateKeyFile" -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$CODESIGNING_SUBPATH" $ssh_username@"$ssh_host":codesigning_data
scp -i "$ssh_privateKeyFile" -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration" $ssh_username@"$ssh_host":telegram-configuration

scp -i "$ssh_privateKeyFile" -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/guest-build-telegram.sh" "$BUILDBOX_DIR/transient-data/source.tar" $ssh_username@"$ssh_host":

ssh -i "$ssh_privateKeyFile" -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $ssh_username@"$ssh_host" -o ServerAliveInterval=60 -t "export BUILD_NUMBER=\"$BUILD_NUMBER\"; export BAZEL_HTTP_CACHE_URL=\"$BAZEL_HTTP_CACHE_URL\"; $GUEST_SHELL -l guest-build-telegram.sh $BUILD_CONFIGURATION" || true

OUTPUT_PATH="build/artifacts"
rm -rf "$OUTPUT_PATH"
mkdir -p "$OUTPUT_PATH"

scp -i "$ssh_privateKeyFile" -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr $ssh_username@"$ssh_host":"telegram-ios/build/artifacts/*" "$OUTPUT_PATH/"

if [ ! -f "$OUTPUT_PATH/Telegram.ipa" ]; then
	exit 1
fi
