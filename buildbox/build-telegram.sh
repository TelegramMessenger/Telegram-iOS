#!/bin/bash

set -e

BUILD_TELEGRAM_VERSION="1"

MACOS_VERSION="10.15"
XCODE_VERSION="11.2"
GUEST_SHELL="bash"

VM_BASE_NAME="macos$(echo $MACOS_VERSION | sed -e 's/\.'/_/g)_Xcode$(echo $XCODE_VERSION | sed -e 's/\.'/_/g)"

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

if [ -z "$BUCK" ]; then
	echo "BUCK is not defined"
	exit 1
fi

if [ ! -f "$BUCK" ]; then
	echo "buck not found at $BUCK"
	exit 1
fi

BUILDBOX_DIR="buildbox"

mkdir -p "$BUILDBOX_DIR/transient-data"

rm -f "tools/buck"
cp "$BUCK" "tools/buck"

BUILD_CONFIGURATION="$1"

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ]; then
	CODESIGNING_SUBPATH="transient-data/codesigning"
	CODESIGNING_TEAMS_SUBPATH="transient-data/teams"
elif [ "$BUILD_CONFIGURATION" == "appstore" ]; then
	CODESIGNING_SUBPATH="transient-data/codesigning"
	CODESIGNING_TEAMS_SUBPATH="transient-data/teams"
elif [ "$BUILD_CONFIGURATION" == "verify" ]; then
	CODESIGNING_SUBPATH="fake-codesigning"
else
	echo "Unknown configuration $1"
	exit 1
fi

COMMIT_COMMENT="$(git log -1 --pretty=%B)"
case "$COMMIT_COMMENT" in 
  *"[nocache]"*)
	export BUCK_HTTP_CACHE=""
    ;;
esac

COMMIT_ID="$(git rev-parse HEAD)"
COMMIT_AUTHOR=$(git log -1 --pretty=format:'%an')
if [ -z "$2" ]; then
	COMMIT_COUNT=$(git rev-list --count HEAD)
	COMMIT_COUNT="$(($COMMIT_COUNT+1000))"
	BUILD_NUMBER="$COMMIT_COUNT"
else
	BUILD_NUMBER="$2"
fi

BASE_DIR=$(pwd)

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ] || [ "$BUILD_CONFIGURATION" == "appstore" ]; then
	if [ ! `which setup-telegram-build.sh` ]; then
		echo "setup-telegram-build.sh not found in PATH $PATH"
		exit 1
	fi
	if [ ! `which setup-codesigning.sh` ]; then
		echo "setup-codesigning.sh not found in PATH $PATH"
		exit 1
	fi
	source `which setup-telegram-build.sh`
	setup_telegram_build "$BUILD_CONFIGURATION" "$BASE_DIR/$BUILDBOX_DIR/transient-data"
	source `which setup-codesigning.sh`
	setup_codesigning "$BUILD_CONFIGURATION" "$BASE_DIR/$BUILDBOX_DIR/transient-data"
	if [ "$SETUP_TELEGRAM_BUILD_VERSION" != "$BUILD_TELEGRAM_VERSION" ]; then
		echo "setup-telegram-build.sh script version doesn't match"
		exit 1
	fi
	if [ "$BUILD_CONFIGURATION" == "appstore" ]; then
		if [ -z "$TELEGRAM_BUILD_APPSTORE_PASSWORD" ]; then
			echo "TELEGRAM_BUILD_APPSTORE_PASSWORD is not set"
			exit 1
		fi
		if [ -z "$TELEGRAM_BUILD_APPSTORE_TEAM_NAME" ]; then
			echo "TELEGRAM_BUILD_APPSTORE_TEAM_NAME is not set"
			exit 1
		fi
		if [ -z "$TELEGRAM_BUILD_APPSTORE_USERNAME" ]; then
			echo "TELEGRAM_BUILD_APPSTORE_USERNAME is not set"
			exit 1
		fi
	fi
fi

if [ ! -d "$BUILDBOX_DIR/$CODESIGNING_SUBPATH" ]; then
	echo "$BUILDBOX_DIR/$CODESIGNING_SUBPATH does not exist"
	exit 1
fi

SOURCE_DIR=$(basename "$BASE_DIR")
rm -f "$BUILDBOX_DIR/transient-data/source.tar"
tar cf "$BUILDBOX_DIR/transient-data/source.tar" --exclude "$BUILDBOX_DIR" --exclude ".git" --exclude "buck-out" --exclude ".buckd" --exclude "build" "."

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

scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/$CODESIGNING_SUBPATH" telegram@"$VM_IP":codesigning_data
scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/$CODESIGNING_TEAMS_SUBPATH" telegram@"$VM_IP":codesigning_teams

if [ "$BUILD_CONFIGURATION" == "verify" ]; then
	ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "mkdir -p telegram-ios-shared/fastlane; echo '' > telegram-ios-shared/fastlane/Fastfile"
else
	scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/transient-data/telegram-ios-shared" telegram@"$VM_IP":telegram-ios-shared
fi
scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/guest-build-telegram.sh" "$BUILDBOX_DIR/transient-data/source.tar" telegram@"$VM_IP":

ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "export TELEGRAM_BUILD_APPSTORE_PASSWORD=\"$TELEGRAM_BUILD_APPSTORE_PASSWORD\"; export TELEGRAM_BUILD_APPSTORE_TEAM_NAME=\"$TELEGRAM_BUILD_APPSTORE_TEAM_NAME\"; export TELEGRAM_BUILD_APPSTORE_USERNAME=\"$TELEGRAM_BUILD_APPSTORE_USERNAME\"; export BUILD_NUMBER=\"$BUILD_NUMBER\"; export COMMIT_ID=\"$COMMIT_ID\"; export COMMIT_AUTHOR=\"$COMMIT_AUTHOR\"; export BUCK_HTTP_CACHE=\"$BUCK_HTTP_CACHE\"; export BUCK_DIR_CACHE=\"$BUCK_DIR_CACHE\"; export BUCK_CACHE_MODE=\"$BUCK_CACHE_MODE\"; $GUEST_SHELL -l guest-build-telegram.sh $BUILD_CONFIGURATION" || true

OUTPUT_PATH="build/artifacts"
rm -rf "$OUTPUT_PATH"
mkdir -p "$OUTPUT_PATH"

scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr telegram@"$VM_IP":"telegram-ios/build/artifacts/*" "$OUTPUT_PATH/"

if [ -z "$RUNNING_VM" ]; then
	if [ "$BUILD_MACHINE" == "linux" ]; then
		virsh destroy "$VM_NAME"
		virsh undefine "$VM_NAME" --remove-all-storage --nvram
	elif [ "$BUILD_MACHINE" == "macOS" ]; then
		prlctl stop "$VM_NAME" --kill
		prlctl delete "$VM_NAME"
	fi
fi

if [ ! -f "$OUTPUT_PATH/Telegram.ipa" ]; then
	exit 1
fi
