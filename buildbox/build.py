#!/usr/bin/python3

import argparse
import json
import os
import sys
import shlex
import shutil
import subprocess
import time
import pipes
import tempfile

def quote_args(seq):
	return ' '.join(pipes.quote(arg) for arg in seq)

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


def run_executable_with_output(path, arguments, check_result=False):
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

	if check_result:
		if process.returncode != 0:
			print('Command {} {} finished with non-zero return code and output:\n{}'.format(executable_path, arguments, output_string))
			sys.exit(1)

	return output_string




def isolated_build(arguments):
	if arguments.certificatesPath is not None:
		if not os.path.exists(arguments.certificatesPath):
			print('{} does not exist'.format(arguments.certificatesPath))
			sys.exit(1)

		keychain_name = 'temp.keychain'
		keychain_password = 'secret'

		existing_keychains = run_executable_with_output('security', arguments=['list-keychains'], check_result=True)
		if keychain_name in existing_keychains:
			run_executable_with_output('security', arguments=['delete-keychain'], check_result=True)

		run_executable_with_output('security', arguments=[
			'create-keychain',
			'-p',
			keychain_password,
			keychain_name
		], check_result=True)

		existing_keychains = run_executable_with_output('security', arguments=['list-keychains', '-d', 'user'])
		existing_keychains.replace('"', '')

		run_executable_with_output('security', arguments=[
			'list-keychains',
			'-d',
			'user',
			'-s',
			keychain_name,
			existing_keychains
		], check_result=True)

		run_executable_with_output('security', arguments=['set-keychain-settings', keychain_name])
		run_executable_with_output('security', arguments=['unlock-keychain', '-p', keychain_password, keychain_name])

		for file_name in os.listdir(arguments.certificatesPath):
			file_path = arguments.certificatesPath + '/' + file_name
			if file_path.endwith('.p12') or file_path.endwith('.cer'):
				run_executable_with_output('security', arguments=[
					'import',
					file_path,
					'-k',
					keychain_name,
					'-P',
					'',
					'-T',
					'/usr/bin/codesign',
					'-T',
					'/usr/bin/security'
				], check_result=True)

		run_executable_with_output('security', arguments=[
			'import',
			'build-system/AppleWWDRCAG3.cer',
			'-k',
			keychain_name,
			'-P',
			'',
			'-T',
			'/usr/bin/codesign',
			'-T',
			'/usr/bin/security'
		], check_result=True)

		run_executable_with_output('security', arguments=[
			'set-key-partition-list',
			'-S',
			'apple-tool:,apple:',
			'-k',
			keychain_password,
			keychain_name
		], check_result=True)

	build_arguments = ['build-system/Make/Make.py']
	
	#build_arguments.append('--bazel="$(pwd)/tools/bazel"')
	
	if arguments.cacheHost is not None:
		build_arguments.append('--cacheHost={}'.format(arguments.cacheHost))

	build_arguments.append('build')

	build_arguments.append('--configurationPath={}'.format(arguments.configurationPath))
	build_arguments.append('--buildNumber={}'.format(arguments.buildNumber))
	build_arguments.append('--configuration={}'.format(arguments.configuration))
	build_arguments.append('--apsEnvironment=production')
	build_arguments.append('--disableParallelSwiftmoduleGeneration')
	build_arguments.append('--provisioningProfilesPath={}'.format(arguments.provisioningProfilesPath))

	build_command = 'python3 ' + quote_args(build_arguments)
	print('Running {}'.format(build_command))
	os.system(build_command)


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
	remote_build_parser.add_argument(
		'--bazelCacheHost',
		required=False,
		type=str,
		help='Bazel remote cache host address.'
	)

	isolated_build_parser = subparsers.add_parser('isolated-build', help='Build the app inside an isolated environment.')
	isolated_build_parser.add_argument(
		'--certificatesPath',
		required=False,
		type=str,
		help='Install codesigning certificates from the specified directory.'
	)
	isolated_build_parser.add_argument(
		'--provisioningProfilesPath',
		required=True,
		help='''
			Use codesigning provisioning profiles from a local directory.
			''',
		metavar='command'
	)
	isolated_build_parser.add_argument(
		'--cacheHost',
		required=False,
		type=str,
		help='Bazel cache host url.'
	)
	isolated_build_parser.add_argument(
		'--configurationPath',
		help='''
			Path to a json containing build configuration.
			See build-system/appstore-configuration.json for an example.
			''',
		required=True,
		metavar='path'
	)
	isolated_build_parser.add_argument(
		'--buildNumber',
		required=True,
		type=int,
		help='Build number.',
		metavar='number'
	)
	isolated_build_parser.add_argument(
		'--configuration',
		type=str,
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
		remote_build(darwin_containers_host=args.darwinContainersHost, bazel_cache_host=args.bazelCacheHost, configuration=args.configuration)
	elif args.commandName == 'isolated-build':
		isolated_build(arguments=args)


