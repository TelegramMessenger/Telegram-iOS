#!/bin/bash

set -e

BUILD_TELEGRAM_VERSION="1"

MACOS_VERSION="11"
XCODE_VERSION="13.2.1"
GUEST_SHELL="bash"

VM_BASE_NAME="macos$(echo $MACOS_VERSION | sed -e 's/\.'/_/g)_Xcode$(echo $XCODE_VERSION | sed -e 's/\.'/_/g)"
echo "Base VM: \"$VM_BASE_NAME\""

case "$(uname -s)" in
    Linux*)     BUILD_MACHINE=linux;;
    Darwin*)    BUILD_MACHINE=macOS;;
    *)          BUILD_MACHINE=""
esac

if [ "$BUILD_MACHINE" == "linux" ]; then
	for MACHINE in $(virsh list --all --name); do
		if [ "$MACHINE" == "$VM_BASE_NAME" ]; then
			FOUND_BASE_MACHINE="1"
			break
		fi
	done
	if [ -z "$FOUND_BASE_MACHINE" ]; then
		echo "Virtual machine $VM_BASE_NAME not found"
		exit 1
	fi
elif [ "$BUILD_MACHINE" == "macOS" ]; then
	echo "Building on macOS"
else
	echo "Unknown build machine $(uname -s)"
fi

if [ `which cleanup-telegram-build-vms.sh` ]; then
	cleanup-telegram-build-vms.sh
fi

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

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental-2" ]; then
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

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental-2" ] || [ "$BUILD_CONFIGURATION" == "appstore" ]; then
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

if [ -z "$RUNNING_VM" ]; then
	VM_NAME="$VM_BASE_NAME-$(openssl rand -hex 10)-build-telegram-$PROCESS_ID"
else
	VM_NAME="$RUNNING_VM"
fi

if [ "$BUILD_MACHINE" == "linux" ]; then
	virt-clone --original "$VM_BASE_NAME" --name "$VM_NAME" --auto-clone
	virsh start "$VM_NAME"

	echo "Getting VM IP"

	while [ 1 ]; do
		TEST_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | egrep -o 'ipv4.*' | sed -e 's/ipv4\s*//g' | sed -e 's|/.*||g')
		if [ ! -z "$TEST_IP" ]; then
			RESPONSE=$(ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$TEST_IP" -o ServerAliveInterval=60 -t "echo -n 1")
			if [ "$RESPONSE" == "1" ]; then
				VM_IP="$TEST_IP"
				break
			fi
		fi
		sleep 1
	done
elif [ "$BUILD_MACHINE" == "macOS" ]; then
	if [ -z "$RUNNING_VM" ]; then
		prlctl clone "$VM_BASE_NAME" --linked --name "$VM_NAME"
		prlctl start "$VM_NAME"

		echo "Getting VM IP"

		while [ 1 ]; do
			TEST_IP=$(prlctl exec "$VM_NAME" "ifconfig | grep inet | grep broadcast | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | tr '\n' '\0'" 2>/dev/null || echo "")
			if [ ! -z "$TEST_IP" ]; then
				RESPONSE=$(ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$TEST_IP" -o ServerAliveInterval=60 -t "echo -n 1")
				if [ "$RESPONSE" == "1" ]; then
					VM_IP="$TEST_IP"
					break
				fi
			fi
			sleep 1
		done
	fi
	echo "VM_IP=$VM_IP"
fi

scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$CODESIGNING_SUBPATH" telegram@"$VM_IP":codesigning_data
scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BASE_DIR/$BUILDBOX_DIR/transient-data/build-configuration" telegram@"$VM_IP":telegram-configuration

scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/guest-build-telegram.sh" "$BUILDBOX_DIR/transient-data/source.tar" telegram@"$VM_IP":

ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "export BUILD_NUMBER=\"$BUILD_NUMBER\"; export BAZEL_HTTP_CACHE_URL=\"$BAZEL_HTTP_CACHE_URL\"; $GUEST_SHELL -l guest-build-telegram.sh $BUILD_CONFIGURATION" || true

OUTPUT_PATH="build/artifacts"
rm -rf "$OUTPUT_PATH"
mkdir -p "$OUTPUT_PATH"

scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr telegram@"$VM_IP":"telegram-ios/build/artifacts/*" "$OUTPUT_PATH/"

if [ -z "$RUNNING_VM" ]; then
	if [ "$BUILD_MACHINE" == "linux" ]; then
		virsh destroy "$VM_NAME"
		virsh undefine "$VM_NAME" --remove-all-storage --nvram
	elif [ "$BUILD_MACHINE" == "macOS" ]; then
		echo "Deleting VM..."
		#prlctl stop "$VM_NAME" --kill
		#prlctl delete "$VM_NAME"
	fi
fi

if [ ! -f "$OUTPUT_PATH/Telegram.ipa" ]; then
	exit 1
fi
