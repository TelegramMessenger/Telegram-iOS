#!/usr/bin/python3

import argparse
import json
import os
import sys
import shlex
import shutil
import subprocess
import time

from darwin_containers import DarwinContainers

def get_clean_env():
    clean_env = os.environ.copy()
    return clean_env

def resolve_executable(program):
	def is_executable(fpath):
		return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

	for path in get_clean_env()["PATH"].split(os.pathsep):
		executable_file = os.path.join(path, program)
		if is_executable(executable_file):
			return executable_file
	return None


def run_executable_with_output(path, arguments):
	executable_path = resolve_executable(path)
	if executable_path is None:
		raise Exception('Could not resolve {} to a valid executable file'.format(path))

	process = subprocess.Popen(
		[executable_path] + arguments,
		stdout=subprocess.PIPE,
		stderr=subprocess.STDOUT,
		env=get_clean_env()
	)
	output_data, _ = process.communicate()
	output_string = output_data.decode('utf-8')
	return output_string

def session_scp_upload(session, source_path, destination_path):
	scp_command = 'scp -i {privateKeyPath} -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr {source_path} containerhost@"{ipAddress}":{destination_path}'.format(
		privateKeyPath=session.privateKeyPath,
		ipAddress=session.ipAddress,
		source_path=shlex.quote(source_path),
		destination_path=shlex.quote(destination_path)
	)
	if os.system(scp_command) != 0:
		print('Command {} finished with a non-zero status'.format(scp_command))

def session_ssh(session, command):
	ssh_command = 'ssh -i {privateKeyPath} -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null containerhost@"{ipAddress}" -o ServerAliveInterval=60 -t "{command}"'.format(
		privateKeyPath=session.privateKeyPath,
		ipAddress=session.ipAddress,
		command=command
	)
	return os.system(ssh_command)

def remote_build(darwin_containers_host, configuration):
	base_dir = os.getcwd()

	configuration_path = 'versions.json'
	xcode_version = ''
	with open(configuration_path) as file:
		configuration_dict = json.load(file)
		if configuration_dict['xcode'] is None:
			raise Exception('Missing xcode version in {}'.format(configuration_path))
		xcode_version = configuration_dict['xcode']

	print('Xcode version: {}'.format(xcode_version))

	commit_count = run_executable_with_output('git', [
		'rev-list',
		'--count',
		'HEAD'
	])

	build_number_offset = 0
	with open('build_number_offset') as file:
		build_number_offset = int(file.read())

	build_number = build_number_offset + int(commit_count)
	print('Build number: {}'.format(build_number))

	macos_version = '12.5'
	image_name = 'macos-{macos_version}-xcode-{xcode_version}'.format(macos_version=macos_version, xcode_version=xcode_version)

	print('Image name: {}'.format(image_name))

	buildbox_dir = 'buildbox'
	os.makedirs('{buildbox_dir}/transient-data'.format(buildbox_dir=buildbox_dir), exist_ok=True)

	codesigning_subpath = ''
	remote_configuration = ''
	if configuration == 'appcenter':
		remote_configuration = 'hockeyapp'
	elif configuration == 'appstore':
		remote_configuration = 'appstore'
	elif configuration == 'reproducible':
		codesigning_subpath = 'build-system/fake-codesigning'
		remote_configuration = 'verify'

		destination_codesigning_path = '{buildbox_dir}/transient-data/telegram-codesigning'.format(buildbox_dir=buildbox_dir)
		destination_build_configuration_path = '{buildbox_dir}/transient-data/build-configuration'.format(buildbox_dir=buildbox_dir)

		if os.path.exists(destination_codesigning_path):
			shutil.rmtree(destination_codesigning_path)
		if os.path.exists(destination_build_configuration_path):
			shutil.rmtree(destination_build_configuration_path)

		shutil.copytree('build-system/fake-codesigning', '{buildbox_dir}/transient-data/telegram-codesigning'.format(buildbox_dir=buildbox_dir))
		shutil.copytree('build-system/example-configuration', '{buildbox_dir}/transient-data/build-configuration'.format(buildbox_dir=buildbox_dir))
	else:
		print('Unknown configuration {}'.format(configuration))
		sys.exit(1)

	source_dir = os.path.basename(base_dir)
	source_archive_path = '{buildbox_dir}/transient-data/source.tar'.format(buildbox_dir=buildbox_dir)

	if os.path.exists(source_archive_path):
		os.remove(source_archive_path)

	print('Compressing source code...')
	os.system('find . -type f -a -not -regex "\\." -a -not -regex ".*\\./git" -a -not -regex ".*\\./git/.*" -a -not -regex "\\./bazel-bin" -a -not -regex "\\./bazel-bin/.*" -a -not -regex "\\./bazel-out" -a -not -regex "\\./bazel-out/.*" -a -not -regex "\\./bazel-testlogs" -a -not -regex "\\./bazel-testlogs/.*" -a -not -regex "\\./bazel-telegram-ios" -a -not -regex "\\./bazel-telegram-ios/.*" -a -not -regex "\\./buildbox" -a -not -regex "\\./buildbox/.*" -a -not -regex "\\./buck-out" -a -not -regex "\\./buck-out/.*" -a -not -regex "\\./\\.buckd" -a -not -regex "\\./\\.buckd/.*" -a -not -regex "\\./build" -a -not -regex "\\./build/.*" -print0 | tar cf "{buildbox_dir}/transient-data/source.tar" --null -T -'.format(buildbox_dir=buildbox_dir))

	darwinContainers = DarwinContainers(serverAddress=darwin_containers_host, verbose=False)

	print('Opening container session...')
	with darwinContainers.workingImageSession(name=image_name) as session:
		print('Uploading data to container...')
		session_scp_upload(session=session, source_path=codesigning_subpath, destination_path='codesigning_data')
		session_scp_upload(session=session, source_path='{base_dir}/{buildbox_dir}/transient-data/build-configuration'.format(base_dir=base_dir, buildbox_dir=buildbox_dir), destination_path='telegram-configuration')
		session_scp_upload(session=session, source_path='{base_dir}/{buildbox_dir}/guest-build-telegram.sh'.format(base_dir=base_dir, buildbox_dir=buildbox_dir), destination_path='')
		session_scp_upload(session=session, source_path='{base_dir}/{buildbox_dir}/transient-data/source.tar'.format(base_dir=base_dir, buildbox_dir=buildbox_dir), destination_path='')

		print('Executing remote build...')

		bazel_cache_host=''
		session_ssh(session=session, command='BUILD_NUMBER="{build_number}" BAZEL_HTTP_CACHE_URL="{bazel_cache_host}" bash -l guest-build-telegram.sh {remote_configuration}'.format(
			build_number=build_number,
			bazel_cache_host=bazel_cache_host,
			remote_configuration=remote_configuration
		))

		print('Retrieving build artifacts...')

		artifacts_path='{base_dir}/build/artifacts'.format(base_dir=base_dir)
		if os.path.exists(artifacts_path):
			shutil.rmtree(artifacts_path)
		os.makedirs(artifacts_path, exist_ok=True)

		session_scp_download(session=session, source_path='telegram-ios/build/artifacts/*', destination_path='{artifacts_path}/'.format(artifacts_path=artifacts_path))
		print('Artifacts have been stored at {}'.format(artifacts_path))

if __name__ == '__main__':
	parser = argparse.ArgumentParser(prog='build')

	parser.add_argument(
		'--verbose',
		action='store_true',
		default=False,
		help='Print debug info'
	)

	subparsers = parser.add_subparsers(dest='commandName', help='Commands')

	remote_build_parser = subparsers.add_parser('remote-build', help='Build the app using a remote environment.')
	remote_build_parser.add_argument(
		'--darwinContainersHost',
		required=True,
		type=str,
		help='DarwinContainers host address.'
	)
	remote_build_parser.add_argument(
		'--configuration',
		choices=[
			'appcenter',
			'appstore',
			'reproducible'
		],
		required=True,
	help='Build configuration'
	)

	if len(sys.argv) < 2:
		parser.print_help()
		sys.exit(1)

	args = parser.parse_args()

	if args.commandName is None:
		exit(0)

	if args.commandName == 'remote-build':
		remote_build(darwin_containers_host=args.darwinContainersHost, configuration=args.configuration)


'''set -e

rm -f "tools/bazel"
cp "$BAZEL" "tools/bazel"

BUILD_CONFIGURATION="$1"

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental" ] || [ "$BUILD_CONFIGURATION" == "appcenter-experimental-2" ]; then
	CODESIGNING_SUBPATH="$BUILDBOX_DIR/transient-data/telegram-codesigning/codesigning"
elif [ "$BUILD_CONFIGURATION" == "appstore" ] || [ "$BUILD_CONFIGURATION" == "appstore-development" ]; then
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
'''